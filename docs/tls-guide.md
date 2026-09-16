# TLS Certificates Guide — Nomad Enterprise HVD on GCP

Nomad enforces strict TLS certificate requirements that standard CA-issued and Let's Encrypt certificates do not satisfy. This guide covers generating, storing, and rotating Nomad-specific TLS certificates for use with the `terraform-google-nomad-enterprise-hvd` module.

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

Standard public CAs do not issue certificates with `.nomad` SANs. You must operate your own CA.

---

## Option A — Generate Certificates with `cfssl` (Recommended)

`cfssl` is HashiCorp's recommended tool for generating Nomad PKI certificates.

### 1 — Install `cfssl`

```bash
# macOS
brew install cfssl

# Linux (binary)
curl -Lo /usr/local/bin/cfssl https://github.com/cloudflare/cfssl/releases/latest/download/cfssl_linux-amd64
curl -Lo /usr/local/bin/cfssljson https://github.com/cloudflare/cfssl/releases/latest/download/cfssljson_linux-amd64
chmod +x /usr/local/bin/cfssl /usr/local/bin/cfssljson
```

### 2 — Create the CA Configuration

```bash
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "nomad": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF
```

### 3 — Generate the CA Certificate

```bash
cat > ca-csr.json <<EOF
{
  "CN": "Nomad CA",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "ST": "California",
      "L": "San Francisco",
      "O": "HashiCorp",
      "OU": "Nomad"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare nomad-ca
# Produces: nomad-ca.pem (CA cert) and nomad-ca-key.pem (CA private key)
```

### 4 — Generate the Server Certificate

Replace `dc1` and `global` with your `nomad_datacenter` and `nomad_region` values:

```bash
cat > server-csr.json <<EOF
{
  "CN": "server.dc1.global.nomad",
  "hosts": [
    "server.dc1.global.nomad",
    "localhost",
    "127.0.0.1"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "ST": "California",
      "L": "San Francisco",
      "O": "HashiCorp",
      "OU": "Nomad"
    }
  ]
}
EOF

cfssl gencert \
  -ca=nomad-ca.pem \
  -ca-key=nomad-ca-key.pem \
  -config=ca-config.json \
  -profile=nomad \
  server-csr.json | cfssljson -bare server
# Produces: server.pem and server-key.pem
```

### 5 — Generate the Client Certificate

```bash
cat > client-csr.json <<EOF
{
  "CN": "client.dc1.global.nomad",
  "hosts": [
    "client.dc1.global.nomad",
    "localhost",
    "127.0.0.1"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "ST": "California",
      "L": "San Francisco",
      "O": "HashiCorp",
      "OU": "Nomad"
    }
  ]
}
EOF

cfssl gencert \
  -ca=nomad-ca.pem \
  -ca-key=nomad-ca-key.pem \
  -config=ca-config.json \
  -profile=nomad \
  client-csr.json | cfssljson -bare client
# Produces: client.pem and client-key.pem
```

### 6 — Generate the CLI Certificate

```bash
cat > cli-csr.json <<EOF
{
  "CN": "cli.global.nomad",
  "hosts": [
    "cli.global.nomad",
    "localhost",
    "127.0.0.1"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF

cfssl gencert \
  -ca=nomad-ca.pem \
  -ca-key=nomad-ca-key.pem \
  -config=ca-config.json \
  -profile=nomad \
  cli-csr.json | cfssljson -bare cli
```

---

## Option B — Generate Certificates with the Nomad CLI

The Nomad CLI provides a simplified certificate generation workflow:

```bash
# Generate CA
nomad tls ca create

# Generate server certificate
nomad tls cert create -server -dc dc1 -region global

# Generate client certificate
nomad tls cert create -client -dc dc1 -region global

# Generate CLI certificate
nomad tls cert create -cli -region global
```

This produces files named `nomad-agent-ca.pem`, `global-server-nomad.pem`, etc.

---

## Storing Certificates in GCP Secret Manager

The module expects TLS certificates to be stored as **base64-encoded PEM** in Secret Manager. The boot script decodes them at runtime.

