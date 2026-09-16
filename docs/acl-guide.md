# ACL Guide — Nomad Enterprise HVD on GCP

This guide covers bootstrapping and managing the Nomad Access Control List (ACL) system deployed by the `terraform-google-nomad-enterprise-hvd` module. ACLs are enabled by default (`nomad_acl_enabled = true`).

---

## Overview

Nomad ACLs enforce authorization on all API operations. Without a valid token, anonymous requests are restricted to read-only access (or blocked entirely depending on the anonymous policy). ACLs must be bootstrapped **once** after the initial cluster deployment.

---

## Step 1 — Bootstrap ACLs

ACL bootstrapping generates the initial management token. This must be done **once** on any single server node immediately after cluster formation.

### Connect to a server node

```bash
# List running server instances
gcloud compute instances list \
  --filter="tags.items=nomad-backend AND status=RUNNING" \
  --project=YOUR_PROJECT_ID \
  --format="table(name,zone,networkInterfaces[0].networkIP)"

# SSH via IAP
gcloud compute ssh INSTANCE_NAME \
  --tunnel-through-iap \
  --project=YOUR_PROJECT_ID \
  --zone=us-central1-a
```

### Set the Nomad address

```bash
export NOMAD_ADDR="https://127.0.0.1:4646"
export NOMAD_CACERT="/etc/nomad.d/tls/ca.pem"
```

### Bootstrap the ACL system

```bash
nomad acl bootstrap
```

Example output:

```
Accessor ID  = 3b4f1b24-8c51-fef9-02b9-55a97d6ee7d1
Secret ID    = a8b87fd7-2a87-de52-bd0a-5bbcb553e64a
Name         = Bootstrap Token
Type         = management
Global       = true
Create Time  = 2024-12-01 10:00:00 +0000 UTC
Policies     = []
Roles        = []
```

> **Important:** The `Secret ID` is the bootstrap token. Store it immediately in a secrets manager (e.g., GCP Secret Manager or HashiCorp Vault). It cannot be retrieved again.

```bash
# Store the bootstrap token securely
echo -n "a8b87fd7-2a87-de52-bd0a-5bbcb553e64a" | \
  gcloud secrets versions add nomad-bootstrap-token \
  --data-file=- \
  --project=YOUR_PROJECT_ID
```

---

## Step 2 — Set the Management Token

Export the bootstrap token for subsequent ACL operations:

```bash
export NOMAD_TOKEN="a8b87fd7-2a87-de52-bd0a-5bbcb553e64a"
```

Verify it works:

```bash
nomad acl token self
```

---

## Step 3 — Create Policies

Nomad ACL policies define the permissions granted to tokens. Policies are written in HCL.

### Example: read-only policy

```hcl
# readonly.hcl
namespace "default" {
  policy = "read"
}
node {
  policy = "read"
}
agent {
  policy = "read"
}
```

```bash
nomad acl policy apply -description "Read-only access" readonly ./readonly.hcl
```

### Example: operator policy (deploy jobs)

```hcl
# operator.hcl
namespace "default" {
  policy = "write"
  capabilities = ["submit-job", "dispatch-job", "read-logs", "read-fs", "alloc-exec"]
}
node {
  policy = "read"
}
agent {
  policy = "read"
}
```

```bash
nomad acl policy apply -description "Operator: deploy and manage jobs" operator ./operator.hcl
```

### Example: admin policy

```hcl
# admin.hcl
namespace "*" {
  policy = "write"
}
node {
  policy = "write"
}
agent {
  policy = "write"
}
operator {
  policy = "write"
}
quota {
  policy = "write"
}
```

```bash
nomad acl policy apply -description "Full admin access" admin ./admin.hcl
```

---

## Step 4 — Create Tokens

Create tokens and attach them to policies:

```bash
# Create a read-only token
nomad acl token create \
  -name="ci-readonly" \
  -policy=readonly \
  -type=client

# Create an operator token with TTL
nomad acl token create \
  -name="deploy-pipeline" \
  -policy=operator \
  -type=client \
  -ttl=24h

# Create a token attached to multiple policies
nomad acl token create \
  -name="platform-team" \
  -policy=operator \
  -policy=readonly \
  -type=client
```

Each command outputs a `Secret ID` that is the bearer token for that identity.

---

## Managing Tokens

### List tokens

```bash
nomad acl token list
```

### View a token

```bash
nomad acl token info ACCESSOR_ID
```

### Revoke a token

```bash
nomad acl token delete ACCESSOR_ID
```

### Rotate the bootstrap token

The bootstrap token should be rotated after initial setup. Create a new management token and revoke the bootstrap token:

```bash
# Create a new management token
nomad acl token create -name="admin-replacement" -type=management

# Revoke the bootstrap token using its accessor ID
nomad acl token delete BOOTSTRAP_ACCESSOR_ID
```

Update the stored token in Secret Manager:

```bash
echo -n "NEW_SECRET_ID" | \
  gcloud secrets versions add nomad-bootstrap-token \
  --data-file=- \
  --project=YOUR_PROJECT_ID
```

---

## ACL Replication

In multi-region deployments, ACLs defined in the authoritative region replicate to secondary regions. Enable replication in secondary region server configurations:

```hcl
acl {
  enabled            = true
  token_ttl          = "30s"
  policy_ttl         = "60s"
  replication_token  = "<replication-token-secret-id>"
}
```

The replication token must be a management-type token from the authoritative region.

---

## Using the Nomad UI with ACLs

When ACLs are enabled, the Nomad UI prompts for a token on first visit:

1. Navigate to `https://<nomad_fqdn>:4646/ui`
2. Click **"Log in with token"**
3. Enter a valid `Secret ID`

Anonymous access (without a token) provides read-only access to the default namespace if the anonymous policy permits it.

---

## Variable Reference

| Variable | Description | Default |
|---|---|---|
| `nomad_acl_enabled` | Enable ACL system | `true` |

---

## Troubleshooting

### `Permission denied` errors

Verify your token has the required policy:

```bash
nomad acl token self
nomad acl policy info POLICY_NAME
```

### ACL not bootstrapped yet

If `nomad acl bootstrap` returns `Error bootstrapping: Unexpected response code: 500`, the cluster may not have reached quorum yet. Wait for all server nodes to join and retry.

### ACL state lost after redeployment

ACL state is stored in Nomad's Raft data directory (`/opt/nomad/data`). If all server instances are replaced simultaneously, ACL state may be lost. To avoid this:

- Use the [Upgrade Guide](./upgrade-guide.md) rolling replacement procedure
- Take a Nomad snapshot before destructive operations: `nomad operator snapshot save backup.snap`
