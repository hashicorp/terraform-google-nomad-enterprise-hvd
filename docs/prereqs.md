# Prerequisites Reference — Nomad Enterprise HVD on GCP

This document describes every resource and configuration that must exist before deploying the `terraform-google-nomad-enterprise-hvd` module. Complete all sections before running `terraform apply`.

---

## Required Tools

| Tool | Minimum Version | Purpose |
|---|---|---|
| Terraform CLI | `>= 1.9` | Provision infrastructure |
| Google Cloud SDK (`gcloud`) | Latest stable | Authenticate, manage secrets, SSH via IAP |
| Git | Any | Version control |

Install the Google Cloud SDK:

```bash
# macOS (Homebrew)
brew install google-cloud-sdk

# Linux
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
tar xzf google-cloud-cli-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh
```

Authenticate:

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

---

## Required GCP APIs

The following APIs must be enabled in your GCP project before deploying:

```bash
gcloud services enable \
  compute.googleapis.com \
  dns.googleapis.com \
  secretmanager.googleapis.com \
  servicenetworking.googleapis.com \
  networkservices.googleapis.com \
  --project=YOUR_PROJECT_ID
```

| API | Purpose |
|---|---|
| `compute.googleapis.com` | Compute Engine instances, instance groups, health checks, load balancer, firewall rules |
| `secretmanager.googleapis.com` | Store and retrieve Nomad license, TLS certificates, and gossip key at boot time |
| `dns.googleapis.com` | Optional Cloud DNS record creation for `nomad_fqdn` |
| `servicenetworking.googleapis.com` | VPC networking services |
| `networkservices.googleapis.com` | Internal load balancer networking |

Verify APIs are enabled:

```bash
gcloud services list --enabled --filter="NAME:(compute.googleapis.com OR secretmanager.googleapis.com OR dns.googleapis.com)" --project=YOUR_PROJECT_ID
```

---

## Networking

### VPC and Subnets

The module requires an existing VPC and at least one subnet. For high availability across three zones (the minimum recommended), provision a regional subnet that spans your target region, or provision separate subnets per zone.

```bash
# Create a VPC
gcloud compute networks create nomad-vpc \
  --subnet-mode=custom \
  --project=YOUR_PROJECT_ID

# Create a regional subnet (spans all zones in the region automatically)
gcloud compute networks subnets create nomad-subnet \
  --network=nomad-vpc \
  --region=us-central1 \
  --range=10.10.0.0/24 \
  --project=YOUR_PROJECT_ID
```

Pass the names to the module:

```hcl
network    = "nomad-vpc"
subnetwork = "nomad-subnet"
region     = "us-central1"
```

> **Note:** The module deploys instances across exactly 3 availability zones within the region (`distribution_policy_zones`). Ensure the subnet's region contains at least 3 zones.

### Shared VPC (optional)

If your network lives in a separate host project (Shared VPC), set:

```hcl
network_project_id = "my-host-project-id"
network_region     = "us-central1"
```

### Firewall Rules

The module creates all required firewall rules automatically. The following rules are provisioned:

| Rule name | Direction | Protocol/Ports | Purpose |
|---|---|---|---|
| `{prefix}-nomad-firewall-iap-allow` | INGRESS | TCP/22 from `35.235.240.0/20` | IAP SSH tunnel (when `enable_iap = true`) |
| `{prefix}-nomad-firewall-allow-api` | INGRESS | TCP/4646 | Nomad API and UI access |
| `{prefix}-nomad-firewall-allow-rpc` | INGRESS | TCP/4647, TCP+UDP/4648 | Nomad RPC and Serf/gossip |
| `{prefix}-nomad-firewall-allow-outbound` | EGRESS | All | Instance outbound traffic |
| `{prefix}-health-check-fw` | INGRESS | TCP/4646 from GCP health check ranges | Load balancer health probes |

Restrict the API and RPC source ranges to your management CIDRs:

```hcl
cidr_ingress_api_allow = ["10.0.0.0/8"]
cidr_ingress_rpc_allow = ["10.0.0.0/8"]
```

> **Security note:** The defaults allow `0.0.0.0/0`. Always restrict these to your actual CIDR ranges before deploying to production.

---

## GCP Secret Manager Secrets

The module reads five secrets from GCP Secret Manager at instance boot time. Create each secret before deploying.

### 1 — Nomad Enterprise License

```bash
gcloud secrets create nomad-enterprise-license \
  --replication-policy=automatic \
  --project=YOUR_PROJECT_ID

echo -n "YOUR_NOMAD_LICENSE_STRING" | \
  gcloud secrets versions add nomad-enterprise-license \
  --data-file=- \
  --project=YOUR_PROJECT_ID
```

### 2 — Nomad Gossip Encryption Key

Generate a gossip key with the Nomad CLI:

```bash
nomad operator gossip keyring generate
# Outputs: <base64-encoded-32-byte-key>
```

Store it:

```bash
gcloud secrets create nomad-gossip-key \
  --replication-policy=automatic \
  --project=YOUR_PROJECT_ID

echo -n "YOUR_GOSSIP_KEY" | \
  gcloud secrets versions add nomad-gossip-key \
  --data-file=- \
  --project=YOUR_PROJECT_ID
```

### 3 — TLS Certificate (base64-encoded PEM)

The certificate, private key, and CA bundle must be stored as **base64-encoded** PEM strings. The boot script decodes them at runtime.

