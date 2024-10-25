################################################################################
# Vault backup
################################################################################

# TODO consider using a service account for assuming AWS role - no need to use access key and secret key

# TODO which namespace should these be in - vault namespace or a new one or some other already exisitng?
# for now go with vault namespace

resource "kubernetes_secret" "vault_backup_cron_job_secrets" {
  metadata {
    name      = "vault-backup-cron-job"
    namespace = kubernetes_namespace.vault.metadata.0.name
  }

  data = {
    VAULT_TOKEN           = "TODO" # follow the same way as did for apisix and dev portal tokens
    AWS_ACCESS_KEY_ID     = var.s3_bucket_access_key
    AWS_SECRET_ACCESS_KEY = var.s3_bucket_secret_key
  }
}

resource "kubernetes_cron_job_v1" "vault_backup" {
  metadata {
    name      = "vault-backup"
    namespace = kubernetes_namespace.vault.metadata.0.name
  }

  spec {
    concurrency_policy            = "Replace"
    failed_jobs_history_limit     = 3
    schedule                      = "1 0 * * *"
    timezone                      = "Etc/UTC"
    starting_deadline_seconds     = 10
    successful_jobs_history_limit = 3

    job_template {
      metadata {}
      spec {
        backoff_limit              = 3
        ttl_seconds_after_finished = 10
        template {
          metadata {}
          spec {
            container {
              name    = "vault-backup"
              image   = "ghcr.io/EURODEO/femdi-gateway-iac/vault-snapshot:latest"
              command = ["/bin/sh", "-c", "/usr/local/bin/vault-snapshot.sh"]

              env {
                name  = "VAULT_ADDR"
                value = "http://vault-active.vault.svc.cluster.local:8200"
              }

              env {
                name = "VAULT_TOKEN"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret.vault_backup_cron_job_secrets.metadata.0.name
                    key  = "VAULT_TOKEN"
                  }
                }
              }

              env {
                name  = "S3_BUCKET"
                value = var.vault_backup_bucket_base_uri
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