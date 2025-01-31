 # Copyright (c) HashiCorp, Inc.
 # SPDX-License-Identifier: MPL-2.0

 #------------------------------------------------------------------------------
 # Nomad URLs
 #------------------------------------------------------------------------------
 output "nomad_url" {
   value = module.nomad.nomad_url
 }

 output "nomad_cli_config" {
   value = module.nomad.nomad_cli_config
 }