```bash
# Encode your PEM files
base64 -i cert.pem -o cert.pem.b64
base64 -i privkey.pem -o privkey.pem.b64
base64 -i ca.pem -o ca.pem.b64

# Store the certificate
gcloud secrets create nomad-tls-cert-base64 \
  --replication-policy=automatic \
  --project=YOUR_PROJECT_ID
gcloud secrets versions add nomad-tls-cert-base64 \
  --data-file=cert.pem.b64 \
  --project=YOUR_PROJECT_ID

# Store the private key
gcloud secrets create nomad-tls-privkey-base64 \
  --replication-policy=automatic \
  --project=YOUR_PROJECT_ID
gcloud secrets versions add nomad-tls-privkey-base64 \
  --data-file=privkey.pem.b64 \
  --project=YOUR_PROJECT_ID

# Store the CA bundle
gcloud secrets create nomad-tls-ca-cert-base64 \
  --replication-policy=automatic \
  --project=YOUR_PROJECT_ID
gcloud secrets versions add nomad-tls-ca-cert-base64 \
  --data-file=ca.pem.b64 \
  --project=YOUR_PROJECT_ID
```

See the [TLS Guide](./tls-guide.md) for instructions on generating Nomad-specific certificates.

### Secret variable mapping

| `terraform.tfvars` variable | Secret Manager secret name (example) |
|---|---|
| `nomad_license_sm_secret_name` | `nomad-enterprise-license` |
| `nomad_gossip_key_secret_name` | `nomad-gossip-key` |
| `nomad_tls_cert_sm_secret_name` | `nomad-tls-cert-base64` |
| `nomad_tls_privkey_sm_secret_name` | `nomad-tls-privkey-base64` |
| `nomad_tls_ca_bundle_sm_secret_name` | `nomad-tls-ca-cert-base64` |

---

## IAM Permissions

### Operator Permissions

The GCP identity running `terraform apply` (user or CI service account) needs the following project-level IAM roles:

| Role | Purpose |
|---|---|
| `roles/compute.admin` | Create and manage Compute Engine resources |
| `roles/iam.serviceAccountAdmin` | Create the Nomad service account |
| `roles/iam.serviceAccountUser` | Attach the service account to instance templates |
| `roles/dns.admin` | Create Cloud DNS records (if `create_cloud_dns_record = true`) |
| `roles/secretmanager.admin` | Create and manage secrets (pre-deployment only) |

Assign roles to your operator account:

```bash
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="user:you@example.com" \
  --role="roles/compute.admin"
```

### Nomad Instance Service Account

The module creates a dedicated service account (`{prefix}-service-account`) and grants it these roles automatically:

| Role | Purpose |
|---|---|
| `roles/compute.viewer` | Read GCE metadata for auto-join |
| `roles/secretmanager.secretAccessor` | Read secrets at boot time |
| `roles/cloudkms.cryptoKeyEncrypterDecrypter` | Encrypt/decrypt with Cloud KMS (if used) |

You can extend or override this list with the `google_service_account_iam_roles` variable.

---

## GCS Bucket for Snapshots (Optional)

To enable Nomad snapshot storage in GCS, create a bucket and provide its name:

```bash
gcloud storage buckets create gs://my-org-nomad-snapshots \
  --location=us-central1 \
  --uniform-bucket-level-access \
  --project=YOUR_PROJECT_ID
```

```hcl
nomad_snapshot_gcs_bucket_name = "my-org-nomad-snapshots"
```

The module grants `roles/storage.objectCreator` and `roles/storage.objectViewer` to the Nomad service account on this bucket.

---

## Cloud DNS Managed Zone (Optional)

To have the module create a DNS `A` record pointing `nomad_fqdn` at the load balancer IP:

```bash
gcloud dns managed-zones create nomad-zone \
  --dns-name="internal.example.com." \
  --description="Internal DNS for Nomad" \
  --visibility=private \
  --networks=nomad-vpc \
  --project=YOUR_PROJECT_ID
```

```hcl
create_cloud_dns_record  = true
cloud_dns_managed_zone   = "nomad-zone"
nomad_fqdn               = "nomad.internal.example.com"
```

---

## TLS Certificates

Nomad TLS certificates have requirements that standard Let's Encrypt certificates do not satisfy. See the [TLS Guide](./tls-guide.md) for full instructions on generating Nomad-specific certificates using `cfssl` or the Nomad CLI.

**Key requirements:**

- The server certificate SAN must include `server.<datacenter>.<region>.nomad` (e.g., `server.dc1.global.nomad`)
- The client certificate SAN must include `client.<datacenter>.<region>.nomad` (e.g., `client.dc1.global.nomad`)
- The CLI certificate SAN must include `cli.<region>.nomad` (e.g., `cli.global.nomad`)
- Private keys must **not** be password-protected
- Certificates must be stored as base64-encoded PEM in Secret Manager

---

## Pre-deployment Validation

Run these checks before `terraform apply`:

```bash
# Confirm APIs are enabled
gcloud services list --enabled --project=YOUR_PROJECT_ID \
  --filter="NAME:(compute OR secretmanager OR dns)"

# Confirm secrets exist
gcloud secrets list --project=YOUR_PROJECT_ID --filter="name~nomad"

# Confirm VPC and subnet exist
gcloud compute networks describe nomad-vpc --project=YOUR_PROJECT_ID
gcloud compute networks subnets describe nomad-subnet --region=us-central1 --project=YOUR_PROJECT_ID

# Validate Terraform configuration
terraform init
terraform validate
```
