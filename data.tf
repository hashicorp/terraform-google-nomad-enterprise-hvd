# Copyright IBM Corp. 2025
# SPDX-License-Identifier: MPL-2.0

data "google_compute_network" "network" {
  name    = var.network
  project = var.network_project_id == null ? var.project_id : var.network_project_id
}

data "google_compute_subnetwork" "subnetwork" {
  name    = var.subnetwork
  project = var.network_project_id == null ? var.project_id : var.network_project_id
  region  = var.network_region == null ? var.region : var.network_region
}

data "google_compute_zones" "available" {
  project = var.project_id
  region  = var.region
  status  = "UP"
}

data "google_netblock_ip_ranges" "legacy" {
  range_type = "legacy-health-checkers"
}

data "google_netblock_ip_ranges" "new" {
  range_type = "health-checkers"
}

