# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# Service account
#------------------------------------------------------------------------------
resource "google_service_account" "nomad_sa" {
  account_id   = format("%s-service-account", var.application_prefix)
  display_name = "HashiCorp Nomad service account"
  project      = var.project_id
}

resource "google_project_iam_member" "nomad_iam" {
  for_each = toset(var.google_service_account_iam_roles)

  project = var.project_id
  role    = each.value
  member  = format("serviceAccount:%s", google_service_account.nomad_sa.email)
}

resource "google_storage_bucket_iam_binding" "snapshots_creator" {
  count = var.nomad_snapshot_gcs_bucket_name == null ? 0 : 1

  bucket = var.nomad_snapshot_gcs_bucket_name
  role   = "roles/storage.objectCreator"

  members = [
    format("serviceAccount:%s", google_service_account.nomad_sa.email)
  ]
}

resource "google_storage_bucket_iam_binding" "snapshots_viewer" {
  count = var.nomad_snapshot_gcs_bucket_name == null ? 0 : 1

  bucket = var.nomad_snapshot_gcs_bucket_name
  role   = "roles/storage.objectViewer"

  members = [
    format("serviceAccount:%s", google_service_account.nomad_sa.email)
  ]
}
