# Nomad Enterprise HVD on GCP — Deployment Guide

This guide walks you through deploying Nomad Enterprise on Google Cloud Platform (GCP) using the `terraform-google-nomad-enterprise-hvd` module. It follows the recommended HashiCorp Validated Design (HVD): servers first, then clients.

## Prerequisites Checklist

Before you begin, confirm the following are in place. The [Prerequisites Reference](./prereqs.md) provides detailed setup instructions for each item.

- [ ] Terraform CLI `>= 1.9` installed
- [ ] GCP project created and billing enabled
- [ ] Required GCP APIs enabled (see [Prerequisites](./prereqs.md#required-gcp-apis))
- [ ] VPC and at least one subnet per availability zone provisioned (minimum 3 subnets for HA)
- [ ] Nomad Enterprise license stored in GCP Secret Manager
- [ ] Nomad gossip encryption key generated and stored in GCP Secret Manager
- [ ] TLS certificate, private key, and CA bundle stored as base64-encoded secrets in GCP Secret Manager
- [ ] GCP credentials configured (`gcloud auth application-default login` or service account key)

---

## Step 1 — Clone and Prepare Your Configuration

Copy the appropriate example to a new directory. Use the `default` example for a combined server+client setup, or use the separate `server` and `client` examples for dedicated node pools.

```bash
# Example structure for multiple environments
mkdir -p environments/production
cp -r examples/default/* environments/production/
cd environments/production
```

Recommended directory layout for managing multiple Nomad clusters:

```
.
└── environments
    ├── production
    │   ├── backend.tf
    │   ├── main.tf
    │   ├── outputs.tf
    │   ├── terraform.tfvars
    │   └── variables.tf
    └── sandbox
        ├── backend.tf
        ├── main.tf
        ├── outputs.tf
        ├── terraform.tfvars
        └── variables.tf
```

---

## Step 2 — Configure Remote State (Recommended)

Create a GCS bucket for Terraform state, then configure `backend.tf`:

```bash
gcloud storage buckets create gs://my-org-nomad-tfstate \
  --location=us-central1 \
  --uniform-bucket-level-access
```

```hcl
# backend.tf
terraform {
  backend "gcs" {
    bucket = "my-org-nomad-tfstate"
    prefix = "nomad/production"
  }
}
```

---

## Step 3 — Deploy Nomad Servers

Create your `terraform.tfvars` for the server deployment. The minimum required values are:

```hcl
# terraform.tfvars — Nomad Servers
project_id = "my-gcp-project-id"
region     = "us-central1"

# Networking
network    = "nomad-vpc"
subnetwork = "nomad-subnet"

# Secrets — names of the GCP Secret Manager secrets (not values)
nomad_license_sm_secret_name       = "nomad-enterprise-license"
nomad_gossip_key_secret_name       = "nomad-gossip-key"
nomad_tls_cert_sm_secret_name      = "nomad-tls-cert-base64"
nomad_tls_privkey_sm_secret_name   = "nomad-tls-privkey-base64"
nomad_tls_ca_bundle_sm_secret_name = "nomad-tls-ca-cert-base64"

# Nomad cluster topology
nomad_server    = true
nomad_client    = false
nomad_datacenter = "dc1"
nomad_region    = "global"
nomad_nodes     = 6
nomad_fqdn      = "nomad.internal.example.com"

# DNS (optional)
create_cloud_dns_record = false
```

Run the server deployment:

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

> **Note:** The `nomad_nodes` variable sets `bootstrap_expect` on the server cluster. Set this to an odd number (3 or 6 recommended) for quorum. The default of 6 provisions 3 voting and 3 non-voting servers across three zones using Autopilot redundancy zones.

---

## Step 4 — Monitor the Bootstrap

After `terraform apply` completes, the cloud-init script runs on each server instance. Monitor progress via SSH using IAP (Identity-Aware Proxy):

```bash
# Find an instance name
gcloud compute instances list --filter="tags.items=nomad-backend" --project=my-gcp-project-id

# SSH via IAP (no public IP required)
gcloud compute ssh nomad-nomad-vm-xxxx \
  --tunnel-through-iap \
  --project=my-gcp-project-id \
  --zone=us-central1-a

# Monitor cloud-init
tail -f /var/log/nomad-cloud-init.log
```

Wait until you see `nomad_custom_data script finished successfully!` in the log.

---

## Step 5 — Verify Nomad Server Cluster Health

Once all servers are bootstrapped, verify the cluster from any server instance:

```bash
# Check server membership
nomad server members

# Check cluster status
nomad status

# Verify Autopilot health
nomad operator autopilot get-config
```

Expected output from `nomad server members` shows all 6 nodes (`alive`) with 3 marked as `voter`.

---

## Step 6 — Bootstrap ACLs (if enabled)

If `nomad_acl_enabled = true` (the default), bootstrap the ACL system **once** from any server node:

```bash
nomad acl bootstrap
```

This outputs a `SecretID` (bootstrap token). Store it securely — it cannot be retrieved again.

```
Accessor ID  = 3b4f1b24-...
Secret ID    = a8b87fd7-...   ← store this securely
Name         = Bootstrap Token
Type         = management
```

Set the environment variable for subsequent CLI operations:

```bash
export NOMAD_TOKEN="a8b87fd7-..."
```

See the [ACL Guide](./acl-guide.md) for policy management and token rotation.

---

## Step 7 — Deploy Nomad Clients

Create a separate `terraform.tfvars` for clients, pointing to the existing server cluster:

```hcl
# terraform.tfvars — Nomad Clients
project_id = "my-gcp-project-id"
region     = "us-central1"

# Same networking as servers
network    = "nomad-vpc"
subnetwork = "nomad-subnet"

# Secrets (TLS and gossip are shared; no license required for clients)
nomad_gossip_key_secret_name       = "nomad-gossip-key"
nomad_tls_cert_sm_secret_name      = "nomad-tls-cert-base64"
nomad_tls_privkey_sm_secret_name   = "nomad-tls-privkey-base64"
nomad_tls_ca_bundle_sm_secret_name = "nomad-tls-ca-cert-base64"
nomad_license_sm_secret_name       = "nomad-enterprise-license"  # required by module, unused by clients at runtime

# Client-specific settings
nomad_server    = false
nomad_client    = true
nomad_datacenter = "dc1"
nomad_region    = "global"
nomad_fqdn      = "nomad.internal.example.com"

# Optionally pin to specific server addresses
# nomad_upstream_servers = ["10.128.0.10:4647", "10.128.0.11:4647", "10.128.0.12:4647"]
```

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

> **Note:** By default, clients use GCE auto-join (`provider=gce`) to discover servers by network tag. Set `nomad_upstream_servers` to hard-code server addresses, which is recommended when server and client deployments are in separate Terraform workspaces.

---

## Step 8 — Configure the Nomad CLI Locally

Use the outputs from the Terraform deployment to configure your local Nomad CLI:

```bash
# From the Terraform output
terraform output nomad_cli_config
```

This outputs the environment variables needed:

```bash
export NOMAD_ADDR="https://nomad.internal.example.com:4646"
export NOMAD_CACERT="/path/to/ca.pem"
export NOMAD_CLIENT_CERT="/path/to/cert.pem"
export NOMAD_CLIENT_KEY="/path/to/key.pem"
export NOMAD_TOKEN="<your-acl-token>"
```

Verify connectivity:

```bash
nomad server members
nomad node status
```

---

## Step 9 — Enable a Workload Runtime (Optional)

Nomad supports multiple workload drivers. The `install_runtime` function in [`templates/nomad_custom_data.sh.tpl`](../templates/nomad_custom_data.sh.tpl) is a placeholder. Uncomment and extend it to install your required runtime before deploying clients.

**Docker example:**

```bash
# In templates/nomad_custom_data.sh.tpl → install_runtime()
function install_runtime {
    if [[ "$OS_DISTRO" == "ubuntu" ]]; then
        apt-get install -y docker.io
        usermod -G docker -a $NOMAD_USER
        systemctl enable --now docker
    fi
}
```

Set `nomad_metadata_template` to point to your custom template in `terraform.tfvars`:

```hcl
nomad_metadata_template = "nomad_custom_data.sh.tpl"
```

Place your custom template in the `./templates/` directory of your Terraform workspace.

---

## Verification Summary

| Check | Command |
|---|---|
| Server cluster health | `nomad server members` |
| Client registration | `nomad node status` |
| ACL bootstrap status | `nomad acl token self` |
| Nomad UI | `https://<nomad_fqdn>:4646/ui` |
| Cloud-init log | `tail /var/log/nomad-cloud-init.log` |

---

## Next Steps

- [Prerequisites Reference](./prereqs.md) — detailed GCP setup for networking, APIs, and secrets
- [Architecture Overview](./architecture-overview.md) — understand the GCP topology and design
- [TLS Guide](./tls-guide.md) — generate and rotate Nomad-specific TLS certificates
- [ACL Guide](./acl-guide.md) — manage policies and tokens
- [Configuration Reference](./configuration-reference.md) — full variable reference
- [Upgrade Guide](./upgrade-guide.md) — zero-downtime Nomad version upgrades
