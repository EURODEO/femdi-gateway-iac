provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }

}

provider "kubernetes" {
  config_path = var.kubeconfig_path

}

#Workaround for https://github.com/hashicorp/terraform-provider-kubernetes/issues/1367
provider "kubectl" {
  config_path = var.kubeconfig_path
}

provider "rancher2" {
  api_url   = var.rancher_api_url
  token_key = var.rancher_token
  insecure  = var.rancher_insecure
}


provider "vault" {
  address = "https://${var.vault_subdomain}.${var.dns_zone}"
  token   = var.vault_token
}

provider "random" {
}

locals {
  vault_host = "http://vault-active.vault.svc.cluster.local:8200"
  etcd_host  = "http://apisix-etcd.apisix.svc.cluster.local:2379"
}


################################################################################
# Install Vault and it's policies and tokens
################################################################################

module "ewc-vault-init" {
  source = "./ewc-vault-init/"

  rancher_api_url    = var.rancher_api_url
  rancher_token      = var.rancher_token
  rancher_cluster_id = var.rancher_cluster_id
  kubeconfig_path    = var.kubeconfig_path

  route53_access_key     = var.route53_access_key
  route53_secret_key     = var.route53_secret_key
  route53_zone_id_filter = var.route53_zone_id_filter
  dns_zone               = var.dns_zone

  email_cert_manager = var.email_cert_manager

  vault_project_id    = rancher2_project.gateway.id
  vault_subdomain     = var.vault_subdomain
  vault_replicas      = var.vault_replicas
  vault_anti-affinity = var.vault_anti-affinity
  vault_key_treshold  = var.vault_key_treshold


}

# Vault configurations after initialization and bootsrap
resource "vault_mount" "apisix" {
  path        = "apisix"
  type        = "kv"
  options     = { version = "1" }
  description = "Apisix secrets"

  depends_on = [module.ewc-vault-init]
}

resource "vault_jwt_auth_backend" "github" {
  description        = "JWT for github actions"
  path               = "github"
  oidc_discovery_url = "https://token.actions.githubusercontent.com"
  bound_issuer       = "https://token.actions.githubusercontent.com"

  depends_on = [module.ewc-vault-init]
}

resource "vault_auth_backend" "kubernetes" {
  type        = "kubernetes"
  description = "Kubernetes auth backend"

  depends_on = [module.ewc-vault-init]
}

resource "vault_kubernetes_auth_backend_config" "k8s_auth_config" {
  backend = vault_auth_backend.kubernetes.path

  # Use the internal Kubernetes API server URL for communication within the cluster.
  # This URL is automatically resolved by the Kubernetes DNS service to the internal IP address of the Kubernetes API server.
  # If the provided host doesn't work (403 response) in future you can check correct DNS search paths using:
  # kubectl run -it --rm --restart=Never busybox --image=busybox -- sh
  # cat /etc/resolv.conf

  kubernetes_host = "https://kubernetes.default.svc.kubernetes.local"

  # We can omit rest of params, e.g. CA certificate and token reviewer JWT as long as 
  # Vault and calling service are run in same k8s cluster
  # https://developer.hashicorp.com/vault/docs/auth/kubernetes#use-local-service-account-token-as-the-reviewer-jwt
}

resource "vault_policy" "apisix-global" {
  name = "apisix-global"

  policy = <<EOT
path "apisix/consumers/*" {
  capabilities = ["read"]
}

EOT

  depends_on = [module.ewc-vault-init]
}

resource "vault_policy" "dev-portal-global" {
  name = "dev-portal-global"

  policy = <<EOT
path "apisix/consumers/*" {
	capabilities = ["create", "read", "update", "patch", "delete", "list"]
}
EOT

  depends_on = [module.ewc-vault-init]
}

resource "vault_policy" "api-management-tool-gha" {
  name = "dev-portal-global"

  policy = <<EOT
path "apisix-dev/apikeys/*" { capabilities = ["read"] } 
path "apisix-dev/urls/*" { capabilities = ["read"] } 
path "apisix-dev/admin/*" { capabilities = ["read"] }
EOT

  depends_on = [module.ewc-vault-init]
}

resource "vault_policy" "backup-cron-job" {
  name = "backup-cron-job"

  policy = <<EOT
path "sys/storage/raft/snapshot" {
  capabilities = ["read"]
}
EOT

  depends_on = [module.ewc-vault-init]
}

resource "vault_jwt_auth_backend_role" "api-management-tool-gha" {
  role_name  = "api-management-tool-gha"
  backend    = vault_jwt_auth_backend.github.path
  role_type  = "jwt"
  user_claim = "actor"
  bound_claims = {
    repository : "EURODEO/api-management-tool-poc"
  }
  bound_audiences = ["https://github.com/EURODEO/api-management-tool-poc"]
  token_policies  = [vault_policy.api-management-tool-gha.name]
  token_ttl       = 300

  depends_on = [module.ewc-vault-init]
}

resource "vault_kubernetes_auth_backend_role" "backup-cron-job" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "backup-cron-job"
  bound_service_account_names      = [kubernetes_service_account.vault_backup_cron_job_service_account.metadata.0.name]
  bound_service_account_namespaces = [module.ewc-vault-init.vault_namespace_name]
  token_policies                   = [vault_policy.backup-cron-job.name]
  token_ttl                        = 300

  depends_on = [module.ewc-vault-init]
}

