# Configuration Reference — Nomad Enterprise HVD on GCP

Complete reference for all input variables accepted by the `terraform-google-nomad-enterprise-hvd` module. Variables are grouped by functional area.

---

## Required Variables

These variables have no default and must be set in every deployment.

| Variable | Type | Description |
|---|---|---|
| `project_id` | `string` | GCP project ID to deploy all resources into |
| `nomad_fqdn` | `string` | Fully qualified domain name used for Nomad peer joining and optionally Cloud DNS. Example: `nomad.internal.example.com` |
| `nomad_server` | `bool` | `true` to deploy server nodes. Exactly one of `nomad_server` or `nomad_client` must be `true` |
| `nomad_client` | `bool` | `true` to deploy client nodes. Exactly one of `nomad_server` or `nomad_client` must be `true` |
| `nomad_datacenter` | `string` | Nomad datacenter name for this deployment (e.g. `dc1`). Used in TLS SAN validation and cluster config |
| `nomad_license_sm_secret_name` | `string` | Name of the GCP Secret Manager secret containing the Nomad Enterprise license string |
| `nomad_gossip_key_secret_name` | `string` | Name of the GCP Secret Manager secret containing the base64 gossip encryption key |
| `nomad_tls_cert_sm_secret_name` | `string` | Name of the GCP Secret Manager secret containing the base64-encoded TLS certificate PEM |
| `nomad_tls_privkey_sm_secret_name` | `string` | Name of the GCP Secret Manager secret containing the base64-encoded TLS private key PEM |
| `nomad_tls_ca_bundle_sm_secret_name` | `string` | Name of the GCP Secret Manager secret containing the base64-encoded CA bundle PEM |

---

## Common Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `region` | `string` | `"us-central1"` | GCP region for all resources |
| `application_prefix` | `string` | `"nomad"` | Prefix applied to all GCP resource names (e.g. `myco-nomad`) |
| `tags` | `list(string)` | `["nomad"]` | Network tags assigned to all instances. The first tag is used as the auto-join tag by default |
| `common_labels` | `map(string)` | `{}` | Labels applied to all GCP resources. Use for cost allocation, environment tagging, etc. |

---

## Nomad Configuration

### Cluster Topology

| Variable | Type | Default | Description |
|---|---|---|---|
| `nomad_nodes` | `number` | `6` | Number of Nomad nodes to deploy. Sets `bootstrap_expect` on server nodes. Odd numbers (3 or 6) are recommended |
| `nomad_region` | `string` | `null` | Nomad region name. Multiple datacenters can share a region. Defaults to `"global"` in Nomad when unset |
| `nomad_datacenter` | `string` | required | Datacenter name. Must match the SAN on TLS certificates (e.g. `dc1`) |
| `nomad_version` | `string` | `"1.9.5+ent"` | Nomad Enterprise version to install. Must include the `+ent` suffix |

### Ports

| Variable | Type | Default | Description |
|---|---|---|---|
| `nomad_port_api` | `number` | `4646` | TCP port for the Nomad HTTP API and UI |
| `nomad_port_rpc` | `number` | `4647` | TCP port for Nomad RPC (server-to-server and client-to-server) |
| `nomad_port_serf` | `number` | `4648` | TCP/UDP port for Nomad Serf gossip (LAN) |

### TLS

| Variable | Type | Default | Description |
|---|---|---|---|
| `nomad_tls_enabled` | `bool` | `true` | Enable TLS for the Nomad API and RPC. **Never set to `false` in production** |
| `nomad_tls_disable_client_certs` | `bool` | `true` | Disable mutual TLS client certificate requirement on the API listener. Required when using the TLS auth method |
| `nomad_tls_require_and_verify_client_cert` | `bool` | `false` | Require clients to present a certificate that validates against system CAs |

See the [TLS Guide](./tls-guide.md) for certificate generation instructions.

### ACLs

