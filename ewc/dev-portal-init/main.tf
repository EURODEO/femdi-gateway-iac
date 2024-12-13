################################################################################
# Install Keycloak 
################################################################################

locals {
  postgres_host    = "keycloak-postgresql.keycloak.svc.cluster.local"
  postgres_db_name = "bitnami_keycloak" # Default from Helm chart
  postgres_db_user = "bn_keycloak"      # default from Helm chart
}

resource "kubernetes_namespace" "keycloak" {
  metadata {
    annotations = {
      "field.cattle.io/projectId" = var.rancher_project_id
    }

    name = "keycloak"
  }
}

resource "random_password" "keycloak-dev-portal-secret" {
  length = 32
}

# Create configmap for realm json
resource "kubernetes_config_map" "realm-json" {
  metadata {
    name      = "realm-json"
    namespace = kubernetes_namespace.keycloak.metadata.0.name
  }
  data = {
    "realm.json" = templatefile("./keycloak-realm/realm-export.json", {
      dev_portal_api_secret    = random_password.keycloak-dev-portal-secret.result
      frontend_url             = "https://${var.dev-portal_subdomain}.${var.dns_zone}",
      google_idp_client_secret = var.google_idp_client_secret
      github_idp_client_secret = var.github_idp_client_secret
    })
  }
}

#TODO: Add HPA
#TODO: Consider managing the secrets in self managed kubernetes_secret instead of using Helm chart generated secret
#      Could not make self managed secret work reliably. Possible cause of this https://github.com/bitnami/charts/issues/18014
resource "helm_release" "keycloak" {
  name             = "keycloak"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "keycloak"
  version          = "21.1.2"
  namespace        = kubernetes_namespace.keycloak.metadata.0.name
  create_namespace = false

  values = [
    templatefile("./helm-values/keycloak-values-template.yaml", {
      cluster_issuer = var.cluster_issuer
      hostname       = "${var.keycloak_subdomain}.${var.dns_zone}",
      ip             = var.load_balancer_ip
    })
  ]

  # Needed for tls termination at ingress
  # See: https://github.com/bitnami/charts/tree/main/bitnami/keycloak#use-with-ingress-offloading-ssl
  set {
    name  = "proxy"
    value = "edge"
  }

  set {
    name  = "auth.adminUser"
    value = "admin"
  }

  set_sensitive {
    name  = "auth.adminPassword"
    value = var.keycloak_admin_password
  }

  set {
    name  = "postgresql.auth.username"
    value = local.postgres_db_user
  }

  set {
    name  = "postgresql.auth.database"
    value = local.postgres_db_name
  }

  # Needed for configmap realm import
  # See: https://github.com/bitnami/charts/issues/5178#issuecomment-765361901
  set {
    name  = "extraStartupArgs"
    value = "--import-realm"

  }

  set {
    name  = "extraVolumeMounts[0].name"
    value = "config"

  }

  set {
    name  = "extraVolumeMounts[0].mountPath"
    value = "/opt/bitnami/keycloak/data/import"

  }

  set {
    name  = "extraVolumeMounts[0].readOnly"
    value = true

  }

  set {
    name  = "extraVolumes[0].name"
    value = "config"

  }

  set {
    name  = "extraVolumes[0].configMap.name"
    value = kubernetes_config_map.realm-json.metadata[0].name

  }

  set {
    name  = "extraVolumes[0].configMap.items[0].key"
    value = "realm.json"

  }

  set {
    name  = "extraVolumes[0].configMap.items[0].path"
    value = "realm.json"

  }


}

################################################################################

# Install Dev-portal
################################################################################
resource "kubernetes_namespace" "dev-portal" {
  metadata {
    annotations = {
      "field.cattle.io/projectId" = var.rancher_project_id
    }

    name = "dev-portal"
  }
}

resource "random_password" "dev-portal-password" {
  length = 32
}

# Create Secret for credentials
resource "kubernetes_secret" "dev-portal-secret-for-backend" {
  metadata {
    name      = "dev-portal-secret-for-backend"
    namespace = kubernetes_namespace.dev-portal.metadata.0.name
  }

  data = {
    "secrets.yaml" = yamlencode({

      "vault" = {
        "url"          = "http://vault-active.vault.svc.cluster.local:8200"
        "token"        = var.dev-portal_vault_token
        "base_path"    = "apisix-dev/consumers"
        "secret_phase" = random_password.dev-portal-password.result
      }

      "apisix" = {
        "key_path" = "$secret:/vault/1"
        "instances" = [
          {
            "name"          = "EWC"
            "admin_url"     = "http://apisix-admin.apisix.svc.cluster.local:9180"
            "gateway_url"   = "https://${var.apisix_subdomain}.${var.dns_zone}"
            "admin_api_key" = var.apisix_admin
          }
        ]
      }
      "keycloak" = {
        "url"           = "http://keycloak.keycloak.svc.cluster.local"
        "realm"         = "test"
        "client_id"     = "dev-portal-api"
        "client_secret" = random_password.keycloak-dev-portal-secret.result
      }
    })
  }

  type = "Opaque"
}

resource "helm_release" "dev-portal" {
  name             = "dev-portal"
  repository       = "https://rodeo-project.eu/Dev-portal/"
  chart            = "dev-portal"
  version          = "1.10.2"
  namespace        = kubernetes_namespace.dev-portal.metadata.0.name
  create_namespace = false

  values = [
    templatefile("./helm-values/dev-portal-values-template.yaml", {
      cluster_issuer = var.cluster_issuer
      hostname       = "${var.dev-portal_subdomain}.${var.dns_zone}",
      ip             = var.load_balancer_ip
    })
  ]

  set {
    name  = "imageCredentials.username"
    value = "USERNAME"
  }

  set_sensitive {
    name  = "imageCredentials.password"
    value = var.dev-portal_registry_password
  }

  set {
    name  = "backend.image.tag"
    value = "sha-e5fe5f5"
  }

  set {
    name  = "backend.secrets.secretName"
    value = kubernetes_secret.dev-portal-secret-for-backend.metadata.0.name
  }

  set {
    name  = "backend.secrets.secretName"
    value = kubernetes_secret.dev-portal-secret-for-backend.metadata.0.name
  }

  set {
    name  = "frontend.image.tag"
    value = "sha-5608cd2"
  }

  set {
    name  = "frontend.keycloak_logout_url"
    value = "https://${var.dev-portal_subdomain}.${var.dns_zone}"
  }

  set {
    name  = "frontend.keycloak_url"
    value = "https://${var.keycloak_subdomain}.${var.dns_zone}"
  }


}
