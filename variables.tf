# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

#-----------------------------------------------------------------------------------
# Common
#-----------------------------------------------------------------------------------
variable "project_id" {
  type        = string
  description = "(required) The project ID to host the cluster in (required)"
}

variable "region" {
  type        = string
  description = "(optional) The region to host the cluster in"
  default     = "us-central1"
}

variable "nomad_fqdn" {
  type        = string
  description = "Fully qualified domain name to use for joining peer nodes and optionally DNS"
  nullable    = false
}

variable "tags" {
  type        = list(string)
  description = "(optional) A list containing tags to assign to all resources"
  default     = ["nomad"]
}

variable "common_labels" {
  type        = map(string)
  description = "(optional) Common labels to apply to GCP resources."
  default     = {}
}

variable "application_prefix" {
  type        = string
  description = "(optional) The prefix to give to cloud entities"
  default     = "nomad"
}

#------------------------------------------------------------------------------
# Prerequisites
#------------------------------------------------------------------------------
variable "nomad_license_sm_secret_name" {
  type        = string
  description = "Name of Secret Manager secret containing Nomad license."
}

variable "nomad_tls_cert_sm_secret_name" {
  type        = string
  description = "Name of Secret Manager containing Nomad TLS certificate."
}

variable "nomad_tls_privkey_sm_secret_name" {
  type        = string
  description = "Name of Secret Manager containing Nomad TLS private key."
}

variable "nomad_tls_ca_bundle_sm_secret_name" {
  type        = string
  description = "Name of Secret Manager containing Nomad TLS custom CA bundle."
  nullable    = true
}

variable "nomad_gossip_key_secret_name" {
  type        = string
  description = "Name of Secret Manager secret containing Nomad gossip encryption key."
}
#------------------------------------------------------------------------------
# Nomad configuration settings
#------------------------------------------------------------------------------
variable "nomad_tls_enabled" {
  type        = bool
  description = "Boolean to enable TLS for Nomad."
  default     = true
}

variable "autopilot_health_enabled" {
  type        = bool
  default     = true
  description = "Whether autopilot upgrade migration validation is performed for server nodes at boot-time"
}

variable "nomad_upstream_servers" {
  type        = list(string)
  description = "List of Nomad server addresses to join the Nomad client with."
  default     = null
}

variable "nomad_nodes" {
  type        = number
  default     = 6
  description = "Number of Nomad nodes to deploy."
}

variable "nomad_acl_enabled" {
  type        = bool
  description = "Boolean to enable ACLs for Nomad."
  default     = true
}

variable "nomad_client" {
  type        = bool
  description = "Boolean to enable the Nomad client mode."
}

variable "nomad_server" {
  type        = bool
  description = "Boolean to enable the Nomad server mode."
}

variable "nomad_region" {
  type        = string
  description = "Specifies the region of the local agent. A region is an abstract grouping of datacenters. Clients are not required to be in the same region as the servers they are joined with, but do need to be in the same datacenter. If not specified, the region is set AWS region."
  default     = null
}

variable "nomad_datacenter" {
  type        = string
  description = "Specifies the data center of the local agent. A datacenter is an abstract grouping of clients within a region. Clients are not required to be in the same datacenter as the servers they are joined with, but do need to be in the same region."
}

variable "nomad_version" {
  type        = string
  description = "(optional) The version of Nomad to use"
  default     = "1.9.5+ent"
}

variable "nomad_enable_ui" {
  type        = bool
  description = "(optional) Enable the Nomad UI"
  default     = true
}

variable "nomad_port_api" {
  type        = number
  description = "TCP port for Nomad API listener"
  default     = 4646
}

variable "nomad_port_rpc" {
  type        = number
  description = "TCP port for Nomad cluster address"
  default     = 4647
}

variable "nomad_port_serf" {
  type        = number
  description = "TCP port for Nomad cluster address"
  default     = 4648
}

variable "nomad_tls_disable_client_certs" {
  type        = bool
  description = "Disable client authentication for the Nomad listener. Must be enabled when tls auth method is used."
  default     = true
}

variable "nomad_tls_require_and_verify_client_cert" {
  type        = bool
  description = "(optional) Require a client to present a client certificate that validates against system CAs"
  default     = false
}

variable "auto_join_tag" {
  type        = list(string)
  description = "(optional) A list of a tag which will be used by Nomad to join other nodes to the cluster. If left blank, the module will use the first entry in `tags`"
  default     = null
}

