variable "rancher_api_url" {
  description = "Rancher instance URL"
  type        = string
}

variable "rancher_token" {
  description = "Rancher instance access key"
  type        = string
  sensitive   = true
}

variable "rancher_insecure" {
  description = "Is Rancher instance insecure"
  type        = bool
  default     = false
}

variable "rancher_cluster_id" {
  description = "ID of your Rancher cluster"
  type        = string

}

variable "kubeconfig_path" {
  description = "Path to your kubeconfig"
  type        = string
  default     = "~/.kube/config"
  validation {
    condition     = fileexists(var.kubeconfig_path)
    error_message = "The specified kubeconfig file does not exist."
  }
}


variable "route53_access_key" {
  description = "AWS access key for route53"
  type        = string
  sensitive   = true
}

variable "route53_secret_key" {
  description = "AWS secret key for route53"
  type        = string
  sensitive   = true
}

variable "route53_zone_id_filter" {
  description = "ZoneIdFilter for route53"
  type        = string
}

variable "dns_zone" {
  description = "DNS zone for cert-manager"
  type        = string
  default     = "eumetnet-femdi.eumetsat.ewcloud.host"
}

variable "email_cert_manager" {
  description = "email for Let's encrypt cert-manager"
  type        = string
}

variable "apisix_admin" {
  description = "Admin API key to control access to the APISIX Admin API endpoints"
  type        = string
  sensitive   = true
}

variable "apisix_reader" {
  description = "Reader API key to control access to the APISIX Admin API endpoints"
  type        = string
  sensitive   = true
}

variable "apisix_subdomain" {
  description = "subdomain where apisix will be hosted"
  type        = string
  default     = "gateway"
}

variable "apisix_ip_list" {
  description = "Restrict Admin API Access by IP CIDR"
  type        = list(string)
  default     = ["0.0.0.0/0"]
  validation {
    condition = alltrue([
      for i in var.apisix_ip_list :
      can(cidrnetmask(i))
    ])
    error_message = "Not a valid list of CIDR-blocks"
  }
}

variable "apisix_replicas" {
  description = "Amount of minimum replicas for APISIX"
  type        = number
  default     = 1
}

variable "apisix_etcd_replicas" {
  description = "Amount of etcd replicas for APISIX"
  type        = number
  default     = 3
}

variable "keycloak_admin_password" {
  description = "Password for keycloak admin"
  type        = string
  sensitive   = true
}

variable "keycloak_subdomain" {
  description = "subdomain where keycloak will be hosted"
  type        = string
  default     = "keycloak"
}

variable "keycloak_replicas" {
  description = "Amount of keycloak replicas"
  type        = number
  default     = 1
}

variable "vault_subdomain" {
  description = "subdomain where vault will be hosted"
  type        = string
  default     = "vault"
}

variable "vault_replicas" {
  description = "Amount of vault replicas"
  type        = number
  default     = 3
}

variable "vault_anti-affinity" {
  description = "Do you want to use Vault anti-affinity"
  type        = bool
  default     = true
}

variable "vault_key_treshold" {
  description = "Treshold to unseal Vault"
  type        = number
  default     = 3
}

variable "vault_token" {
  description = "Token for Vault if it is already initialized"
  type        = string
  sensitive   = true
}

variable "install_dev-portal" {
  description = "Should Dev-portal be installed"
  type        = bool
  default     = true
}

variable "dev-portal_subdomain" {
  description = "subdomain where devportal will be hosted"
  type        = string
  default     = "devportal"
}

variable "dev-portal_registry_password" {
  description = "Container registry password for dev-portal"
  type        = string
  sensitive   = true
}

variable "google_idp_client_secret" {
  description = "Secret to use Google idp"
  type        = string
  sensitive   = true
}

variable "github_idp_client_secret" {
  description = "Secret to use Github idp"
  type        = string
  sensitive   = true
}

variable "s3_bucket_access_key" {
  description = "AWS access key for S3 bucket for backups"
  type        = string
  sensitive   = true
}

variable "s3_bucket_secret_key" {
  description = "AWS secret key for S3 bucket for backups"
  type        = string
  sensitive   = true
}

variable "backup_bucket_base_path" {
  description = "AWS S3 backup bucket base path"
  type        = string
  default     = "dev-rodeo-backups/ewc"
}

variable "alert_email_recipients" {
  description = "Email addresses to receive alerts"
  type        = list(string)
  default     = []
}

variable "alert_email_sender" {
  description = "Email address to send alerts"
  type        = string
}

variable "alert_smtp_auth_username" {
  description = <<-EOF
SMTP username for alertmanager.
Leave empty if not available yet. 
Note: Leaving empty will skip the creation of the default Alertmanager Config
EOF
  type        = string
}

variable "alert_smtp_auth_password" {
  description = <<-EOF
SMTP password for alertmanager.
Leave empty if not available yet. 
Note: Leaving empty will skip the creation of the default Alertmanager Config
EOF
  type        = string
  sensitive   = true
}

variable "alert_smtp_host" {
  description = "SMTP host for alertmanager"
  type        = string
  default     = "smtp.gmail.com:587"
}
