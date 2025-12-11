# Copyright IBM Corp. 2025
# SPDX-License-Identifier: MPL-2.0

output "nomad_url" {
  value       = module.nomad.nomad_url
  description = "URL to access Nomad application based on value of `nomad_fqdn` input."
}

output "nomad_cli_config" {
  value       = module.nomad.nomad_cli_config
  description = "Environment variables to configure the nomad CLI"
}
