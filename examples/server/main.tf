# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.39"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region # update to your GCP region
}

module "nomad" {
  source = "../.."

  additional_package_names                 = var.additional_package_names
  application_prefix                       = var.application_prefix
  auto_join_tag                            = var.auto_join_tag
  autopilot_health_enabled                 = var.autopilot_health_enabled
  boot_disk_size                           = var.boot_disk_size
  boot_disk_type                           = var.boot_disk_type
  cidr_ingress_api_allow                   = var.cidr_ingress_api_allow
  cidr_ingress_rpc_allow                   = var.cidr_ingress_rpc_allow
  cloud_dns_managed_zone                   = var.cloud_dns_managed_zone
  cni_version                              = var.cni_version
  common_labels                            = var.common_labels
  compute_image_family                     = var.compute_image_family
  compute_image_project                    = var.compute_image_project
  create_cloud_dns_record                  = var.create_cloud_dns_record
  enable_auto_healing                      = var.enable_auto_healing
  enable_iap                               = var.enable_iap
  google_service_account_iam_roles         = var.google_service_account_iam_roles
  health_check_interval                    = var.health_check_interval
  health_timeout                           = var.health_timeout
  initial_auto_healing_delay               = var.initial_auto_healing_delay
  load_balancing_scheme                    = var.load_balancing_scheme
  machine_type                             = var.machine_type
  metadata                                 = var.metadata
  network                                  = var.network
  network_project_id                       = var.network_project_id
  network_region                           = var.network_region
  node_count                               = var.node_count
  nomad_acl_enabled                        = var.nomad_acl_enabled
  nomad_architecture                       = var.nomad_architecture
  nomad_audit_disk_size                    = var.nomad_audit_disk_size
  nomad_audit_disk_type                    = var.nomad_audit_disk_type
  nomad_client                             = var.nomad_client
  nomad_data_disk_size                     = var.nomad_data_disk_size
  nomad_data_disk_type                     = var.nomad_data_disk_type
  nomad_datacenter                         = var.nomad_datacenter
  nomad_dir_bin                            = var.nomad_dir_bin
  nomad_dir_config                         = var.nomad_dir_config
  nomad_dir_home                           = var.nomad_dir_home
  nomad_dir_logs                           = var.nomad_dir_logs
  nomad_enable_ui                          = var.nomad_enable_ui
  nomad_fqdn                               = var.nomad_fqdn
  nomad_gossip_key_secret_name             = var.nomad_gossip_key_secret_name
  nomad_group_name                         = var.nomad_group_name
  nomad_license_sm_secret_name             = var.nomad_license_sm_secret_name
  nomad_metadata_template                  = var.nomad_metadata_template
  nomad_nodes                              = var.nomad_nodes
  nomad_port_api                           = var.nomad_port_api
  nomad_port_rpc                           = var.nomad_port_rpc
  nomad_port_serf                          = var.nomad_port_serf
  nomad_region                             = var.nomad_region
  nomad_server                             = var.nomad_server
  nomad_snapshot_gcs_bucket_name           = var.nomad_snapshot_gcs_bucket_name
  nomad_tls_ca_bundle_sm_secret_name       = var.nomad_tls_ca_bundle_sm_secret_name
  nomad_tls_cert_sm_secret_name            = var.nomad_tls_cert_sm_secret_name
  nomad_tls_disable_client_certs           = var.nomad_tls_disable_client_certs
  nomad_tls_enabled                        = var.nomad_tls_enabled
  nomad_tls_privkey_sm_secret_name         = var.nomad_tls_privkey_sm_secret_name
  nomad_tls_require_and_verify_client_cert = var.nomad_tls_require_and_verify_client_cert
  nomad_upstream_servers                   = var.nomad_upstream_servers
  nomad_user_name                          = var.nomad_user_name
  nomad_version                            = var.nomad_version
  packer_image                             = var.packer_image
  project_id                               = var.project_id
  region                                   = var.region
  subnetwork                               = var.subnetwork
  systemd_dir                              = var.systemd_dir
  tags                                     = var.tags

}