#------------------------------------------------------------------------------
# System paths and settings
#------------------------------------------------------------------------------
variable "additional_package_names" {
  type        = set(string)
  description = "List of additional repository package names to install"
  default     = []
}

variable "nomad_user_name" {
  type        = string
  description = "Name of system user to own Nomad files and processes"
  default     = "nomad"
}

variable "nomad_group_name" {
  type        = string
  description = "Name of group to own Nomad files and processes"
  default     = "nomad"
}

variable "systemd_dir" {
  type        = string
  description = "Path to systemd directory for unit files"
  default     = "/lib/systemd/system"
}

variable "nomad_dir_bin" {
  type        = string
  description = "Path to install Nomad Enterprise binary"
  default     = "/usr/bin"
}

variable "nomad_dir_config" {
  type        = string
  description = "Path to install Nomad Enterprise binary"
  default     = "/etc/nomad.d"
}

variable "nomad_dir_home" {
  type        = string
  description = "Path to hold data, plugins and license directories"
  default     = "/opt/nomad"
}

variable "nomad_dir_logs" {
  type        = string
  description = "Path to hold Nomad file audit device logs"
  default     = "/var/log/nomad"
}

variable "cni_version" {
  type        = string
  description = "Version of CNI plugin to install."
  default     = "1.6.0"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.cni_version))
    error_message = "Value must be in the format 'X.Y.Z'."
  }
}
#-----------------------------------------------------------------------------------
# Networking
#-----------------------------------------------------------------------------------
variable "network" {
  type        = string
  description = "(optional) The VPC network to host the cluster in"
  default     = "default"
}

variable "subnetwork" {
  type        = string
  description = "(optional) The subnet in the VPC network to host the cluster in"
  default     = "default"
}

variable "network_project_id" {
  type        = string
  description = "(optional) The project that the VPC network lives in. Can be left blank if network is in the same project as provider"
  default     = null
}

variable "network_region" {
  type        = string
  description = "(optional) The region that the VPC network lives in. Can be left blank if network is in the same region as provider"
  default     = null
}

variable "cidr_ingress_api_allow" {
  type        = list(string)
  description = "CIDR ranges to allow API traffic inbound to Nomad instance(s)."
  default     = ["0.0.0.0/0"]
}

variable "cidr_ingress_rpc_allow" {
  type        = list(string)
  description = "CIDR ranges to allow RPC traffic inbound to Nomad instance(s)."
  default     = ["0.0.0.0/0"]
}

#-----------------------------------------------------------------------------------
# DNS
#-----------------------------------------------------------------------------------
variable "create_cloud_dns_record" {
  type        = bool
  description = "Boolean to create Google Cloud DNS record for `nomad_fqdn` resolving to load balancer IP. `cloud_dns_managed_zone` is required when `true`."
  default     = false
}

variable "cloud_dns_managed_zone" {
  type        = string
  description = "Zone name to create Cloud DNS record in if `create_cloud_dns_record` is set to `true`."
  default     = null
}

#-----------------------------------------------------------------------------------
# Compute
#-----------------------------------------------------------------------------------
variable "nomad_architecture" {
  type        = string
  description = "Architecture of the Nomad binary to install."
  default     = "amd64"
  validation {
    condition     = can(regex("^(amd64|arm64)$", var.nomad_architecture))
    error_message = "value must be either 'amd64' or 'arm64'."
  }
}

variable "node_count" {
  type        = number
  description = "(optional) The number of nodes to create in the pool"
  default     = 6
}

variable "nomad_metadata_template" {
  type        = string
  description = "(optional) Alternative template file to provide for instance template metadata script. place the file in your local `./templates folder` no path required"
  default     = "nomad_custom_data.sh.tpl"
  validation {
    condition     = can(fileexists("../../templates/${var.nomad_metadata_template}") || fileexists("./templates/${var.nomad_metadata_template}"))
    error_message = "File `../../templates/${var.nomad_metadata_template}` or `./templates/${var.nomad_metadata_template} not found or not readable"
  }
}

variable "compute_image_family" {
  type        = string
  description = "(optional) The family name of the image, https://cloud.google.com/compute/docs/images/os-details,defaults to `Ubuntu`"
  default     = "ubuntu-2204-lts"
}

