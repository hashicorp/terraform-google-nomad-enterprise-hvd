# Upgrade Guide — Nomad Enterprise HVD on GCP

This guide covers upgrading the Nomad Enterprise version and the module configuration on GCP using a zero-downtime rolling replacement strategy.

---

## Upgrade Strategy Overview

The `terraform-google-nomad-enterprise-hvd` module uses a Regional Managed Instance Group (MIG) with an `OPPORTUNISTIC` update policy. Upgrades are performed by:

1. Updating the `nomad_version` variable (or other configuration)
2. Running `terraform apply` to update the instance template
3. Using the GCP MIG rolling replace action to cycle instances

The MIG is configured with `max_unavailable_fixed = 0` and `max_surge_fixed = 3` (one per zone), ensuring new instances are provisioned and healthy before old ones are removed.

> **Important:** Always upgrade Nomad server nodes before client nodes. Nomad supports clients running one major version behind servers.

---

## Step 1 — Review the Nomad Upgrade Notes

Before upgrading, read the [Nomad changelog](https://github.com/hashicorp/nomad/releases) and any upgrade notes for the target version. Pay particular attention to:

- Breaking changes in the configuration file format
- Deprecations that affect your `nomad_custom_data.sh.tpl` template
- Raft protocol version changes (rare, but require special handling)

---

## Step 2 — Take a Cluster Snapshot

Before any upgrade, save a Nomad snapshot from a server node as a recovery point:

```bash
# SSH to a server node
gcloud compute ssh INSTANCE_NAME \
  --tunnel-through-iap \
  --project=YOUR_PROJECT_ID \
  --zone=us-central1-a

# Save a snapshot
nomad operator snapshot save \
  -token "$NOMAD_TOKEN" \
  pre-upgrade-$(date +%Y%m%d).snap

# Copy snapshot off the instance
exit
gcloud compute scp INSTANCE_NAME:pre-upgrade-*.snap . \
  --tunnel-through-iap \
  --project=YOUR_PROJECT_ID \
  --zone=us-central1-a
```

Store the snapshot in GCS for durability:

```bash
gcloud storage cp pre-upgrade-*.snap gs://my-org-nomad-snapshots/ --project=YOUR_PROJECT_ID
```

---

## Step 3 — Update the Module Version

Update `nomad_version` in your `terraform.tfvars`:

```hcl
# Before
nomad_version = "1.9.5+ent"

# After
nomad_version = "1.10.0+ent"
```

Preview the changes:

```bash
terraform plan
```

The plan should show a change only to the `google_compute_instance_template` resource and a `replace` action on `google_compute_region_instance_group_manager` (due to `create_before_destroy`).

Apply the template change:

```bash
terraform apply
```

> `terraform apply` updates the instance template but does **not** replace running instances automatically with the `OPPORTUNISTIC` policy. The running instances continue to use the old template until replaced.

---

## Step 4 — Upgrade Server Nodes

Trigger a rolling replacement of server instances. Servers must be upgraded one at a time to maintain Raft quorum.

```bash
gcloud compute instance-groups managed rolling-action replace \
  nomad-nomad-ig-mgr \
  --region=us-central1 \
  --project=YOUR_PROJECT_ID \
  --max-unavailable=0 \
  --max-surge=1
```

Monitor the rollout:

```bash
gcloud compute instance-groups managed describe-instances \
  nomad-nomad-ig-mgr \
  --region=us-central1 \
  --project=YOUR_PROJECT_ID

# Watch the instance group operation
gcloud compute instance-groups managed wait-until \
  nomad-nomad-ig-mgr \
  --version-target-reached \
  --region=us-central1 \
  --project=YOUR_PROJECT_ID
```

After each new instance starts, verify it joined the cluster:

```bash
nomad server members
```

Wait for all servers to report `alive` and for Autopilot to report the cluster is healthy:

```bash
nomad operator autopilot get-config
nomad operator raft list-peers
```

---

## Step 5 — Verify Server Cluster Health

Before upgrading clients, confirm the server cluster is fully healthy:

```bash
# All servers alive
nomad server members

# Leader elected
nomad operator raft list-peers | grep leader

# No pending jobs or allocations blocked
nomad status
```

---

## Step 6 — Upgrade Client Nodes

If clients are managed in a separate Terraform workspace or module invocation, update `nomad_version` there and repeat steps 3–4 for the client MIG.

Clients can tolerate a more aggressive rollout since they do not participate in Raft:

```bash
gcloud compute instance-groups managed rolling-action replace \
  nomad-nomad-ig-mgr \
  --region=us-central1 \
  --project=YOUR_PROJECT_ID \
  --max-unavailable=1 \
  --max-surge=3
```

Monitor node registration:

```bash
nomad node status
```

---

## Step 7 — Verify Workloads

After all nodes are upgraded, confirm running allocations are healthy:

```bash
# List all jobs
nomad job status

# Check allocation health
nomad alloc status -short

# Check for any failed allocations
nomad alloc status -json | jq '[.[] | select(.ClientStatus == "failed")]'
```

---

## Rolling Back

If the upgrade causes issues, roll back by reverting `nomad_version` in `terraform.tfvars` and repeating the rolling replace procedure:

```bash
# In terraform.tfvars
nomad_version = "1.9.5+ent"

terraform apply

gcloud compute instance-groups managed rolling-action replace \
  nomad-nomad-ig-mgr \
  --region=us-central1 \
  --project=YOUR_PROJECT_ID \
  --max-unavailable=0 \
  --max-surge=1
```

> **Note:** Nomad does not support downgrading across major versions when Raft protocol upgrades have occurred. Always review upgrade notes before upgrading, and test in a non-production environment first.

---

## Upgrading the Terraform Module

To upgrade the module version itself (not the Nomad version), update the module `source` version pin in your `main.tf`:

```hcl
module "nomad" {
  # Before
  source  = "hashicorp/nomad-enterprise-hvd/google"
  version = "0.2.0"

  # After
  version = "0.3.0"
  ...
}
```

Review the module [CHANGELOG](https://github.com/hashicorp/terraform-google-nomad-enterprise-hvd/releases) for variable additions, removals, or changed defaults before applying.

```bash
terraform init -upgrade
terraform plan
terraform apply
```

---

## Upgrade Checklist

| Step | Command | Expected outcome |
|---|---|---|
| Take snapshot | `nomad operator snapshot save` | `.snap` file saved |
| Update version variable | Edit `terraform.tfvars` | `nomad_version` updated |
| Apply instance template | `terraform apply` | Only instance template changes |
| Roll servers | `gcloud compute instance-groups managed rolling-action replace` | Servers replaced one at a time |
| Verify server health | `nomad server members` | All servers `alive` |
| Roll clients | `gcloud compute instance-groups managed rolling-action replace` | Clients replaced |
| Verify client health | `nomad node status` | All clients `ready` |
| Verify workloads | `nomad alloc status -short` | No failed allocations |
