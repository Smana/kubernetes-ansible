import os
import re
import sys
import logging
import requests
import json
import argparse
import hashlib
from ruamel.yaml import YAML
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from concurrent.futures import ThreadPoolExecutor
from dependency_config import ARCHITECTURES, OSES, README_COMPONENTS, PATH_DOWNLOAD, PATH_CHECKSUM, PATH_MAIN, PATH_README, PATH_VERSION_DIFF, COMPONENT_INFO, SHA256REGEX


yaml = YAML()
yaml.explicit_start = True
yaml.preserve_quotes = True
yaml.width = 4096
yaml.indent(mapping=2, sequence=4, offset=2)


pwd = os.getcwd()
cache_dir = './cache'
cache_expiry_seconds = 86400
os.makedirs(cache_dir, exist_ok=True)


github_api_url = 'https://api.github.com/graphql'
gh_token = os.getenv('GH_TOKEN')
if not gh_token:
    logging.error('GH_TOKEN is not set. You can set it via "export GH_TOKEN=<your-token>". Exiting.')
    sys.exit(1)


def setup_logging(loglevel):
    log_format = '%(asctime)s - %(levelname)s - [%(threadName)s] - %(message)s'
    numeric_level = getattr(logging, loglevel.upper(), None)
    if not isinstance(numeric_level, int):
        raise ValueError(f'Invalid log level: {loglevel}')
    logging.basicConfig(level=numeric_level, format=log_format)

def get_session_with_retries():
    session = requests.Session()
    adapter = HTTPAdapter(
        pool_connections=50,
        pool_maxsize=50,
        max_retries=Retry(total=3, backoff_factor=1)
    )
    session.mount('http://', adapter)
    session.mount('https://', adapter)
    return session

def get_current_version(component, component_data):
    kube_major_version = component_data['kube_major_version']
    placeholder_version = [kube_major_version if item == 'kube_major_version' else item for item in component_data['placeholder_version']]
    if component.startswith('kube'):
        current_version = main_yaml_data
    else:
        current_version = download_yaml_data
    for key in placeholder_version:
        current_version = current_version.get(key)
    return current_version

def get_latest_version(component_repo_metadata):
    releases = component_repo_metadata.get('releases', {}).get('nodes', [])
    for release in releases:
        if release.get('isLatest', False):
            return release['tagName']
    tags = component_repo_metadata.get('refs', {}).get('nodes', []) # fallback on tags
    if tags:
        first_tag = tags[0]['name']
        return first_tag
    return None

def get_patch_versions(component, latest_version, component_repo_metadata):
    if component in ['gvisor_runsc','gvisor_containerd_shim']: # hack for gvisor
        return [latest_version]
    match = re.match(r'v?(\d+)\.(\d+)', latest_version)
    if not match:
        logging.error(f'Invalid version format: {latest_version}')
        return []
    major_version, minor_version = match.groups()
    patch_versions = []
    stable_version_pattern = re.compile(rf'^v?{major_version}\.{minor_version}(\.\d+)?$') # no rc, alpha, dev, etc.
    # Search releases
    releases = component_repo_metadata.get('releases', {}).get('nodes', [])
    for release in releases:
        version = release.get('tagName', '')
        if stable_version_pattern.match(version):
            patch_versions.append(version)
    # Fallback to tags
    if not patch_versions:
        tags = component_repo_metadata.get('refs', {}).get('nodes', [])
        for tag in tags:
            version = tag.get('name', '')
            if stable_version_pattern.match(version):
                patch_versions.append(version)
    patch_versions.sort(key=lambda v: list(map(int, re.findall(r'\d+', v)))) # sort for checksum update
    return patch_versions

