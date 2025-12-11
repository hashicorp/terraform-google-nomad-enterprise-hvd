# Copyright IBM Corp. 2025
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# Firewall rules (for GCP health check probes)
#------------------------------------------------------------------------------
resource "google_compute_firewall" "allow_nomad_health_checks" {
  count = var.load_balancing_scheme == "NONE" ? 0 : 1

  name        = format("%s-health-check-fw", var.application_prefix)
  network     = data.google_compute_network.network.self_link
  project     = var.network_project_id == null ? var.project_id : var.network_project_id
  description = "Allow Google LB HC IP ranges to poll Vault Instance"
  direction   = "INGRESS"

  source_ranges = concat(
    data.google_netblock_ip_ranges.legacy.cidr_blocks_ipv4,
    data.google_netblock_ip_ranges.new.cidr_blocks_ipv4
  )

  allow {
    protocol = "tcp"
    ports    = [var.nomad_port_api]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

#------------------------------------------------------------------------------
# Backend
#------------------------------------------------------------------------------
resource "google_compute_region_backend_service" "nomad_bs" {
  count = var.load_balancing_scheme == "NONE" ? 0 : 1

  name    = format("%s-backend-service", var.application_prefix)
  project = var.project_id
  region  = var.region

  protocol              = "TCP"
  load_balancing_scheme = var.load_balancing_scheme
  timeout_sec           = 60

  backend {
    group = google_compute_region_instance_group_manager.nomad.instance_group
  }

  health_checks = [google_compute_region_health_check.nomad_hc[0].self_link]
}

resource "google_compute_region_health_check" "nomad_hc" {
  count = var.load_balancing_scheme == "NONE" ? 0 : 1

  name    = format("%s-regional-health-check", var.application_prefix)
  project = var.project_id
  region  = var.region

  check_interval_sec = var.health_check_interval
  timeout_sec        = var.health_timeout

  https_health_check {
    port               = var.nomad_port_api
    port_specification = "USE_FIXED_PORT"

    request_path = "/v1/agent/health"
  }

  log_config {
    enable = true
  }
}

#------------------------------------------------------------------------------
# Frontend
#------------------------------------------------------------------------------
resource "google_compute_forwarding_rule" "nomad_fr" {
  count = var.load_balancing_scheme == "NONE" ? 0 : 1

  name       = format("%s-forwarding-rule", var.application_prefix)
  region     = var.region
  project    = var.project_id
  network    = var.load_balancing_scheme == "INTERNAL" ? data.google_compute_network.network.self_link : null
  subnetwork = var.load_balancing_scheme == "INTERNAL" ? data.google_compute_subnetwork.subnetwork.self_link : null

  backend_service       = google_compute_region_backend_service.nomad_bs[0].id
  ports                 = [var.nomad_port_api]
  load_balancing_scheme = var.load_balancing_scheme
}
