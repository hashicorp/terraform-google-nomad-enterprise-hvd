# Copyright IBM Corp. 2025
# SPDX-License-Identifier: MPL-2.0

data "google_dns_managed_zone" "nomad" {
  count = var.create_cloud_dns_record == true ? 1 : 0

  name = var.cloud_dns_managed_zone
}

resource "google_dns_record_set" "nomad" {
  count = var.create_cloud_dns_record == true ? 1 : 0

  managed_zone = data.google_dns_managed_zone.nomad[0].name
  name         = "${var.nomad_fqdn}."
  type         = "A"
  ttl          = 60
  rrdatas      = [google_compute_forwarding_rule.nomad_fr[0].ip_address]
}
