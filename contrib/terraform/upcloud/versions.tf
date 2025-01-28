
terraform {
  required_providers {
    upcloud = {
      source  = "UpCloudLtd/upcloud"
      version = "~>5.9.0"
    }
  }
  required_version = ">= 0.13"
}