```bash
# --- Server deployment ---
# Encode the server certificate and key
base64 -i server.pem > server.pem.b64
base64 -i server-key.pem > server-key.pem.b64
base64 -i nomad-ca.pem > ca.pem.b64

# Store in Secret Manager
gcloud secrets create nomad-tls-cert-base64 --replication-policy=automatic --project=PROJECT_ID
gcloud secrets versions add nomad-tls-cert-base64 --data-file=server.pem.b64 --project=PROJECT_ID

gcloud secrets create nomad-tls-privkey-base64 --replication-policy=automatic --project=PROJECT_ID
gcloud secrets versions add nomad-tls-privkey-base64 --data-file=server-key.pem.b64 --project=PROJECT_ID

gcloud secrets create nomad-tls-ca-cert-base64 --replication-policy=automatic --project=PROJECT_ID
gcloud secrets versions add nomad-tls-ca-cert-base64 --data-file=ca.pem.b64 --project=PROJECT_ID
```

> **Note:** For client deployments, repeat the above using `client.pem` and `client-key.pem`. Servers and clients can share the same CA bundle secret.

---

## TLS Variable Reference

| Variable | Description | Default |
|---|---|---|
| `nomad_tls_enabled` | Enable TLS on the Nomad listener | `true` |
| `nomad_tls_cert_sm_secret_name` | Secret Manager secret name for the TLS certificate (base64 PEM) | required |
| `nomad_tls_privkey_sm_secret_name` | Secret Manager secret name for the TLS private key (base64 PEM) | required |
| `nomad_tls_ca_bundle_sm_secret_name` | Secret Manager secret name for the CA bundle (base64 PEM) | required |
| `nomad_tls_disable_client_certs` | Disable mutual TLS client certificate verification | `true` |
| `nomad_tls_require_and_verify_client_cert` | Require and verify client certificate against system CAs | `false` |

> **Warning:** `nomad_tls_enabled = false` disables all TLS. Never use this in production. It exists only for lab or development environments.

---

## Configuring the Local Nomad CLI for TLS

Export these environment variables to use the Nomad CLI against a TLS-enabled cluster:

```bash
export NOMAD_ADDR="https://nomad.internal.example.com:4646"
export NOMAD_CACERT="/path/to/nomad-ca.pem"
export NOMAD_CLIENT_CERT="/path/to/cli.pem"
export NOMAD_CLIENT_KEY="/path/to/cli-key.pem"
```

Verify connectivity:

```bash
nomad server members
```

---

## Certificate Rotation

Rotating TLS certificates on a live cluster requires a rolling replacement of all instances:

### 1 — Add the new certificate version to Secret Manager

```bash
# Create a new version; keep the old one active until rotation completes
gcloud secrets versions add nomad-tls-cert-base64 \
  --data-file=new-server.pem.b64 \
  --project=PROJECT_ID

gcloud secrets versions add nomad-tls-privkey-base64 \
  --data-file=new-server-key.pem.b64 \
  --project=PROJECT_ID
```

> The module always fetches the **`latest`** version of each secret at boot time.

### 2 — Trigger a rolling instance replacement

Force the MIG to replace all instances using the latest secret version:

```bash
gcloud compute instance-groups managed rolling-action replace \
  nomad-nomad-ig-mgr \
  --region=us-central1 \
  --project=PROJECT_ID \
  --max-unavailable=0 \
  --max-surge=3
```

The MIG creates new instances before terminating old ones (`max-unavailable=0`), keeping the cluster operational throughout rotation.

### 3 — Verify the cluster is healthy post-rotation

```bash
nomad server members
nomad operator autopilot get-config
```

### 4 — Disable the old secret version (optional)

```bash
gcloud secrets versions disable OLD_VERSION_NUMBER \
  --secret=nomad-tls-cert-base64 \
  --project=PROJECT_ID
```

---

## CA Rotation

Rotating the CA is a more involved process. The general approach is:

1. Generate a new CA and issue new certificates signed by the new CA
2. Add both the old and new CA certificates to the CA bundle secret (concatenated PEM)
3. Add new certificate and key versions to their respective secrets
4. Perform a rolling instance replacement (step 2 above)
5. Once all instances are running with the new certificates, remove the old CA from the bundle
6. Perform a second rolling replacement to remove the old CA from all instances

This two-phase rotation ensures no instance rejects peers during the transition.
