# TLS Certificates Guide — Nomad Enterprise HVD on GCP

Nomad enforces strict TLS certificate requirements that standard CA-issued and Let's Encrypt certificates do not satisfy. This guide covers generating, storing, and rotating Nomad-specific TLS certificates for use with the `terraform-google-nomad-enterprise-hvd` module using the built-in `nomad tls` CLI commands.

---

## Why Nomad Requires Custom Certificates

Nomad verifies peer identity using the TLS Subject Alternative Name (SAN) field. The SAN must contain a Nomad-specific hostname of the form:

```
<role>.<datacenter>.<region>.nomad
```

For example, in datacenter `dc1` and region `global`:

| Node role | Required SAN |
|---|---|
| Server | `server.dc1.global.nomad` |
| Client | `client.dc1.global.nomad` |
| CLI | `cli.global.nomad` |

Standard public CAs do not issue certificates with `.nomad` SANs. Use the `nomad tls` commands to operate your own CA — no third-party tools required.

---

## Prerequisites

- Nomad Enterprise binary installed locally (`>= 1.9`): `nomad version`
- A working directory to hold the generated certificate files

---

## Step 1 — Create the Certificate Authority

Run `nomad tls ca create` once per cluster. This generates a self-signed CA used to sign all node certificates.

```bash
nomad tls ca create
```

This produces two files:

```
nomad-agent-ca.pem      # CA certificate — distribute to all nodes
nomad-agent-ca-key.pem  # CA private key — keep secret, used only for signing
```

### CA create options

| Flag | Default | Description |
|---|---|---|
| `-common-name` | `"Nomad Agent CA"` | Common Name field of the CA certificate |
| `-days` | `1825` (5 years) | Validity period in days |
| `-domain` | `"nomad"` | Domain for the cluster. Only used with `-name-constraint` |
| `-name-constraint` | `false` | Restrict the CA to only sign certificates for the specified domain. Recommended for production |
| `-additional-domain` | | Additional DNS zones to allow when `-name-constraint` is enabled. Can be specified multiple times |
| `-country` | `"US"` | Certificate country field |
| `-province` | `"CA"` | Certificate province field |
| `-locality` | `"San Francisco"` | Certificate locality field |
| `-organization` | `"HashiCorp Inc."` | Certificate organization field |
| `-organizational-unit` | `"Nomad"` | Certificate organizational unit field |

**Example: production CA with name constraints**

```bash
nomad tls ca create \
  -common-name "My Org Nomad CA" \
  -name-constraint \
  -domain nomad \
  -days 1825
```

> **Security note:** Store `nomad-agent-ca-key.pem` securely. It is only needed to sign new certificates. Never deploy it to cluster nodes.

---

## Step 2 — Create the Server Certificate

Run `nomad tls cert create -server` to generate a certificate for Nomad server nodes. The certificate SAN is automatically set to `server.<datacenter>.<region>.nomad`.

```bash
nomad tls cert create -server -dc dc1 -region global
```

Replace `dc1` with your `nomad_datacenter` value and `global` with your `nomad_region` value.

This produces:

```
global-server-nomad.pem      # Server TLS certificate
global-server-nomad-key.pem  # Server TLS private key
```

### Cert create options

| Flag | Default | Description |
|---|---|---|
| `-server` | | Generate a server certificate |
| `-client` | | Generate a client certificate |
| `-cli` | | Generate a CLI certificate |
| `-dc` | | Datacenter name. Sets the datacenter component of the SAN (`server.<dc>.<region>.nomad`). Required |
| `-region` | `"global"` | Region name. Sets the region component of the SAN |
| `-domain` | `"nomad"` | Cluster domain. Must match the `-domain` used when creating the CA |
| `-days` | `365` (1 year) | Validity period in days |
| `-ca` | `nomad-agent-ca.pem` | Path to the CA certificate |
| `-key` | `nomad-agent-ca-key.pem` | Path to the CA private key |
| `-additional-dnsname` | | Extra SAN DNS names (e.g. a load balancer hostname). Can be specified multiple times. `localhost` is always included |
| `-additional-ipaddress` | | Extra SAN IP addresses. Can be specified multiple times. `127.0.0.1` is always included |

