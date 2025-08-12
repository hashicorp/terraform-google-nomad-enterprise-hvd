# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

locals {
  nomad_metadata_template = fileexists("${path.cwd}/templates/${var.nomad_metadata_template}") ? "${path.cwd}/templates/${var.nomad_metadata_template}" : "${path.module}/templates/${var.nomad_metadata_template}"
  nomad_metadata_template_vars = {
    # system paths and settings
    systemd_dir              = var.systemd_dir,
    nomad_dir_bin            = var.nomad_dir_bin,
    nomad_dir_config         = var.nomad_dir_config,
    nomad_dir_home           = var.nomad_dir_home,
    nomad_dir_logs           = var.nomad_dir_logs,
    nomad_user_name          = var.nomad_user_name,
    nomad_group_name         = var.nomad_group_name,
    additional_package_names = join(" ", var.additional_package_names)

    # installation secrets
    nomad_license_sm_secret_name       = var.nomad_license_sm_secret_name
    nomad_tls_cert_sm_secret_name      = var.nomad_tls_cert_sm_secret_name
    nomad_tls_privkey_sm_secret_name   = var.nomad_tls_privkey_sm_secret_name
    nomad_tls_ca_bundle_sm_secret_name = var.nomad_tls_ca_bundle_sm_secret_name == null ? "NONE" : var.nomad_tls_ca_bundle_sm_secret_name,
    nomad_gossip_key_secret_name       = var.nomad_gossip_key_secret_name

    #Nomad settings
    nomad_upstream_servers                   = var.nomad_upstream_servers
    nomad_nodes                              = var.nomad_nodes
    nomad_server                             = var.nomad_server
    nomad_client                             = var.nomad_client
    nomad_fqdn                               = var.nomad_fqdn == null ? "" : var.nomad_fqdn,
    nomad_region                             = var.nomad_region,
    nomad_datacenter                         = var.nomad_datacenter,
    nomad_version                            = var.nomad_version,
    nomad_enable_ui                          = var.nomad_enable_ui,
    nomad_port_api                           = var.nomad_port_api,
    nomad_port_rpc                           = var.nomad_port_rpc,
    nomad_port_serf                          = var.nomad_port_serf,
    nomad_tls_enabled                        = var.nomad_tls_enabled
    nomad_tls_require_and_verify_client_cert = var.nomad_tls_require_and_verify_client_cert,
    nomad_tls_disable_client_certs           = var.nomad_tls_disable_client_certs,
    nomad_acl_enabled                        = var.nomad_acl_enabled
    autopilot_health_enabled                 = var.autopilot_health_enabled
    auto_join_tag_value                      = var.auto_join_tag == null ? var.tags[0] : var.auto_join_tag[0]
    auto_join_zone_pattern                   = "${var.region}-[[:alpha:]]{1}"
    cni_dir_bin                              = "/opt/cni/bin"
    cni_install_url                          = format("https://github.com/containernetworking/plugins/releases/download/v%s/cni-plugins-linux-%s-v%s.tgz", var.cni_version, var.nomad_architecture, var.cni_version)
  }
}

#------------------------------------------------------------------------------
# Compute
#------------------------------------------------------------------------------
resource "google_compute_instance_template" "nomad" {
  name_prefix    = format("%s-instance-template-", var.application_prefix)
  project        = var.project_id
  machine_type   = var.machine_type
  can_ip_forward = true
  tags           = concat(["nomad-backend"], var.tags)
  labels         = var.common_labels

  disk {
    source_image = var.packer_image == null ? format("%s/%s", var.compute_image_project, var.compute_image_family) : var.packer_image
    auto_delete  = true
    boot         = true
    disk_type    = var.boot_disk_type
    disk_size_gb = var.boot_disk_size
  }

  disk {
    auto_delete  = true
    boot         = false
    disk_type    = var.nomad_data_disk_type
    disk_size_gb = var.nomad_data_disk_size
  }

  disk {
    auto_delete  = true
    boot         = false
    disk_type    = var.nomad_audit_disk_type
    disk_size_gb = var.nomad_audit_disk_size
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.subnetwork.self_link
  }

  metadata = var.metadata

  metadata_startup_script = templatefile(local.nomad_metadata_template, local.nomad_metadata_template_vars)

  service_account {
    email  = google_service_account.nomad_sa.email
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_instance_group_manager" "nomad" {
  name    = "${var.application_prefix}-nomad-ig-mgr"
  project = var.project_id

  base_instance_name = "${var.application_prefix}-nomad-vm"
  #this change limits the serversprawl to 3 zones ensuring voters and none voters after first 3 instances
  distribution_policy_zones = slice(data.google_compute_zones.available.names, 0, 3)
  target_size               = var.node_count
  region                    = var.region

  version {
    name              = google_compute_instance_template.nomad.name
    instance_template = google_compute_instance_template.nomad.self_link
  }

  update_policy {
    type                         = "OPPORTUNISTIC"
    instance_redistribution_type = "PROACTIVE"
    minimal_action               = "REPLACE"
    max_surge_fixed              = length(data.google_compute_zones.available.names)
    max_unavailable_fixed        = 0
  }

  lifecycle {
    create_before_destroy = true
  }

  dynamic "auto_healing_policies" {
    for_each = var.enable_auto_healing == true ? [true] : []
    content {
      health_check      = google_compute_health_check.nomad_auto_healing[0].self_link
      initial_delay_sec = var.initial_auto_healing_delay
    }
  }

}

resource "google_compute_health_check" "nomad_auto_healing" {
  count = var.enable_auto_healing == true ? 1 : 0

  name    = format("%s-autohealing-health-check", var.application_prefix)
  project = var.project_id

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