def get_repository_metadata(component_info, session):
    query_parts = []
    for component, data in component_info.items():
        owner = data['owner']
        repo = data['repo']
        query_parts.append(f"""
            {component}: repository(owner: "{owner}", name: "{repo}") {{
                releases(first: {args.graphql_number_of_entries}, orderBy: {{field: CREATED_AT, direction: DESC}}) {{
                    nodes {{
                        tagName
                        url
                        description
                        publishedAt
                        isLatest
                    }}
                }}
                refs(refPrefix: "refs/tags/", first: {args.graphql_number_of_entries}, orderBy: {{field: TAG_COMMIT_DATE, direction: DESC}}) {{
                    nodes {{
                        name
                        target {{
                            ... on Tag {{
                                target {{
                                    ... on Commit {{
                                        history(first: {args.graphql_number_of_commits}) {{
                                            edges {{
                                                node {{
                                                    oid
                                                    message
                                                    url
                                                }}
                                            }}
                                        }}
                                    }}
                                }}
                            }}
                            ... on Commit {{
                                # In case the tag directly points to a commit
                                history(first: {args.graphql_number_of_commits}) {{
                                    edges {{
                                        node {{
                                            oid
                                            message
                                            url
                                        }}
                                    }}
                                }}
                            }}
                        }}
                    }}
                }}
            }}
        """)

    query = f"query {{ {''.join(query_parts)} }}"
    headers = {
        'Authorization': f'Bearer {gh_token}',
        'Content-Type': 'application/json'
    }

    try:
        response = session.post(github_api_url, json={'query': query}, headers=headers)
        response.raise_for_status()
        json_data = response.json()
        data = json_data.get('data')
        if data is not None and bool(data):  # Ensure 'data' is not None and not empty
            logging.debug(f'GraphQL data response:\n{json.dumps(data, indent=2)}')
            return data
        else:
            logging.error(f'GraphQL query returned errors: {json_data}')
            return None
    except Exception as e:
        logging.error(f'Error fetching repository metadata: {e}')
        return None

def calculate_checksum(cachefile, sha_regex):
    if sha_regex:
        logging.debug(f'Searching with regex {sha_regex} in file {cachefile}')
        with open(f'cache/{cachefile}', 'r') as f:
            for line in f:
                if sha_regex == 'simple': # Only sha is present in the file
                    pattern = re.compile(SHA256REGEX)
                else:
                    pattern = re.compile(rf'(?:{SHA256REGEX}.*{sha_regex}|{sha_regex}.*{SHA256REGEX})') # Sha may be at start or end
                match = pattern.search(line)
                if match:
                    checksum = match.group(1) or match.group(2)
                    logging.debug(f'Matched line: {line.strip()}')
                    return checksum
    else: # binary
        sha256_hash = hashlib.sha256()
        with open(f'cache/{cachefile}', 'rb') as f:
            for byte_block in iter(lambda: f.read(4096), b''):
                sha256_hash.update(byte_block)
        checksum = sha256_hash.hexdigest()
        return checksum

def download_file_and_get_checksum(component, arch, url_download, version, sha_regex, session):
    logging.info(f'Download URL {url_download}')
    cache_file = f'{component}-{arch}-{version}'
    if os.path.exists(f'cache/{cache_file}'):
        logging.info(f'Using cached file for {url_download}')
        return calculate_checksum(cache_file, sha_regex)
    try:
        response = session.get(url_download, timeout=10)
        response.raise_for_status()
        with open(f'cache/{cache_file}', 'wb') as f:
            f.write(response.content)
        logging.info(f'Downloaded and cached file for {url_download}')
        return calculate_checksum(cache_file, sha_regex)
    except Exception as e:
        logging.warning(e)
        return None