| Variable | Type | Default | Description |
|---|---|---|---|
| `nomad_acl_enabled` | `bool` | `true` | Enable ACL system. See the [ACL Guide](./acl-guide.md) for bootstrapping instructions |

### Autopilot

| Variable | Type | Default | Description |
|---|---|---|---|
| `autopilot_health_enabled` | `bool` | `true` | Enable Autopilot with redundancy zones. When `true`, servers in the same GCP zone are treated as the same redundancy zone. Requires an odd number of zones |

### Auto-Join

| Variable | Type | Default | Description |
|---|---|---|---|
| `auto_join_tag` | `list(string)` | `null` | Network tag used by GCE auto-join. If `null`, the first value in `tags` is used. Instances must carry this tag for discovery to work |

### Client Settings

| Variable | Type | Default | Description |
|---|---|---|---|
| `nomad_upstream_servers` | `list(string)` | `null` | Static list of server addresses for client nodes (e.g. `["10.0.0.1:4647"]`). When `null`, clients use GCE auto-join to discover servers |
| `cni_version` | `string` | `"1.6.0"` | CNI plugins version to install on client nodes. Format: `X.Y.Z` |

### Miscellaneous

| Variable | Type | Default | Description |
|---|---|---|---|
| `nomad_enable_ui` | `bool` | `true` | Enable the Nomad web UI |

---

## Networking

| Variable | Type | Default | Description |
|---|---|---|---|
| `network` | `string` | `"default"` | Name of the VPC network |
| `subnetwork` | `string` | `"default"` | Name of the subnet within `network` |
| `network_project_id` | `string` | `null` | Project ID of the VPC network. Required for Shared VPC. Leave `null` if network is in the same project |
| `network_region` | `string` | `null` | Region of the VPC network. Leave `null` if network is in the same region as `region` |
| `cidr_ingress_api_allow` | `list(string)` | `["0.0.0.0/0"]` | CIDR ranges allowed to reach the Nomad API (port 4646). **Restrict to your management CIDRs in production** |
| `cidr_ingress_rpc_allow` | `list(string)` | `["0.0.0.0/0"]` | CIDR ranges allowed to reach Nomad RPC/Serf ports. **Restrict to internal CIDRs in production** |

---

## Compute

