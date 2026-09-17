# Architecture Overview — Nomad Enterprise HVD on GCP

This document explains the Google Cloud architecture that the `terraform-google-nomad-enterprise-hvd` module provisions, the design decisions behind it, and how the components fit together to deliver a production-ready Nomad Enterprise cluster.

---

## High-Level Architecture

```
┌───────────────────────────────────────────────────────────────────────────────┐
│  GCP Project                                                                  │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────────┐ │
│  │  VPC Network (customer-managed)                                          │ │
│  │                                                                          │ │
│  │  ┌────────────────────────────────────────────────────────────────────┐  │ │
│  │  │  Regional Subnet (e.g. us-central1)                                │  │ │
│  │  │                                                                    │  │ │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │  │ │
│  │  │  │  Zone A       │  │  Zone B       │  │  Zone C       │            │  │ │
│  │  │  │  Nomad VM     │  │  Nomad VM     │  │  Nomad VM     │            │  │ │
│  │  │  │  (server or   │  │  (server or   │  │  (server or   │  ...       │  │ │
│  │  │  │   client)     │  │   client)     │  │   client)     │            │  │ │
│  │  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘            │  │ │
│  │  │         │                 │                  │                    │  │ │
│  │  │         └─────────────────┼──────────────────┘                    │  │ │
│  │  │                           │                                       │  │ │
│  │  │                 ┌─────────▼──────────┐                            │  │ │
│  │  │                 │  Regional MIG       │                            │  │ │
│  │  │                 │  (Instance Group    │                            │  │ │
│  │  │                 │   Manager)          │                            │  │ │
│  │  │                 └─────────┬──────────┘                            │  │ │
│  │  │                           │                                       │  │ │
│  │  │          ┌────────────────▼───────────────────┐                   │  │ │
│  │  │          │  Internal/External Load Balancer    │                   │  │ │
│  │  │          │  (Regional Backend Service +        │                   │  │ │
│  │  │          │   Forwarding Rule on TCP/4646)       │                   │  │ │
│  │  │          └────────────────────────────────────┘                   │  │ │
│  │  └────────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                          │ │
│  └──────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  ┌────────────────────────┐   ┌────────────────────────┐                     │
│  │  Secret Manager         │   │  Cloud DNS (optional)   │                     │
│  │  - nomad-license        │   │  nomad.internal.co      │                     │
│  │  - nomad-gossip-key     │   │   → LB IP               │                     │
│  │  - tls-cert (b64)       │   └────────────────────────┘                     │
│  │  - tls-privkey (b64)    │                                                   │
│  │  - tls-ca (b64)         │   ┌────────────────────────┐                     │
│  └────────────────────────┘   │  GCS Bucket (optional)  │                     │
│                               │  - Nomad snapshots       │                     │
│  ┌────────────────────────┐   └────────────────────────┘                     │
│  │  Service Account        │                                                   │
│  │  (compute.viewer,       │                                                   │
│  │   secretmanager.        │                                                   │
│  │   secretAccessor)       │                                                   │
│  └────────────────────────┘                                                   │
└───────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Breakdown

### Compute Engine Instance Template

A single `google_compute_instance_template` is created per module invocation. It defines:

- **Machine type** — defaults to `n2-standard-4` (4 vCPU / 16 GB RAM); tune with `machine_type`
- **Boot disk** — Ubuntu 22.04 LTS (`ubuntu-2204-lts`), `pd-balanced`, 30 GB
- **Data disk** — `pd-ssd`, 500 GB, mounted at `/opt/nomad` (Nomad data directory)
- **Audit log disk** — `pd-balanced`, 50 GB, mounted at `/var/log/nomad` (audit logs)
- **Startup script** — `nomad_custom_data.sh.tpl`, which installs and configures Nomad at first boot
- **Service account** — the module-created Nomad service account with `cloud-platform` scope

The template uses `create_before_destroy = true` so rolling updates replace instances without downtime.

### Regional Managed Instance Group (MIG)

The `google_compute_region_instance_group_manager` manages the lifecycle of all Nomad nodes within a region. Key properties:

- **Distribution policy** — instances are spread across exactly 3 zones (`slice(available_zones, 0, 3)`) regardless of `node_count`, ensuring Raft quorum is never concentrated in a single zone
- **Target size** — controlled by `node_count` (default: 6)
- **Update policy** — `OPPORTUNISTIC` replacement with `max_surge_fixed` equal to the number of available zones and `max_unavailable_fixed = 0`, ensuring zero-downtime rolling updates
- **Auto-healing** — optional; when `enable_auto_healing = true`, unhealthy instances are automatically replaced after `initial_auto_healing_delay` seconds (default: 1200s / 20 min)

### Load Balancer

The module supports three load balancing schemes controlled by `load_balancing_scheme`:

| Scheme | Use case |
|---|---|
| `INTERNAL` (default) | Private clusters; LB IP is accessible only within the VPC |
| `EXTERNAL` | Clusters that need to be reachable from outside the VPC |
| `NONE` | No load balancer; useful when Consul service mesh handles routing |

When a load balancer is provisioned (`INTERNAL` or `EXTERNAL`), the module creates:

1. **`google_compute_region_health_check`** — HTTPS health check on `/v1/agent/health` at port 4646
2. **`google_compute_region_backend_service`** — TCP backend pointing to the MIG
3. **`google_compute_forwarding_rule`** — Forwards TCP/4646 to the backend service
4. **`google_compute_firewall.allow_nomad_health_checks`** — Allows GCP health check probe ranges to reach instances

### GCP Secret Manager Integration

Nomad's license, TLS certificates, and gossip key are never baked into the machine image. Instead, they are fetched at boot time via `gcloud secrets versions access` in the startup script. This means:

- Secrets can be rotated without rebuilding the image
- Instances require only `roles/secretmanager.secretAccessor` on the project
- No secrets are stored in Terraform state or instance metadata

### GCE Auto-Join

Nomad uses the `go-discover` GCE provider for automatic cluster formation. Instances tag themselves with a configurable network tag (default: `nomad`) and the startup script generates this Nomad configuration stanza:

```hcl
server_join {
  retry_join = ["provider=gce zone_pattern=us-central1-[a-z] tag_value=nomad"]
}
```

The `zone_pattern` is derived from `var.region` at render time, scoping auto-join to the deployment region. This removes the need to know instance IPs in advance.

### IAP SSH Access

When `enable_iap = true` (the default), the module creates a firewall rule allowing TCP/22 from the IAP proxy range (`35.235.240.0/20`). This lets operators SSH to instances through IAP without requiring public IP addresses or a bastion host:

```bash
gcloud compute ssh INSTANCE_NAME \
  --tunnel-through-iap \
  --project=PROJECT_ID \
  --zone=us-central1-a