resource "vault_token" "apisix-global" {
  policies  = [vault_policy.apisix-global.name]
  period    = "768h"
  renewable = true

  depends_on = [module.ewc-vault-init]
}
resource "vault_token" "dev-portal-global" {
  policies  = [vault_policy.dev-portal-global.name]
  period    = "768h"
  renewable = true

  depends_on = [module.ewc-vault-init]
}


################################################################################
# Install gateway apps
################################################################################
# Create project for gateway
resource "rancher2_project" "gateway" {
  name       = "gateway"
  cluster_id = var.rancher_cluster_id
}

################################################################################

# Install Dev-portal and keycloak
################################################################################

module "dev-portal-init" {
  count = var.install_dev-portal ? 1 : 0

  source = "./dev-portal-init/"

  kubeconfig_path = var.kubeconfig_path

  dns_zone = var.dns_zone

  cluster_issuer   = module.ewc-vault-init.cluster_issuer
  load_balancer_ip = module.ewc-vault-init.load_balancer_ip

  rancher_project_id = rancher2_project.gateway.id

  keycloak_subdomain               = var.keycloak_subdomain
  keycloak_admin_password          = var.keycloak_admin_password
  keycloak_backup_bucket_base_path = var.keycloak_backup_bucket_base_path

  dev-portal_subdomain         = var.dev-portal_subdomain
  dev-portal_registry_password = var.dev-portal_registry_password
  dev-portal_vault_token       = vault_token.dev-portal-global.client_token

  apisix_subdomain = var.apisix_subdomain
  apisix_admin     = var.apisix_admin

  google_idp_client_secret = var.google_idp_client_secret
  github_idp_client_secret = var.github_idp_client_secret

  s3_bucket_access_key = var.s3_bucket_access_key
  s3_bucket_secret_key = var.s3_bucket_secret_key

}

################################################################################

# Install Apisix
################################################################################
resource "kubernetes_namespace" "apisix" {
  metadata {
    annotations = {
      "field.cattle.io/projectId" = rancher2_project.gateway.id
    }

    name = "apisix"
  }
}

# ConfigMap for custom error pages
resource "kubernetes_config_map" "custom_error_pages" {
  metadata {
    name      = "custom-error-pages"
    namespace = kubernetes_namespace.apisix.metadata.0.name
  }
  data = {
    "apisix_error_429.html" = templatefile("../apisix/error_pages/apisix_error_429.html", {
      devportal_address = "${var.dev-portal_subdomain}.${var.dns_zone}"
    })
    "apisix_error_403.html" = templatefile("../apisix/error_pages/apisix_error_403.html", {
      devportal_address = "${var.dev-portal_subdomain}.${var.dns_zone}"
    })
  }
}

resource "helm_release" "apisix" {
  name             = "apisix"
  repository       = "https://charts.apiseven.com"
  chart            = "apisix"
  version          = "2.6.0"
  namespace        = kubernetes_namespace.apisix.metadata.0.name
  create_namespace = false

  values = [
    templatefile("./helm-values/apisix-values-template.yaml", {
      cluster_issuer = module.ewc-vault-init.cluster_issuer,
      hostname       = "${var.apisix_subdomain}.${var.dns_zone}",
      ip             = module.ewc-vault-init.load_balancer_ip
    })
  ]

  set_sensitive {
    name  = "apisix.admin.credentials.admin"
    value = var.apisix_admin
  }

  set_sensitive {
    name  = "apisix.admin.credentials.viewer"
    value = var.apisix_reader
  }

  set_list {
    name  = "apisix.admin.allow.ipList"
    value = var.apisix_ip_list
  }

  # Apisix vault integration
  set {
    name  = "apisix.vault.enabled"
    value = true
  }

  set {
    name  = "apisix.vault.host"
    value = local.vault_host
  }

  set {
    name  = "apisix.vault.prefix"
    value = "apisix-dev/consumers"
  }

  set_sensitive {
    name  = "apisix.vault.token"
    value = vault_token.apisix-global.client_token
  }

  # Custom error pages mount
  set {
    name  = "extraVolumeMounts[0].name"
    value = "custom-error-pages"

  }

  set {
    name  = "extraVolumeMounts[0].mountPath"
    value = "/custom/error-pages"

  }

  set {
    name  = "extraVolumeMounts[0].readOnly"
    value = true

  }

  set {
    name  = "extraVolumes[0].name"
    value = "custom-error-pages"

  }

  set {
    name  = "extraVolumes[0].configMap.name"
    value = kubernetes_config_map.custom_error_pages.metadata[0].name

  }

  set {
    name  = "extraVolumes[0].configMap.items[0].key"
    value = "apisix_error_403.html"

  }

  set {
    name  = "extraVolumes[0].configMap.items[0].path"
    value = "apisix_error_403.html"

  }

  set {
    name  = "extraVolumes[0].configMap.items[1].key"
    value = "apisix_error_429.html"

  }

  set {
    name  = "extraVolumes[0].configMap.items[1].path"
    value = "apisix_error_429.html"

  }

  #Custom error page nginx.conf
  set {
    name  = "apisix.nginx.configurationSnippet.httpStart"
    value = file("../apisix/error_values/httpStart")
  }

  set {
    name  = "apisix.nginx.configurationSnippet.httpSrv"
    value = file("../apisix/error_values/httpSrv")
  }

  # Trust container's CA for Vault and other outbound CA requests
  set {
    name  = "apisix.nginx.configurationSnippet.httpEnd"
    value = "lua_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;"

  }

  depends_on = [module.ewc-vault-init]

}