def get_checksums(component, component_data, versions, session):
    checksums = {}
    for version in versions:
        processed_version = process_version_string(component, version)
        checksums[version] = {}
        url_download_template = component_data.get('url_download')
        if component_data['checksum_structure'] == 'os_arch':
            # OS -> Arch -> Checksum
            for os_name in OSES:
                if os_name not in checksums[version]:
                    checksums[version][os_name] = {}
                for arch in ARCHITECTURES:
                    url_download = url_download_template.format(arch=arch, os_name=os_name, version=processed_version)
                    sha_regex = component_data.get('sha_regex').format(arch=arch, os_name=os_name)
                    checksum = download_file_and_get_checksum(component, arch, url_download, processed_version, sha_regex, session) or 0
                    checksums[version][os_name][arch] = checksum
        elif component_data['checksum_structure'] == 'arch':
            # Arch -> Checksum
            for arch in ARCHITECTURES:
                tmp_arch = arch
                if component == 'youki':
                    tmp_arch = tmp_arch.replace('arm64', 'aarch64-gnu').replace('amd64', 'x86_64-gnu')
                elif component in ['gvisor_containerd_shim','gvisor_runsc']:
                    tmp_arch = tmp_arch.replace("arm64", "aarch64").replace("amd64", "x86_64")
                url_download = url_download_template.format(arch=tmp_arch, version=processed_version)
                sha_regex = component_data.get('sha_regex').format(arch=tmp_arch)
                checksum = download_file_and_get_checksum(component, arch, url_download, processed_version, sha_regex, session) or 0
                checksums[version][arch] = checksum
        elif component_data['checksum_structure'] == 'simple':
            # Checksum
            url_download = url_download_template.format(version=processed_version)
            sha_regex = component_data.get('sha_regex')
            checksum = download_file_and_get_checksum(component, '', url_download, processed_version, sha_regex, session) or 0
            checksums[version] = checksum  # Store checksum for the version
    return checksums

def update_checksum(component, component_data, checksums, version):
    processed_version = process_version_string(component, version)
    placeholder_checksum = component_data['placeholder_checksum']
    checksum_structure = component_data['checksum_structure']
    current = checksum_yaml_data[placeholder_checksum]

    if checksum_structure == 'simple':
        # Simple structure (placeholder_checksum -> version -> checksum)
        checksum_yaml_data[placeholder_checksum] = {processed_version: checksums, **current}
    elif checksum_structure == 'os_arch':
        # OS structure (placeholder_checksum -> os -> arch -> version -> checksum)
        for os_name, arch_dict in checksums.items():
            os_current = current.setdefault(os_name, {})
            for arch, checksum in arch_dict.items():
                os_current[arch] = {(processed_version): checksum, **os_current.get(arch, {})}
    elif checksum_structure == 'arch':
        # Arch structure (placeholder_checksum -> arch -> version -> checksum)
        for arch, checksum in checksums.items():
            current[arch] = {(processed_version): checksum, **current.get(arch, {})}
    logging.info(f'Updated {placeholder_checksum} with version {processed_version} and checksums {checksums}')

def resolve_kube_dependent_component_version(component, component_data, version):
    kube_major_version = component_data['kube_major_version']
    if component in ['crictl', 'crio']:
        try:
            component_major_version = get_major_version(version)
            if component_major_version == kube_major_version:
                resolved_version = kube_major_version
            else:
                resolved_version = component_major_version
        except (IndexError, AttributeError):
            logging.error(f'Error parsing version for {component}: {version}')
            return
    else:
        resolved_version = kube_major_version
    return resolved_version

def update_version(component, component_data, version):
    placeholder_version = component_data['placeholder_version']
    resolved_version = resolve_kube_dependent_component_version(component, component_data, version)
    updated_placeholder = [
        resolved_version if item == 'kube_major_version' else item
        for item in placeholder_version
    ]
    current = download_yaml_data
    if len(updated_placeholder) == 1:
        current[updated_placeholder[0]] = version
    else:
        for key in updated_placeholder[:-1]:
            current = current.setdefault(key, {})
        final_key = updated_placeholder[-1]
        if final_key in current:
            current[final_key] = version
        else:
            new_entry = {final_key: version, **current}
            current.clear()
            current.update(new_entry)
    logging.info(f'Updated {updated_placeholder} to {version}')

def update_readme(component, version):
    for i, line in enumerate(readme_data):
        if component in line and re.search(r'v\d+\.\d+\.\d+', line):
            readme_data[i] = re.sub(r'v\d+\.\d+\.\d+', version, line)
            logging.info(f'Updated {component} to {version} in README')
            break
    return readme_data

