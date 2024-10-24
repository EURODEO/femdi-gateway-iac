################################################################################
# Vault backup
################################################################################

# TODO consider using a service account for assuming AWS role

resource "kubernetes_cron_job_v1" "vault_backup" {
  metadata {
    name = "vault-backup"
    namespace = kubernetes_namespace.vault.metadata.0.name # Or use some other namespace or is new one better??
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
              name    = "hello"
              image   = "busybox"
              command = ["/bin/sh", "-c", "date; echo Hello from the Kubernetes cluster"]
            }
          }
        }
      }
    }
  }

}