```

---

## Deployment Topology

### Server Cluster (Recommended: 6 nodes)

The HVD recommendation is 6 server nodes spread across 3 zones (2 per zone). With Autopilot redundancy zones enabled (`autopilot_health_enabled = true`), Nomad treats each zone as a redundancy zone:

- Zones A, B, C each host 2 servers
- 3 servers are **voters** (one per zone) — these participate in Raft quorum
- 3 servers are **non-voters** — they follow the leader but do not vote

This configuration tolerates the loss of an entire zone while maintaining a majority of voters (2/3 remain).

```
Zone A: voter + non-voter  \
Zone B: voter + non-voter  ─── 3 voters → quorum maintained if 1 zone fails
Zone C: voter + non-voter  /
```

### Client Pool

Clients are deployed as a separate module invocation with `nomad_server = false, nomad_client = true`. Clients:

- Do not participate in Raft
- Join the cluster by auto-joining on the server tag, or via `nomad_upstream_servers`
- Run workloads scheduled by the server cluster
- Run as `root` (required by Nomad for workload isolation and CNI)

### Multi-Datacenter

For multi-datacenter deployments, deploy the module once per datacenter, setting `nomad_datacenter` and `nomad_region` to match your Nomad topology:

```hcl
# us-central1 datacenter
nomad_datacenter = "us-central"
nomad_region     = "global"

# europe-west1 datacenter (separate module invocation)
nomad_datacenter = "eu-west"
nomad_region     = "global"
```

---

## Startup Script Flow

The `nomad_custom_data.sh.tpl` startup script runs once on first boot via Google's `metadata_startup_script` mechanism. The execution order is:

```
detect OS & architecture
       │
install prerequisites (curl, jq, unzip)
       │
install gcloud SDK (if not present)
       │
prepare data disk (format ext4, mount at /opt/nomad)
prepare audit disk (format ext4, mount at /var/log/nomad)
       │
create nomad user/group
create directory tree
       │
download & verify Nomad binary (GPG + SHA256)
install binary to /usr/bin/nomad
       │
[client only] install runtime + CNI plugins + sysctl
[server only] fetch license from Secret Manager
fetch gossip key from Secret Manager (servers only)
[if TLS]     fetch TLS cert, key, CA from Secret Manager
       │
generate /etc/nomad.d/nomad.hcl
generate /lib/systemd/system/nomad.service
       │
systemctl enable + start nomad
```

Log output is written to `/var/log/nomad-cloud-init.log` on each instance.

---

## Security Design Decisions

| Decision | Rationale |
|---|---|
| No public IPs on instances | Access via IAP; reduces attack surface |
| Secrets in Secret Manager, not metadata | Secrets are not visible in Terraform state, GCP console metadata tab, or instance startup script arguments |
| TLS required by default (`nomad_tls_enabled = true`) | Encrypts all Nomad API, RPC, and gossip traffic; required for production |
| ACLs enabled by default (`nomad_acl_enabled = true`) | Enforces authorization for all API operations |
| Data and audit log on separate persistent disks | Isolates Nomad data from OS; allows independent disk type/size tuning and prevents audit logs from filling the OS disk |
| Gossip encryption required | Prevents unauthorised nodes from joining the cluster |
| `create_before_destroy` on instance template | Enables zero-downtime rolling updates |
