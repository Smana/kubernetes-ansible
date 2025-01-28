import sys
import json
import argparse

# Do not commit any prints if the script doesn't exit with error code
# Otherwise it will be part of the PR body


def load_json(component):
    try:
        with open('version_diff.json', 'r') as f:
            repo_metadata = json.load(f)
            component_data = repo_metadata.get(component)
            return component_data
    except Exception as e:
        return None

def get_version_commits(version, component_metadata):
    tags = component_metadata.get('refs', {}).get('nodes', [])
    for tag in tags:
        if tag['name'] == version:
            target = tag.get('target', {})

            # Check if the target is a Tag pointing to a Commit
            if 'history' in target.get('target', {}):
                commit_history = target['target']['history'].get('edges', [])
            # Check if the target is directly a Commit object
            elif 'history' in target:
                commit_history = target['history'].get('edges', [])
            else:
                return None

            commits = []
            for commit in commit_history:
                commit_node = commit.get('node', {})
                commit_info = {
                    'oid': commit_node.get('oid'),
                    'message': commit_node.get('message'),
                    'url': commit_node.get('url')
                }
                commits.append(commit_info)

            if commits:
                return commits
    return None

def get_version_description(version, repo_metadata):
    if repo_metadata:
        releases = repo_metadata.get('releases', {}).get('nodes', [])
        for release in releases:
            if release.get('tagName') == version:
                description = release.get('description', None)
                return format_description(description)
    return None

def handle_reference(input):
    return input.replace('github.com', 'redirect.github.com') # Prevent reference in the sourced PR

# Split description into visible and collapsed
def format_description(description):
    description = handle_reference(description)
    lines = description.splitlines()
    if len(lines) > args.description_number_of_lines:
        first_part = '\n'.join(lines[:args.description_number_of_lines])
        collapsed_part = '\n'.join(lines[args.description_number_of_lines:])
        formatted_description = f"""{first_part}

<details>
  <summary>Show more</summary>

{collapsed_part}

</details>
"""
        return formatted_description
    else:
        return description

def main():
    component_data = load_json(args.component)
    if not component_data:
        print('Failed to load component data')
        sys.exit(1)
    owner = component_data.get('owner')
    repo = component_data.get('repo')
    latest_version = component_data.get('latest_version')
    repo_metadata = component_data.get('repo_metadata')
    release_url = f'https://github.com/{owner}/{repo}/releases/tag/{latest_version}'
    commits = get_version_commits(latest_version, repo_metadata)
    description = get_version_description(latest_version, repo_metadata)

    # General info
    pr_body = f"""
### {latest_version}

**URL**: [Release {latest_version}]({release_url})

        """

    # Description
    if description:

        pr_body += f"""
#### Description:
{description}
        """

    # Commits
    if commits:
        pr_commits = '\n<details>\n<summary>Commits</summary>\n\n'
        for commit in commits:
            short_oid = commit.get('oid')[:7]
            message = commit.get('message').split('\n')[0]
            commit_message = handle_reference(message)
            # commit_message = link_pull_requests(commit_message, repo_url)
            commit_url = commit.get('url')
            pr_commits += f'- [`{short_oid}`]({commit_url}) {commit_message}  \n'
        pr_commits += '\n</details>'
        pr_body += pr_commits

    # Print body
    print(pr_body)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Pull Request body generator')
    parser.add_argument('--component', required=True, help='Specify the component to process')
    parser.add_argument('--description-number-of-lines', type=int, default=20, help='Number of lines to include from the description')
    args = parser.parse_args()

    main()
