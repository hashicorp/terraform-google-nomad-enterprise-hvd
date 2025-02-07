# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "google_compute_firewall" "allow_iap" {
  count = var.enable_iap == true ? 1 : 0
  name  = "${var.application_prefix}-nomad-firewall-iap-allow"

  description = "Allow https://cloud.google.com/iap/docs/using-tcp-forwarding#console traffic"
  network     = data.google_compute_network.network.self_link
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [22]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["nomad-backend"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "allow_api" {
  name = "${var.application_prefix}-nomad-firewall-allow-api"

  description = "Allow API traffic ingress to nomad instances in ${data.google_compute_network.network.name} from specified CIDR ranges."
  network     = data.google_compute_network.network.self_link
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [var.nomad_port_api]
  }

  source_ranges = var.cidr_ingress_api_allow
  target_tags   = ["nomad-backend"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "allow_rpc" {
  name = "${var.application_prefix}-nomad-firewall-allow-rpc"

  description = "Allow RPC/Serf traffic ingress to nomad instances in ${data.google_compute_network.network.name} from specified CIDR ranges."
  network     = data.google_compute_network.network.self_link
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [var.nomad_port_rpc, var.nomad_port_serf]
  }

  allow {
    protocol = "udp"
    ports    = [var.nomad_port_serf]
  }

  source_ranges = var.cidr_ingress_rpc_allow
  target_tags   = ["nomad-backend"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "allow_outbound" {
  name = "${var.application_prefix}-nomad-firewall-allow-outbound"

  description = "Allow traffic egress from nomad instances in ${data.google_compute_network.network.name} from specified CIDR ranges."
  network     = data.google_compute_network.network.self_link
  direction   = "EGRESS"

  allow {
    protocol = "all"
    ports    = [] # all low ports-ish
  }

  source_ranges = var.cidr_ingress_api_allow
  target_tags   = ["nomad-backend"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}