def safe_save_files(file_path, data=None, save_func=None):
    if not save_func(file_path, data):
        logging.error(f'Failed to save file {file_path}')
        sys.exit(1)

def create_json_file(file_path):
    new_data = {}
    try:
        with open(file_path, 'w') as f:
            json.dump(new_data, f, indent=2)
        return new_data
    except Exception as e:
        logging.error(f'Failed to create {file_path}: {e}')
        return None

def save_json_file(file_path, data):
    try:
        with open(file_path, 'w') as f:
            json.dump(data, f, indent=2)
        return True
    except Exception as e:
        logging.error(f'Failed to save {file_path}: {e}')
        return False

def load_yaml_file(yaml_file):
    try:
        with open(yaml_file, 'r') as f:
            return yaml.load(f)
    except Exception as e:
        logging.error(f'Failed to load {yaml_file}: {e}')
        return None

def save_yaml_file(yaml_file, data):
    try:
        with open(yaml_file, 'w') as f:
            yaml.dump(data, f)
        return True
    except Exception as e:
        logging.error(f'Failed to save {yaml_file}: {e}')
        return False

def open_readme(path_readme):
    try:
        with open(path_readme, 'r') as f:
            return f.readlines()
    except Exception as e:
        logging.error(f'Failed to load {path_readme}: {e}')
        return None

def save_readme(path_readme, data):
    try:
        with open(path_readme, 'w') as f:
            f.writelines(data)
            return True
    except Exception as e:
        logging.error(f'Failed to save {path_readme}: {e}')
        return False

def process_version_string(component, version):
    if component in ['youki', 'nerdctl', 'cri_dockerd', 'containerd']:
        if version.startswith('v'):
            version = version[1:]
            return version
    match = re.search(r'release-(\d{8})', version) # gvisor
    if match:
        version = match.group(1)
    return version

def get_major_version(version):
    match = re.match(r'^(v\d+)\.(\d+)', version)
    if match:
        return f'{match.group(1)}.{match.group(2)}'
    return None

def process_component(component, component_data, repo_metadata, session):
    logging.info(f'Processing component: {component}')
    component_repo_metada = repo_metadata.get(component, {})

    # Get current kube version
    kube_version = main_yaml_data.get('kube_version')
    kube_major_version = get_major_version(kube_version)
    component_data['kube_version'] = kube_version  # needed for nested components
    component_data['kube_major_version'] = kube_major_version  # needed for nested components

    # Get current component version
    current_version = get_current_version(component, component_data)
    if not current_version:
        logging.info(f'Stop processing component {component}, current version unknown')
        return

    # Get latest component version
    latest_version = get_latest_version(component_repo_metada)
    if not latest_version:
        logging.info(f'Stop processing component {component}, latest version unknown.')
        return
    # Kubespray version
    processed_latest_version = process_version_string(component, latest_version)

    # Log version comparison
    if current_version == processed_latest_version:
        logging.info(f'Component {component}, version {current_version} is up to date')
    else:
        logging.info(f'Component {component} version discrepancy, current={current_version}, latest={processed_latest_version}')

    # CI - write data and return
    if args.ci_check and current_version != latest_version:
        version_diff[component] = {
            # used in dependecy-check.yml workflow
            'current_version' : current_version,
            'latest_version' : latest_version, # used for PR name
            # used in generate_pr_body.py script
            'processed_latest_version': processed_latest_version, # used for PR body
            'owner' : component_data['owner'],
            'repo' : component_data['repo'],
            'repo_metadata' : component_repo_metada,
        }
        return

    # Get patch versions
    patch_versions = get_patch_versions(component, latest_version, component_repo_metada)
    logging.info(f'Component {component} patch versions: {patch_versions}')

    # Get checksums for all patch versions
    checksums = get_checksums(component, component_data, patch_versions, session)
    # Update checksums
    for version in patch_versions:
        version_checksum = checksums.get(version)
        update_checksum(component, component_data, version_checksum, version)

    # Update version in configuration
    if component not in ['kubeadm', 'kubectl', 'kubelet']: # kubernetes dependent components
        if component != 'calico_crds': # TODO double check if only calicoctl may change calico_version
            update_version(component, component_data, processed_latest_version)

    # Update version in README
    if component in README_COMPONENTS:
        if component in ['crio', 'crictl']:
            component_major_version = get_major_version(processed_latest_version)
            if component_major_version != kube_major_version: # do not update README, we just added checksums
                return
        # replace component name to fit readme
        component = component.replace('crio', 'cri-o').replace('calicoctl', 'calico')
        update_readme(component, latest_version)

