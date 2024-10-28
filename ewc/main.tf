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
  # Remove when EWC fixes their DNS
  insecure = true
}

provider "http" {
}

provider "vault" {
  address = "https://${var.vault_subdomain}.${var.dns_zone}"
  token   = coalesce(data.external.vault-init.result.root_token, var.vault_token)
}

provider "random" {
}

################################################################################
# Get id of Rancher System project
################################################################################
data "rancher2_project" "System" {
  provider   = rancher2
  cluster_id = var.rancher_cluster_id
  name       = "System"
}

################################################################################
# Install openstack-cinder-csi Plugin under System project
################################################################################
resource "kubernetes_namespace" "openstack-cinder-csi" {
  metadata {
    annotations = {
      "field.cattle.io/projectId" = data.rancher2_project.System.id
    }

    name = "openstack-cinder-csi"
  }
}
resource "helm_release" "csi-cinder" {
  name             = "openstack-cinder-csi"
  repository       = "https://kubernetes.github.io/cloud-provider-openstack"
  chart            = "openstack-cinder-csi"
  version          = "2.30.0"
  namespace        = kubernetes_namespace.openstack-cinder-csi.metadata.0.name
  create_namespace = false

  set {
    name  = "storageClass.delete.isDefault"
    value = true
  }

  set {
    name  = "secret.filename"
    value = "cloud-config"
  }
}

################################################################################
# Install ingress-nginx under System project
################################################################################
resource "kubernetes_namespace" "ingress-nginx" {
  metadata {
    annotations = {
      "field.cattle.io/projectId" = data.rancher2_project.System.id
    }

    name = "ingress-nginx"
  }
}
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.7.1"
  namespace        = kubernetes_namespace.ingress-nginx.metadata.0.name
  create_namespace = false

  set {
    name  = "controller.kind"
    value = "DaemonSet"
  }

  set {
    name  = "controller.ingressClassResource.default"
    value = true
  }

  # Needed for keycloak to work
  set {
    name  = "controller.config.proxy-buffer-size"
    value = "256k"
  }
}

data "kubernetes_service" "ingress-nginx-controller" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = kubernetes_namespace.ingress-nginx.metadata.0.name
  }

  depends_on = [helm_release.ingress_nginx]
}

################################################################################
# Install external-dns under System project
################################################################################
resource "kubernetes_namespace" "external-dns" {
  metadata {
    annotations = {
      "field.cattle.io/projectId" = data.rancher2_project.System.id
    }

    name = "external-dns"
  }
}
resource "helm_release" "external-dns" {
  name             = "external-dns"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "external-dns"
  version          = "6.23.6"
  namespace        = kubernetes_namespace.external-dns.metadata.0.name
  create_namespace = false

  set {
    name  = "policy"
    value = "upsert-only"
  }

  set {
    name  = "controller.ingressClassResource.default"
    value = true
  }

  set {
    name  = "aws.credentials.accessKey"
    value = var.route53_access_key

  }

  set {
    name  = "aws.credentials.secretKey"
    value = var.route53_secret_key

  }

  set_list {
    name  = "zoneIdFilters"
    value = [var.route53_zone_id_filter]
  }
}

################################################################################
# Install cert-manager under System project
################################################################################
resource "kubernetes_namespace" "cert-manager" {
  metadata {
    annotations = {
      "field.cattle.io/projectId" = data.rancher2_project.System.id
    }

    name = "cert-manager"
  }
}
resource "helm_release" "cert-manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io/"
  chart            = "cert-manager"
  version          = "1.11.5"
  namespace        = kubernetes_namespace.cert-manager.metadata.0.name
  create_namespace = false

  set {
    name  = "installCRDs"
    value = true
  }

  set {
    name  = "ingressShim.defaultACMEChallengeType"
    value = "dns01"
  }

  set {
    name  = "ingressShim.defaultACMEDNS01ChallengeProvider"
    value = "route53"
  }

  set {
    name  = "ingressShim.defaultIssuerKind"
    value = "ClusterIssuer"
  }

  set {
    name  = "ingressShim.letsencrypt-prod"
    value = "route53"
  }
}

resource "kubernetes_secret" "acme-route53-secret" {
  metadata {
    name      = "acme-route53"
    namespace = kubernetes_namespace.cert-manager.metadata.0.name
  }

  data = {
    secret-access-key = var.route53_secret_key
  }

  type = "Opaque"
}

locals {
  clusterissuer_letsencrypt_prod_manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name"      = "letsencrypt-prod"
      "namespace" = kubernetes_namespace.cert-manager.metadata.0.name
    }
    "spec" = {
      "acme" = {
        "email" = var.email_cert_manager
        "privateKeySecretRef" = {
          "name" = "letsencrypt-prod"
        }
        "server" = "https://acme-v02.api.letsencrypt.org/directory"
        "solvers" = [
          {
            "dns01" = {
              "route53" = {
                "accessKeyID" = var.route53_access_key
                "region"      = "eu-central-1"
                "secretAccessKeySecretRef" = {
                  "key"  = "secret-access-key"
                  "name" = kubernetes_secret.acme-route53-secret.metadata.0.name
                }
              }
            }
            "selector" = {
              "dnsZones" = [var.dns_zone]
            }
          },
        ]
      }
    }
  }
}