| Variable | Type | Default | Description |
|---|---|---|---|
| `machine_type` | `string` | `"n2-standard-4"` | GCE machine type for Nomad nodes. `n2-standard-4` provides 4 vCPU / 16 GB RAM |
| `node_count` | `number` | `6` | Number of instances in the Regional MIG |
| `nomad_architecture` | `string` | `"amd64"` | CPU architecture of the Nomad binary. Valid values: `amd64`, `arm64` |
| `compute_image_family` | `string` | `"ubuntu-2204-lts"` | GCE image family for the boot disk. See [GCE OS details](https://cloud.google.com/compute/docs/images/os-details) |
| `compute_image_project` | `string` | `"ubuntu-os-cloud"` | GCP project that owns the compute image family |
| `packer_image` | `string` | `null` | Full image path for a custom Packer image (e.g. `projects/my-project/global/images/nomad-hardened-v1`). When set, overrides `compute_image_family` and `compute_image_project` |
| `metadata` | `map(string)` | `null` | Additional GCE instance metadata key-value pairs |
| `nomad_metadata_template` | `string` | `"nomad_custom_data.sh.tpl"` | Filename of the startup script template. Place custom templates in `./templates/` of your Terraform workspace |
| `additional_package_names` | `set(string)` | `[]` | Extra OS packages to install at boot time via `apt-get` or `yum` |

### Disks

| Variable | Type | Default | Description |
|---|---|---|---|
| `boot_disk_type` | `string` | `"pd-balanced"` | Boot disk type. Valid: `pd-ssd`, `pd-balanced`, `pd-standard`, `local-ssd` |
| `boot_disk_size` | `number` | `30` | Boot disk size in GB |
| `nomad_data_disk_type` | `string` | `"pd-ssd"` | Data disk type (mounted at `nomad_dir_home`). `pd-ssd` recommended for Raft performance |
| `nomad_data_disk_size` | `number` | `500` | Data disk size in GB |
| `nomad_audit_disk_type` | `string` | `"pd-balanced"` | Audit log disk type (mounted at `nomad_dir_logs`) |
| `nomad_audit_disk_size` | `number` | `50` | Audit log disk size in GB |

### Auto-Healing

| Variable | Type | Default | Description |
|---|---|---|---|
| `enable_auto_healing` | `bool` | `false` | Enable MIG auto-healing. When `true`, unhealthy instances are automatically replaced |
| `initial_auto_healing_delay` | `number` | `1200` | Seconds to wait before auto-healing begins after instance creation. Range: 0–3600 |
| `health_check_interval` | `number` | `30` | Seconds between health check probes |
| `health_timeout` | `number` | `15` | Seconds to wait for a health check response before marking the instance unhealthy |

---

## IAP

| Variable | Type | Default | Description |
|---|---|---|---|
| `enable_iap` | `bool` | `true` | Create a firewall rule allowing IAP TCP forwarding (SSH via `gcloud compute ssh --tunnel-through-iap`). Recommended when instances have no public IPs |

---

## IAM

| Variable | Type | Default | Description |
|---|---|---|---|
| `google_service_account_iam_roles` | `list(string)` | `["roles/compute.viewer", "roles/secretmanager.secretAccessor", "roles/cloudkms.cryptoKeyEncrypterDecrypter"]` | IAM roles granted to the Nomad service account. Extend this list to grant access to additional GCP services |

---

## Load Balancer

| Variable | Type | Default | Description |
|---|---|---|---|
| `load_balancing_scheme` | `string` | `"INTERNAL"` | Load balancer type. Valid: `INTERNAL` (private), `EXTERNAL` (public), `NONE` (no LB) |

---

## DNS

| Variable | Type | Default | Description |
|---|---|---|---|
| `create_cloud_dns_record` | `bool` | `false` | Create a Cloud DNS `A` record for `nomad_fqdn` pointing to the load balancer IP |
| `cloud_dns_managed_zone` | `string` | `null` | Name of the Cloud DNS managed zone. Required when `create_cloud_dns_record = true` |

---

## Storage

| Variable | Type | Default | Description |
|---|---|---|---|
| `nomad_snapshot_gcs_bucket_name` | `string` | `null` | Name of an existing GCS bucket for Nomad snapshots. When set, the Nomad service account is granted `objectCreator` and `objectViewer` on the bucket |

---

## System Paths

These variables control where Nomad is installed and run. The defaults follow the [Nomad production deployment guidelines](https://developer.hashicorp.com/nomad/docs/install/production).

| Variable | Type | Default | Description |
|---|---|---|---|
| `nomad_user_name` | `string` | `"nomad"` | Linux user that owns Nomad files and runs the Nomad process. Client nodes use `root` regardless of this setting |
| `nomad_group_name` | `string` | `"nomad"` | Linux group for the Nomad user |
| `nomad_dir_bin` | `string` | `"/usr/bin"` | Directory for the Nomad binary |
| `nomad_dir_config` | `string` | `"/etc/nomad.d"` | Directory for Nomad configuration files |
| `nomad_dir_home` | `string` | `"/opt/nomad"` | Base directory for Nomad data, plugins, and license files. Mounted on the data disk |
| `nomad_dir_logs` | `string` | `"/var/log/nomad"` | Directory for Nomad audit logs. Mounted on the audit disk |
| `systemd_dir` | `string` | `"/lib/systemd/system"` | Directory for the Nomad systemd unit file |

---

## Outputs

| Output | Description |
|---|---|
| `nomad_url` | HTTPS URL to the Nomad UI: `https://<nomad_fqdn>:4646` |
| `nomad_cli_config` | Shell export statements for configuring the Nomad CLI (`NOMAD_ADDR`, `NOMAD_CACERT`, etc.) |