**Example: server certificate with load balancer DNS name**

```bash
nomad tls cert create -server \
  -dc dc1 \
  -region global \
  -additional-dnsname "nomad.internal.example.com" \
  -days 365
```

---

## Step 3 — Create the Client Certificate

```bash
nomad tls cert create -client -dc dc1 -region global
```

This produces:

```
global-client-nomad.pem      # Client TLS certificate
global-client-nomad-key.pem  # Client TLS private key
```

The SAN is automatically set to `client.dc1.global.nomad`.

---

## Step 4 — Create the CLI Certificate

Used for authenticating the local `nomad` CLI against a TLS-enabled cluster.

```bash
nomad tls cert create -cli -region global
```

This produces:

```
global-cli-nomad.pem      # CLI TLS certificate
global-cli-nomad-key.pem  # CLI TLS private key
```

---

## Step 5 — Verify the Generated Files

Confirm the SANs on the server certificate:

```bash
openssl x509 -in global-server-nomad.pem -noout -text | grep -A1 "Subject Alternative"
```

Expected output:

```
X509v3 Subject Alternative Names:
    DNS:server.dc1.global.nomad, DNS:localhost, IP Address:127.0.0.1
```

---

## Step 6 — Store Certificates in GCP Secret Manager

The module fetches certificates from GCP Secret Manager at boot time. Certificates must be stored as **base64-encoded PEM** — the boot script decodes them at runtime.

```bash
# Encode the files
base64 -i global-server-nomad.pem     > server.pem.b64
base64 -i global-server-nomad-key.pem > server-key.pem.b64
base64 -i nomad-agent-ca.pem          > ca.pem.b64

# Store in Secret Manager
gcloud secrets create nomad-tls-cert-base64 \
  --replication-policy=automatic --project=PROJECT_ID
gcloud secrets versions add nomad-tls-cert-base64 \
  --data-file=server.pem.b64 --project=PROJECT_ID

gcloud secrets create nomad-tls-privkey-base64 \
  --replication-policy=automatic --project=PROJECT_ID
gcloud secrets versions add nomad-tls-privkey-base64 \
  --data-file=server-key.pem.b64 --project=PROJECT_ID

gcloud secrets create nomad-tls-ca-cert-base64 \
  --replication-policy=automatic --project=PROJECT_ID
gcloud secrets versions add nomad-tls-ca-cert-base64 \
  --data-file=ca.pem.b64 --project=PROJECT_ID
```

For **client** deployments, repeat using `global-client-nomad.pem` and `global-client-nomad-key.pem`. Servers and clients share the same CA secret.

### Secret variable mapping

| `terraform.tfvars` variable | Secret Manager secret | Content |
|---|---|---|
| `nomad_tls_cert_sm_secret_name` | `nomad-tls-cert-base64` | Base64-encoded TLS certificate PEM |
| `nomad_tls_privkey_sm_secret_name` | `nomad-tls-privkey-base64` | Base64-encoded TLS private key PEM |
| `nomad_tls_ca_bundle_sm_secret_name` | `nomad-tls-ca-cert-base64` | Base64-encoded CA certificate PEM |

---

## TLS Variable Reference

| Variable | Description | Default |
|---|---|---|
| `nomad_tls_enabled` | Enable TLS on the Nomad listener | `true` |
| `nomad_tls_cert_sm_secret_name` | Secret Manager secret for the TLS certificate (base64 PEM) | required |
| `nomad_tls_privkey_sm_secret_name` | Secret Manager secret for the TLS private key (base64 PEM) | required |
| `nomad_tls_ca_bundle_sm_secret_name` | Secret Manager secret for the CA bundle (base64 PEM) | required |
| `nomad_tls_disable_client_certs` | Disable mutual TLS client certificate verification | `true` |
| `nomad_tls_require_and_verify_client_cert` | Require and verify client certificate against system CAs | `false` |