resource "kubectl_manifest" "clusterissuer_letsencrypt_prod" {
  yaml_body  = yamlencode(local.clusterissuer_letsencrypt_prod_manifest)
  depends_on = [helm_release.cert-manager]

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
# Install Keycloak 
################################################################################
resource "kubernetes_namespace" "keycloak" {
  metadata {
    annotations = {
      "field.cattle.io/projectId" = rancher2_project.gateway.id
    }

    name = "keycloak"
  }
}

# Download realm json
data "http" "realm-json" {
  url = "https://raw.githubusercontent.com/EURODEO/Dev-portal/main/keycloak/config/realm_export/realm-export.json"
}

# Create configmap for realm json
resource "kubernetes_config_map" "realm-json" {
  metadata {
    name      = "realm-json"
    namespace = kubernetes_namespace.keycloak.metadata.0.name
  }
  data = {
    "realm.json" = data.http.realm-json.response_body
  }
}

#TODO: Add HPA
resource "helm_release" "keycloak" {
  name             = "keycloak"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "keycloak"
  version          = "21.1.2"
  namespace        = kubernetes_namespace.keycloak.metadata.0.name
  create_namespace = false

  values = [
    templatefile("./helm-values/keycloak-values-template.yaml", {
      cluster_issuer = kubectl_manifest.clusterissuer_letsencrypt_prod.name,
      hostname       = "${var.keycloak_subdomain}.${var.dns_zone}",
      ip             = data.kubernetes_service.ingress-nginx-controller.status[0].load_balancer[0].ingress[0].ip,
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

  depends_on = [helm_release.cert-manager, helm_release.external-dns,
  helm_release.ingress_nginx, helm_release.csi-cinder]

}



################################################################################
# Install vault
################################################################################
resource "kubernetes_namespace" "vault" {
  metadata {
    annotations = {
      "field.cattle.io/projectId" = rancher2_project.gateway.id
    }

    name = "vault"
  }
}

locals {
  vault_certificate_secret = "vault-certificates"
  vault_issuer_manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "Issuer"
    "metadata" = {
      "name"      = "vault-selfsigned-issuer"
      "namespace" = kubernetes_namespace.vault.metadata.0.name
    }
    "spec" = {
      "selfSigned" = {}
    }
  }
  vault_certificate_manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "Certificate"
    "metadata" = {
      "name"      = local.vault_certificate_secret
      "namespace" = kubernetes_namespace.vault.metadata.0.name
    }
    "spec" = {
      "isCA"       = true
      "commonName" = "vault-ca"
      "secretName" = local.vault_certificate_secret
      "privateKey" = {
        "algorithm" = "ECDSA"
        "size"      = 256
      }
      "issuerRef" = {
        "group" = "cert-manager.io"
        "kind"  = "Issuer"
        "name"  = kubectl_manifest.vault-issuer.name
      }
      "dnsNames" = [
        "*.vault-internal",
        "*.vault-internal.${kubernetes_namespace.vault.metadata.0.name}",
        "*.vault-internal.${kubernetes_namespace.vault.metadata.0.name}.svc",
        "*.vault-internal.${kubernetes_namespace.vault.metadata.0.name}.svc.cluster.local",
      ]
    }
  }
}


resource "kubectl_manifest" "vault-issuer" {
  yaml_body  = yamlencode(local.vault_issuer_manifest)
  depends_on = [helm_release.cert-manager]
}

resource "kubectl_manifest" "vault-certificates" {
  yaml_body  = yamlencode(local.vault_certificate_manifest)
  depends_on = [helm_release.cert-manager, kubectl_manifest.vault-issuer]
}

resource "helm_release" "vault" {
  name             = "vault"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  version          = "0.28.0"
  namespace        = kubernetes_namespace.vault.metadata.0.name
  create_namespace = false

  values = [
    templatefile("./helm-values/vault-values-template.yaml", {
      cluster_issuer           = kubectl_manifest.clusterissuer_letsencrypt_prod.name,
      hostname                 = "${var.vault_subdomain}.${var.dns_zone}",
      ip                       = data.kubernetes_service.ingress-nginx-controller.status[0].load_balancer[0].ingress[0].ip,
      vault_certificate_secret = local.vault_certificate_secret
      replicas                 = var.vault_replicas
      replicas_iterator        = range(var.vault_replicas)
    })
  ]


  depends_on = [helm_release.cert-manager, helm_release.external-dns,
  helm_release.ingress_nginx, helm_release.csi-cinder]

}

# Wait for vault container to be availible
resource "time_sleep" "wait_5_second" {
  create_duration = "5s"
  depends_on      = [helm_release.vault]
}

data "kubernetes_resource" "vault-pods-before" {
  count = var.vault_replicas

  api_version = "v1"
  kind        = "Pod"

  metadata {
    name      = "vault-${count.index}"
    namespace = kubernetes_namespace.vault.metadata.0.name
  }

  depends_on = [helm_release.vault, time_sleep.wait_5_second]
}

data "external" "vault-init" {
  program = [
    "bash",
    "./vault-init/vault-init.sh",
    var.kubeconfig_path,
    kubernetes_namespace.vault.metadata.0.name,
    join(" ", flatten([
      for pod in data.kubernetes_resource.vault-pods-before : [
        for condition in pod.object.status.conditions : condition.status
        if condition.type == "Ready"
      ]])
    ),
    var.vault_key_treshold
  ]

  depends_on = [helm_release.vault, time_sleep.wait_5_second, data.kubernetes_resource.vault-pods-before]

}

data "kubernetes_resource" "vault-pods-after" {
  count = var.vault_replicas

  api_version = "v1"
  kind        = "Pod"

  metadata {
    name      = "vault-${count.index}"
    namespace = kubernetes_namespace.vault.metadata.0.name
  }

  depends_on = [helm_release.vault, time_sleep.wait_5_second, data.kubernetes_resource.vault-pods-before, data.external.vault-init]
}

resource "vault_mount" "apisix" {
  path        = "apisix"
  type        = "kv"
  options     = { version = "1" }
  description = "Apisix secrets"

  depends_on = [data.kubernetes_resource.vault-pods-after]
}

resource "vault_jwt_auth_backend" "github" {
  description        = "JWT for github actions"
  path               = "github"
  oidc_discovery_url = "https://token.actions.githubusercontent.com"
  bound_issuer       = "https://token.actions.githubusercontent.com"

  depends_on = [data.kubernetes_resource.vault-pods-after]
}

resource "vault_policy" "apisix-global" {
  name = "apisix-global"

  policy = <<EOT
path "apisix/consumers/*" {
  capabilities = ["read"]
}

EOT

  depends_on = [data.kubernetes_resource.vault-pods-after]
}

resource "vault_policy" "dev-portal-global" {
  name = "dev-portal-global"

  policy = <<EOT
path "apisix/consumers/*" {
	capabilities = ["create", "read", "update", "patch", "delete", "list"]
}
EOT

  depends_on = [data.kubernetes_resource.vault-pods-after]
}

resource "vault_policy" "api-management-tool-gha" {
  name = "dev-portal-global"

  policy = <<EOT
path "apisix-dev/apikeys/*" { capabilities = ["read"] } 
path "apisix-dev/urls/*" { capabilities = ["read"] } 
path "apisix-dev/admin/*" { capabilities = ["read"] }
EOT

  depends_on = [data.kubernetes_resource.vault-pods-after]
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
  depends_on      = [data.kubernetes_resource.vault-pods-after]
}

resource "vault_token" "apisix-global" {
  policies  = [vault_policy.apisix-global]
  period    = "768h"
  renewable = true
}
resource "vault_token" "dev-portal-global" {
  policies  = [vault_policy.dev-portal-global]
  period    = "768h"
  renewable = true
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
      cluster_issuer = kubectl_manifest.clusterissuer_letsencrypt_prod.name,
      hostname       = "${var.apisix_subdomain}.${var.dns_zone}",
      ip             = data.kubernetes_service.ingress-nginx-controller.status[0].load_balancer[0].ingress[0].ip
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
    value = "http://vault-active.vault.svc.cluster.local:8200"
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

  depends_on = [helm_release.cert-manager, helm_release.external-dns,
  helm_release.ingress_nginx, helm_release.csi-cinder]

}

################################################################################

# Install Dev-portal
################################################################################
resource "kubernetes_namespace" "dev-portal" {
  metadata {
    annotations = {
      "field.cattle.io/projectId" = rancher2_project.gateway.id
    }

    name = "dev-portal"
  }
}

resource "random_string" "random" {
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
        "token"        = vault_token.dev-portal-global
        "base_path"    = "apisix-dev/consumers"
        "secret_phase" = random_string.random.result
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
        "client_secret" = ""
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
      cluster_issuer = kubectl_manifest.clusterissuer_letsencrypt_prod.name,
      hostname       = "${var.dev-portal_subdomain}.${var.dns_zone}",
      ip             = data.kubernetes_service.ingress-nginx-controller.status[0].load_balancer[0].ingress[0].ip
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
    name  = "keycloak_url"
    value = "https://${var.keycloak_subdomain}.${var.dns_zone}"
  }
  depends_on = [helm_release.cert-manager, helm_release.external-dns,
    helm_release.ingress_nginx, helm_release.csi-cinder, helm_release.apisix
  , helm_release.keycloak]

}
