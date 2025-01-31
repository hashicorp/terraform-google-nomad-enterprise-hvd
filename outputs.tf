# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# Nomad URLs
#------------------------------------------------------------------------------

output "nomad_url" {
  value       = try("https://${var.nomad_fqdn}", null)
  description = "URL to access Nomad application based on value of `nomad_fqdn` input."
}

output "nomad_cli_config" {
  description = "Environment variables to configure the nomad CLI"
  value       = <<-EOF
     %{if var.nomad_server~}
       %{if var.load_balancing_scheme != "NONE"~}
       export NOMAD_ADDR=https://${var.nomad_fqdn}
       %{else~}
       # No load balancer created; set NOMAD_ADDR to the IPV4 address of any Nomad Server instance if this is a server deployment.
       export NOMAD_ADDR=https://<instance-ipv4>
       %{endif~}
       export NOMAD_TLS_SERVER_NAME=${var.nomad_fqdn}
       %{if var.nomad_tls_ca_bundle_sm_secret_name != null~}
       export NOMAD_CACERT=<path/to/ca-certificate>
       %{endif~}
     %{endif~}
   EOF
}
