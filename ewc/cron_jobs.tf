################################################################################
# Vault backup
################################################################################

# TODO consider using a service account for assuming AWS role - no need to use access key and secret key
# Using service account with self-hosted k8s cluster requires own OIDC provider, keycloak, s3, dex etc.

# TODO which namespace should these be in - vault namespace or a new one or some other already exisitng?
# for now go with vault namespace

resource "kubernetes_secret" "vault_backup_cron_job_secrets" {
  metadata {
    name      = "vault-backup-cron-job"
    namespace = module.ewc-vault-init.vault_namespace_name
  }

  data = {
    AWS_ACCESS_KEY_ID     = var.s3_bucket_access_key
    AWS_SECRET_ACCESS_KEY = var.s3_bucket_secret_key
  }

  type = "Opaque"
}

resource "kubernetes_service_account" "backup_cron_job_service_account" {
  metadata {
    name      = "backup-cron-job-sa"
    namespace = module.ewc-vault-init.vault_namespace_name
  }

}

resource "kubernetes_cron_job_v1" "vault_backup" {
  metadata {
    name      = "vault-backup"
    namespace = module.ewc-vault-init.vault_namespace_name
  }

  spec {
    concurrency_policy            = "Replace"
    failed_jobs_history_limit     = 3 # Keep the latest 3 failed jobs
    schedule                      = "1 0 * * *"
    timezone                      = "Etc/UTC"
    starting_deadline_seconds     = 43200 # 12 hours
    successful_jobs_history_limit = 1     # Keep the latest

    job_template {
      metadata {}
      spec {
        backoff_limit = 6 # This the default value
        template {
          metadata {}
          spec {
            service_account_name = kubernetes_service_account.backup_cron_job_service_account.metadata.0.name
            restart_policy       = "OnFailure"
            container {
              name              = "vault-backup"
              image             = "ghcr.io/eurodeo/femdi-gateway-iac/vault-snapshot:latest"
              image_pull_policy = "Always" # TODO change to IfNotPresent once tested out to be working
              command           = ["/bin/sh", "-c", "/usr/local/bin/vault-snapshot.sh"]

              env {
                name  = "VAULT_ADDR"
                value = local.vault_host
              }

              env {
                name  = "S3_BUCKET_BASE_PATH"
                value = var.vault_backup_bucket_base_path
              }

              env {
                name = "AWS_ACCESS_KEY_ID"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret.vault_backup_cron_job_secrets.metadata.0.name
                    key  = "AWS_ACCESS_KEY_ID"
                  }
                }
              }

              env {
                name = "AWS_SECRET_ACCESS_KEY"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret.vault_backup_cron_job_secrets.metadata.0.name
                    key  = "AWS_SECRET_ACCESS_KEY"
                  }
                }
              }
            }
          }
        }
      }
    }
  }

}