> **Warning:** `nomad_tls_enabled = false` disables all TLS. Never use this in production.

---

## Configuring the Local Nomad CLI for TLS

Export these environment variables to use the Nomad CLI against the cluster:

```bash
export NOMAD_ADDR="https://nomad.internal.example.com:4646"
export NOMAD_CACERT="/path/to/nomad-agent-ca.pem"
export NOMAD_CLIENT_CERT="/path/to/global-cli-nomad.pem"
export NOMAD_CLIENT_KEY="/path/to/global-cli-nomad-key.pem"
export NOMAD_TOKEN="<your-acl-token>"
```

Verify connectivity:

```bash
nomad server members
```

---

## Certificate Rotation

Rotating certificates on a live cluster uses a rolling MIG replacement. The module always fetches the **`latest`** secret version at boot time.

### 1 — Generate new certificates

```bash
nomad tls cert create -server -dc dc1 -region global -days 365

base64 -i global-server-nomad.pem     > server-new.pem.b64
base64 -i global-server-nomad-key.pem > server-key-new.pem.b64
```

### 2 — Add new versions to Secret Manager

```bash
gcloud secrets versions add nomad-tls-cert-base64 \
  --data-file=server-new.pem.b64 --project=PROJECT_ID

gcloud secrets versions add nomad-tls-privkey-base64 \
  --data-file=server-key-new.pem.b64 --project=PROJECT_ID
```

### 3 — Trigger a rolling instance replacement

```bash
gcloud compute instance-groups managed rolling-action replace \
  nomad-nomad-ig-mgr \
  --region=us-central1 \
  --project=PROJECT_ID \
  --max-unavailable=0 \
  --max-surge=3
```

New instances start with the new certificates. Old instances are terminated only after new ones pass health checks.

### 4 — Verify and clean up

```bash
# Confirm cluster is healthy
nomad server members
nomad operator autopilot get-config

# Disable the old secret version (optional)
gcloud secrets versions disable OLD_VERSION_NUMBER \
  --secret=nomad-tls-cert-base64 --project=PROJECT_ID
```

---

## CA Rotation

Rotating the CA is a two-phase process to avoid any node rejecting peers during the transition.

### Phase 1 — Add the new CA alongside the old one

```bash
# Generate new CA
nomad tls ca create -common-name "My Org Nomad CA v2"
# Produces: nomad-agent-ca.pem (new), nomad-agent-ca-key.pem (new)

# Concatenate old and new CAs into a bundle
cat old-nomad-agent-ca.pem nomad-agent-ca.pem > ca-bundle.pem
base64 -i ca-bundle.pem > ca-bundle.b64

# Update the CA secret with the bundle
gcloud secrets versions add nomad-tls-ca-cert-base64 \
  --data-file=ca-bundle.b64 --project=PROJECT_ID
```

Generate new node certificates signed by the new CA:

```bash
nomad tls cert create -server -dc dc1 -region global \
  -ca nomad-agent-ca.pem \
  -key nomad-agent-ca-key.pem
```

Update the cert and key secrets, then perform a rolling replacement (see [Certificate Rotation](#certificate-rotation) above). After the rollout, all nodes trust both CAs and use the new leaf certificates.

### Phase 2 — Remove the old CA

Once all nodes are running with the new certificates, update the CA bundle secret to contain only the new CA:

```bash
base64 -i nomad-agent-ca.pem > ca-new-only.b64

gcloud secrets versions add nomad-tls-ca-cert-base64 \
  --data-file=ca-new-only.b64 --project=PROJECT_ID
```

Perform a second rolling replacement to remove the old CA from all running nodes.
