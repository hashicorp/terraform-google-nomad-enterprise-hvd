# Nomad Enterprise HVD on GCP — Documentation

Documentation for the `terraform-google-nomad-enterprise-hvd` module.

## Guides

| Document | Type | Description |
|---|---|---|
| [Deployment Guide](./deployment-guide.md) | How-to | End-to-end walkthrough for deploying Nomad Enterprise on GCP using this module |
| [Prerequisites](./prereqs.md) | Reference | GCP APIs, networking, Secret Manager secrets, and IAM required before `terraform apply` |
| [TLS Certificates Guide](./tls-guide.md) | How-to | Generating, storing, and rotating Nomad-specific TLS certificates |
| [ACL Guide](./acl-guide.md) | How-to | Bootstrapping ACLs and managing policies and tokens |
| [Upgrade Guide](./upgrade-guide.md) | How-to | Zero-downtime Nomad version upgrades using MIG rolling replacement |
| [Architecture Overview](./architecture-overview.md) | Explanation | GCP resource topology, design decisions, and startup script flow |
| [Configuration Reference](./configuration-reference.md) | Reference | All input variables, grouped by functional area |

## Quick Start

```bash
# 1. Enable required GCP APIs
gcloud services enable compute.googleapis.com secretmanager.googleapis.com dns.googleapis.com

# 2. Store secrets
gcloud secrets create nomad-gossip-key --replication-policy=automatic
echo -n "$(nomad operator gossip keyring generate)" | gcloud secrets versions add nomad-gossip-key --data-file=-

# 3. Copy and configure the default example
cp -r examples/default environments/sandbox
cd environments/sandbox

# 4. Edit terraform.tfvars with your project_id, network, and secret names
# 5. Deploy
terraform init && terraform apply
```

See the [Deployment Guide](./deployment-guide.md) for the complete step-by-step walkthrough.
