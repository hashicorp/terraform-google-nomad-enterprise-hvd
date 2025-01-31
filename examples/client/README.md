# Nomad Enteprise HVD - Default Example

This example will deploy Nomad Clients to join an existing Nomad Cluster.
The clients can join via a specified tag with setting `auto_join_tag`
No Runtimes will be enabled by default. To enable a runtime, modify the `install_runtime` function in the `templates\nomad_custom_data.sh.tpl` with the code to enable any runtimes as needed.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 5.39 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_nomad"></a> [nomad](#module\_nomad) | ../.. | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_nomad_client"></a> [nomad\_client](#input\_nomad\_client) | Boolean to enable the Nomad client mode. | `bool` | n/a | yes |
| <a name="input_nomad_datacenter"></a> [nomad\_datacenter](#input\_nomad\_datacenter) | Specifies the data center of the local agent. A datacenter is an abstract grouping of clients within a region. Clients are not required to be in the same datacenter as the servers they are joined with, but do need to be in the same region. | `string` | n/a | yes |
| <a name="input_nomad_fqdn"></a> [nomad\_fqdn](#input\_nomad\_fqdn) | Fully qualified domain name to use for joining peer nodes and optionally DNS | `string` | n/a | yes |
| <a name="input_nomad_gossip_key_secret_name"></a> [nomad\_gossip\_key\_secret\_name](#input\_nomad\_gossip\_key\_secret\_name) | Name of Secret Manager secret containing Nomad gossip encryption key. | `string` | n/a | yes |
| <a name="input_nomad_license_sm_secret_name"></a> [nomad\_license\_sm\_secret\_name](#input\_nomad\_license\_sm\_secret\_name) | Name of Secret Manager secret containing Nomad license. | `string` | n/a | yes |
| <a name="input_nomad_server"></a> [nomad\_server](#input\_nomad\_server) | Boolean to enable the Nomad server mode. | `bool` | n/a | yes |
| <a name="input_nomad_tls_ca_bundle_sm_secret_name"></a> [nomad\_tls\_ca\_bundle\_sm\_secret\_name](#input\_nomad\_tls\_ca\_bundle\_sm\_secret\_name) | Name of Secret Manager containing Nomad TLS custom CA bundle. | `string` | n/a | yes |
| <a name="input_nomad_tls_cert_sm_secret_name"></a> [nomad\_tls\_cert\_sm\_secret\_name](#input\_nomad\_tls\_cert\_sm\_secret\_name) | Name of Secret Manager containing Nomad TLS certificate. | `string` | n/a | yes |
| <a name="input_nomad_tls_privkey_sm_secret_name"></a> [nomad\_tls\_privkey\_sm\_secret\_name](#input\_nomad\_tls\_privkey\_sm\_secret\_name) | Name of Secret Manager containing Nomad TLS private key. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | (required) The project ID to host the cluster in (required) | `string` | n/a | yes |
| <a name="input_additional_package_names"></a> [additional\_package\_names](#input\_additional\_package\_names) | List of additional repository package names to install | `set(string)` | `[]` | no |
| <a name="input_application_prefix"></a> [application\_prefix](#input\_application\_prefix) | (optional) The prefix to give to cloud entities | `string` | `"nomad"` | no |
| <a name="input_auto_join_tag"></a> [auto\_join\_tag](#input\_auto\_join\_tag) | (optional) A list of a tag which will be used by Nomad to join other nodes to the cluster. If left blank, the module will use the first entry in `tags` | `list(string)` | `null` | no |
| <a name="input_autopilot_health_enabled"></a> [autopilot\_health\_enabled](#input\_autopilot\_health\_enabled) | Whether autopilot upgrade migration validation is performed for server nodes at boot-time | `bool` | `true` | no |
| <a name="input_boot_disk_size"></a> [boot\_disk\_size](#input\_boot\_disk\_size) | (optional) The disk size (GB) to use to create the boot disk | `number` | `30` | no |
| <a name="input_boot_disk_type"></a> [boot\_disk\_type](#input\_boot\_disk\_type) | (optional) The disk type to use to create the boot disk | `string` | `"pd-balanced"` | no |
| <a name="input_cidr_ingress_api_allow"></a> [cidr\_ingress\_api\_allow](#input\_cidr\_ingress\_api\_allow) | CIDR ranges to allow API traffic inbound to Nomad instance(s). | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_cidr_ingress_rpc_allow"></a> [cidr\_ingress\_rpc\_allow](#input\_cidr\_ingress\_rpc\_allow) | CIDR ranges to allow RPC traffic inbound to Nomad instance(s). | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_cloud_dns_managed_zone"></a> [cloud\_dns\_managed\_zone](#input\_cloud\_dns\_managed\_zone) | Zone name to create Cloud DNS record in if `create_cloud_dns_record` is set to `true`. | `string` | `null` | no |
| <a name="input_cni_version"></a> [cni\_version](#input\_cni\_version) | Version of CNI plugin to install. | `string` | `"1.6.0"` | no |
| <a name="input_common_labels"></a> [common\_labels](#input\_common\_labels) | (optional) Common labels to apply to GCP resources. | `map(string)` | `{}` | no |
| <a name="input_compute_image_family"></a> [compute\_image\_family](#input\_compute\_image\_family) | (optional) The family name of the image, https://cloud.google.com/compute/docs/images/os-details,defaults to `Ubuntu` | `string` | `"ubuntu-2204-lts"` | no |
| <a name="input_compute_image_project"></a> [compute\_image\_project](#input\_compute\_image\_project) | (optional) The project name of the image, https://cloud.google.com/compute/docs/images/os-details, defaults to `Ubuntu` | `string` | `"ubuntu-os-cloud"` | no |
| <a name="input_create_cloud_dns_record"></a> [create\_cloud\_dns\_record](#input\_create\_cloud\_dns\_record) | Boolean to create Google Cloud DNS record for `nomad_fqdn` resolving to load balancer IP. `cloud_dns_managed_zone` is required when `true`. | `bool` | `false` | no |
| <a name="input_enable_auto_healing"></a> [enable\_auto\_healing](#input\_enable\_auto\_healing) | (optional) Enable auto-healing on the Instance Group | `bool` | `false` | no |
| <a name="input_enable_iap"></a> [enable\_iap](#input\_enable\_iap) | (Optional bool) Enable https://cloud.google.com/iap/docs/using-tcp-forwarding#console, defaults to `true`. | `bool` | `true` | no |
| <a name="input_google_service_account_iam_roles"></a> [google\_service\_account\_iam\_roles](#input\_google\_service\_account\_iam\_roles) | (optional) List of IAM roles to give to the Nomad service account | `list(string)` | <pre>[<br/>  "roles/compute.viewer",<br/>  "roles/secretmanager.secretAccessor",<br/>  "roles/cloudkms.cryptoKeyEncrypterDecrypter"<br/>]</pre> | no |
| <a name="input_health_check_interval"></a> [health\_check\_interval](#input\_health\_check\_interval) | (optional) How often, in seconds, to send a health check | `number` | `30` | no |
| <a name="input_health_timeout"></a> [health\_timeout](#input\_health\_timeout) | (optional) How long, in seconds, to wait before claiming failure | `number` | `15` | no |
| <a name="input_initial_auto_healing_delay"></a> [initial\_auto\_healing\_delay](#input\_initial\_auto\_healing\_delay) | (optional) The time, in seconds, that the managed instance group waits before it applies autohealing policies | `number` | `1200` | no |
| <a name="input_load_balancing_scheme"></a> [load\_balancing\_scheme](#input\_load\_balancing\_scheme) | (optional) Type of load balancer to use (INTERNAL, EXTERNAL, or NONE) | `string` | `"INTERNAL"` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | (optional) The machine type to use for the Nomad nodes | `string` | `"n2-standard-4"` | no |
| <a name="input_metadata"></a> [metadata](#input\_metadata) | (optional) Metadata to add to the Compute Instance template | `map(string)` | `null` | no |
| <a name="input_network"></a> [network](#input\_network) | (optional) The VPC network to host the cluster in | `string` | `"default"` | no |
| <a name="input_network_project_id"></a> [network\_project\_id](#input\_network\_project\_id) | (optional) The project that the VPC network lives in. Can be left blank if network is in the same project as provider | `string` | `null` | no |
| <a name="input_network_region"></a> [network\_region](#input\_network\_region) | (optional) The region that the VPC network lives in. Can be left blank if network is in the same region as provider | `string` | `null` | no |
| <a name="input_node_count"></a> [node\_count](#input\_node\_count) | (optional) The number of nodes to create in the pool | `number` | `6` | no |
| <a name="input_nomad_acl_enabled"></a> [nomad\_acl\_enabled](#input\_nomad\_acl\_enabled) | Boolean to enable ACLs for Nomad. | `bool` | `true` | no |
| <a name="input_nomad_architecture"></a> [nomad\_architecture](#input\_nomad\_architecture) | Architecture of the Nomad binary to install. | `string` | `"amd64"` | no |
| <a name="input_nomad_audit_disk_size"></a> [nomad\_audit\_disk\_size](#input\_nomad\_audit\_disk\_size) | (optional) The disk size (GB) to use to create the Nomad audit log disk | `number` | `50` | no |
| <a name="input_nomad_audit_disk_type"></a> [nomad\_audit\_disk\_type](#input\_nomad\_audit\_disk\_type) | (optional) The disk type to use to create the Nomad audit log disk | `string` | `"pd-balanced"` | no |
| <a name="input_nomad_data_disk_size"></a> [nomad\_data\_disk\_size](#input\_nomad\_data\_disk\_size) | (optional) The disk size (GB) to use to create the disk | `number` | `500` | no |
| <a name="input_nomad_data_disk_type"></a> [nomad\_data\_disk\_type](#input\_nomad\_data\_disk\_type) | (optional) The disk type to use to create the Nomad data disk | `string` | `"pd-ssd"` | no |
| <a name="input_nomad_dir_bin"></a> [nomad\_dir\_bin](#input\_nomad\_dir\_bin) | Path to install Nomad Enterprise binary | `string` | `"/usr/bin"` | no |
| <a name="input_nomad_dir_config"></a> [nomad\_dir\_config](#input\_nomad\_dir\_config) | Path to install Nomad Enterprise binary | `string` | `"/etc/nomad.d"` | no |
| <a name="input_nomad_dir_home"></a> [nomad\_dir\_home](#input\_nomad\_dir\_home) | Path to hold data, plugins and license directories | `string` | `"/opt/nomad"` | no |
| <a name="input_nomad_dir_logs"></a> [nomad\_dir\_logs](#input\_nomad\_dir\_logs) | Path to hold Nomad file audit device logs | `string` | `"/var/log/nomad"` | no |
| <a name="input_nomad_enable_ui"></a> [nomad\_enable\_ui](#input\_nomad\_enable\_ui) | (optional) Enable the Nomad UI | `bool` | `true` | no |
| <a name="input_nomad_group_name"></a> [nomad\_group\_name](#input\_nomad\_group\_name) | Name of group to own Nomad files and processes | `string` | `"nomad"` | no |
| <a name="input_nomad_metadata_template"></a> [nomad\_metadata\_template](#input\_nomad\_metadata\_template) | (optional) Alternative template file to provide for instance template metadata script. place the file in your local `./templates folder` no path required | `string` | `"nomad_custom_data.sh.tpl"` | no |
| <a name="input_nomad_nodes"></a> [nomad\_nodes](#input\_nomad\_nodes) | Number of Nomad nodes to deploy. | `number` | `6` | no |
| <a name="input_nomad_port_api"></a> [nomad\_port\_api](#input\_nomad\_port\_api) | TCP port for Nomad API listener | `number` | `4646` | no |
| <a name="input_nomad_port_rpc"></a> [nomad\_port\_rpc](#input\_nomad\_port\_rpc) | TCP port for Nomad cluster address | `number` | `4647` | no |
| <a name="input_nomad_port_serf"></a> [nomad\_port\_serf](#input\_nomad\_port\_serf) | TCP port for Nomad cluster address | `number` | `4648` | no |
| <a name="input_nomad_region"></a> [nomad\_region](#input\_nomad\_region) | Specifies the region of the local agent. A region is an abstract grouping of datacenters. Clients are not required to be in the same region as the servers they are joined with, but do need to be in the same datacenter. If not specified, the region is set AWS region. | `string` | `null` | no |
| <a name="input_nomad_snapshot_gcs_bucket_name"></a> [nomad\_snapshot\_gcs\_bucket\_name](#input\_nomad\_snapshot\_gcs\_bucket\_name) | Name of Google Cloud Storage bucket to hold Nomad snapshots | `string` | `null` | no |
| <a name="input_nomad_tls_disable_client_certs"></a> [nomad\_tls\_disable\_client\_certs](#input\_nomad\_tls\_disable\_client\_certs) | Disable client authentication for the Nomad listener. Must be enabled when tls auth method is used. | `bool` | `true` | no |
| <a name="input_nomad_tls_enabled"></a> [nomad\_tls\_enabled](#input\_nomad\_tls\_enabled) | Boolean to enable TLS for Nomad. | `bool` | `true` | no |
| <a name="input_nomad_tls_require_and_verify_client_cert"></a> [nomad\_tls\_require\_and\_verify\_client\_cert](#input\_nomad\_tls\_require\_and\_verify\_client\_cert) | (optional) Require a client to present a client certificate that validates against system CAs | `bool` | `false` | no |
| <a name="input_nomad_upstream_servers"></a> [nomad\_upstream\_servers](#input\_nomad\_upstream\_servers) | List of Nomad server addresses to join the Nomad client with. | `list(string)` | `null` | no |
| <a name="input_nomad_user_name"></a> [nomad\_user\_name](#input\_nomad\_user\_name) | Name of system user to own Nomad files and processes | `string` | `"nomad"` | no |
| <a name="input_nomad_version"></a> [nomad\_version](#input\_nomad\_version) | (optional) The version of Nomad to use | `string` | `"1.9.5+ent"` | no |
| <a name="input_packer_image"></a> [packer\_image](#input\_packer\_image) | (optional) The packer image to use | `string` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | (optional) The region to host the cluster in | `string` | `"us-central1"` | no |
| <a name="input_subnetwork"></a> [subnetwork](#input\_subnetwork) | (optional) The subnet in the VPC network to host the cluster in | `string` | `"default"` | no |
| <a name="input_systemd_dir"></a> [systemd\_dir](#input\_systemd\_dir) | Path to systemd directory for unit files | `string` | `"/lib/systemd/system"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | (optional) A list containing tags to assign to all resources | `list(string)` | <pre>[<br/>  "nomad"<br/>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_nomad_url"></a> [nomad\_url](#output\_nomad\_url) | n/a |
<!-- END_TF_DOCS -->
