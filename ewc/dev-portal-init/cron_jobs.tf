################################################################################

# Keycloak backup
################################################################################
resource "kubernetes_secret" "keycloak_backup_cron_job_secrets" {
  metadata {
    name      = "keycloak-backup-cron-job"
    namespace = kubernetes_namespace.keycloak.metadata.0.name
  }

  data = {
    AWS_ACCESS_KEY_ID     = var.s3_bucket_access_key
    AWS_SECRET_ACCESS_KEY = var.s3_bucket_secret_key
  }

  type = "Opaque"

}

resource "kubernetes_cron_job_v1" "keycloak_backup" {
  metadata {
    name      = "keycloak-backup"
    namespace = kubernetes_namespace.keycloak.metadata.0.name
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
            restart_policy = "OnFailure"
            container {
              name              = "keycloak-backup"
              image             = "ghcr.io/eurodeo/femdi-gateway-iac/cron-jobs:latest"
              image_pull_policy = "Always" # TODO change to IfNotPresent once tested out to be working
              command           = ["/bin/sh", "-c", "/usr/local/bin/keycloak-snapshot.sh"]

              env {
                name  = "POSTGRES_HOST"
                value = local.postgres_host
              }

              env {
                name  = "POSTGRES_DB"
                value = local.postgres_db_name
              }

              env {
                name  = "POSTGRES_USER"
                value = local.postgres_db_user
              }

              # A bit magic here to get the password from Keycloak Helm chart generated secret
              # Reference dev-portal-init/main.tf resource "helm_release" "keycloak" for more info
              env {
                name = "POSTGRES_PASSWORD"
                value_from {
                  secret_key_ref {
                    name = "keycloak-postgresql"
                    key  = "password"
                  }
                }
              }

              env {
                name  = "S3_BUCKET_BASE_PATH"
                value = var.keycloak_backup_bucket_base_path
              }

              env {
                name = "AWS_ACCESS_KEY_ID"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret.keycloak_backup_cron_job_secrets.metadata.0.name
                    key  = "AWS_ACCESS_KEY_ID"
                  }
                }
              }

              env {
                name = "AWS_SECRET_ACCESS_KEY"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret.keycloak_backup_cron_job_secrets.metadata.0.name
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