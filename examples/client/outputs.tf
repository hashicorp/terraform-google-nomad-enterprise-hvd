 # Copyright (c) HashiCorp, Inc.
 # SPDX-License-Identifier: MPL-2.0

 #------------------------------------------------------------------------------
 # Nomad URLs
 #------------------------------------------------------------------------------
 output "nomad_url" {
   value = module.nomad.nomad_url
 }
