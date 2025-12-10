# Copyright IBM Corp. 2025
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_version = "~> 1.9"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.39"
    }
  }
}