def main():
    # Setup logging
    setup_logging(args.loglevel)
    # Setup session with retries
    session = get_session_with_retries()

    # Load configuration files
    global main_yaml_data, checksum_yaml_data, download_yaml_data, readme_data, version_diff
    main_yaml_data = load_yaml_file(PATH_MAIN)
    checksum_yaml_data = load_yaml_file(PATH_CHECKSUM)
    download_yaml_data = load_yaml_file(PATH_DOWNLOAD)
    readme_data = open_readme(PATH_README)
    if not (main_yaml_data and checksum_yaml_data and download_yaml_data and readme_data):
        logging.error(f'Failed to open one or more configuration files, current working directory is {pwd}. Exiting...')
        sys.exit(1)

    # CI - create version_diff file
    if args.ci_check:
        version_diff = create_json_file(PATH_VERSION_DIFF)
        if version_diff is None:
            logging.error(f'Failed to create {PATH_VERSION_DIFF} file')
            sys.exit(1)

    # Process single component
    if args.component != 'all':
        if args.component in COMPONENT_INFO:
            specific_component_info = {args.component: COMPONENT_INFO[args.component]}
            # Get repository metadata => releases, tags and commits
            logging.info(f'Fetching repository metadata for the component {args.component}')
            repo_metadata = get_repository_metadata(specific_component_info, session)
            if not repo_metadata:
                sys.exit(1)
            process_component(args.component, COMPONENT_INFO[args.component], repo_metadata, session)
        else:
            logging.error(f'Component {args.component} not found in config.')
            sys.exit(1)
    # Process all components in the configuration file concurrently
    else:
        # Get repository metadata => releases, tags and commits
        logging.info('Fetching repository metadata for all components')
        repo_metadata = get_repository_metadata(COMPONENT_INFO, session)
        if not repo_metadata:
            sys.exit(1)
        with ThreadPoolExecutor(max_workers=args.max_workers) as executor:
            futures = []
            logging.info(f'Running with {executor._max_workers} executors')
            for component, component_data in COMPONENT_INFO.items():
                futures.append(executor.submit(process_component, component, component_data, repo_metadata, session))
            for future in futures:
                future.result()

    # CI - save JSON file
    if args.ci_check:
        safe_save_files(PATH_VERSION_DIFF, version_diff, save_json_file)

    # Save configurations
    else:
        safe_save_files(PATH_CHECKSUM, checksum_yaml_data, save_yaml_file)
        safe_save_files(PATH_DOWNLOAD, download_yaml_data, save_yaml_file)
        safe_save_files(PATH_README, readme_data, save_readme)

    logging.info('Finished.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Kubespray version and checksum updater for dependencies')
    parser.add_argument('--loglevel', default='INFO', help='Set the log level (DEBUG, INFO, WARNING, ERROR, CRITICAL)')
    parser.add_argument('--component', default='all', help='Specify a component to process, default is all components')
    parser.add_argument('--max-workers', type=int, default=4, help='Maximum number of concurrent workers, use with caution(sometimes less is more)')
    parser.add_argument('--ci-check', action='store_true', help='Check versions, store discrepancies in version_diff.json')
    parser.add_argument('--graphql-number-of-entries', type=int, default=10, help='Number of releases/tags to retrieve from Github GraphQL per component (default: 10)')
    parser.add_argument('--graphql-number-of-commits', type=int, default=5, help='Number of commits to retrieve from Github GraphQL per tag (default: 5)')
    args = parser.parse_args()

    main()