variable "compute_image_project" {
  type        = string
  description = "(optional) The project name of the image, https://cloud.google.com/compute/docs/images/os-details, defaults to `Ubuntu`"
  default     = "ubuntu-os-cloud"
}

# Rename to vm_custom_image_name (or similar)
variable "packer_image" {
  type        = string
  description = "(optional) The packer image to use"
  default     = null
}

variable "boot_disk_type" {
  type        = string
  description = "(optional) The disk type to use to create the boot disk"
  default     = "pd-balanced"

  validation {
    condition     = contains(["pd-ssd", "local-ssd", "pd-balanced", "pd-standard"], var.boot_disk_type)
    error_message = "The value must be either pd-ssd, local-ssd, pd-balanced, pd-standard."
  }
}

variable "boot_disk_size" {
  type        = number
  description = "(optional) The disk size (GB) to use to create the boot disk"
  default     = 30
}

variable "nomad_data_disk_type" {
  type        = string
  description = "(optional) The disk type to use to create the Nomad data disk"
  default     = "pd-ssd"

  validation {
    condition     = contains(["pd-ssd", "local-ssd", "pd-balanced", "pd-standard"], var.nomad_data_disk_type)
    error_message = "The value must be either pd-ssd, local-ssd, pd-balanced, pd-standard."
  }
}

variable "nomad_data_disk_size" {
  type        = number
  description = "(optional) The disk size (GB) to use to create the disk"
  default     = 500
}

variable "nomad_audit_disk_type" {
  type        = string
  description = "(optional) The disk type to use to create the Nomad audit log disk"
  default     = "pd-balanced"

  validation {
    condition     = contains(["pd-ssd", "local-ssd", "pd-balanced", "pd-standard"], var.nomad_audit_disk_type)
    error_message = "The value must be either pd-ssd, local-ssd, pd-balanced, pd-standard."
  }
}

variable "nomad_audit_disk_size" {
  type        = number
  description = "(optional) The disk size (GB) to use to create the Nomad audit log disk"
  default     = 50
}

variable "machine_type" {
  type        = string
  description = "(optional) The machine type to use for the Nomad nodes"
  default     = "n2-standard-4"
}

variable "metadata" {
  type        = map(string)
  description = "(optional) Metadata to add to the Compute Instance template"
  default     = null
}

variable "enable_auto_healing" {
  type        = bool
  description = "(optional) Enable auto-healing on the Instance Group"
  default     = false
}

variable "initial_auto_healing_delay" {
  type        = number
  description = "(optional) The time, in seconds, that the managed instance group waits before it applies autohealing policies"
  default     = 1200 #300

  validation {
    condition     = var.initial_auto_healing_delay >= 0 && var.initial_auto_healing_delay <= 3600
    error_message = "The value must be greater than or equal to 0 and less than or equal to 3600s."
  }
}

variable "enable_iap" {
  type        = bool
  default     = true
  description = "(Optional bool) Enable https://cloud.google.com/iap/docs/using-tcp-forwarding#console, defaults to `true`. "
}

#-----------------------------------------------------------------------------------
# IAM variables
#-----------------------------------------------------------------------------------
variable "google_service_account_iam_roles" {
  type        = list(string)
  description = "(optional) List of IAM roles to give to the Nomad service account"
  default = [
    "roles/compute.viewer",
    "roles/secretmanager.secretAccessor",
    "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  ]
}

#------------------------------------------------------------------------------
# GCS
#------------------------------------------------------------------------------
variable "nomad_snapshot_gcs_bucket_name" {
  type        = string
  description = "Name of Google Cloud Storage bucket to hold Nomad snapshots"
  nullable    = true
  default     = null
}

#-----------------------------------------------------------------------------------
# Load balancer variables
#-----------------------------------------------------------------------------------
variable "load_balancing_scheme" {
  type        = string
  description = "(optional) Type of load balancer to use (INTERNAL, EXTERNAL, or NONE)"
  default     = "INTERNAL"

  validation {
    condition     = contains(["INTERNAL", "EXTERNAL", "NONE"], var.load_balancing_scheme)
    error_message = "The load balancing scheme must be INTERNAL, EXTERNAL, or NONE."
  }
}

variable "health_check_interval" {
  type        = number
  description = "(optional) How often, in seconds, to send a health check"
  default     = 30
}

variable "health_timeout" {
  type        = number
  description = "(optional) How long, in seconds, to wait before claiming failure"
  default     = 15
}

