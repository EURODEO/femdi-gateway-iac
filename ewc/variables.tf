variable "rancher_api_url" {
  description = "Rancher instance URL"
  type        = string
}

variable "rancher_token" {
  description = "Rancher instance access key"
  type        = string
  sensitive   = true
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

variable "keycloak_admin_password" {
  description = "Password for keycloak admin"
  sensitive   = true
}

variable "keycloak_subdomain" {
  description = "subdomain where keycloak will be hosted"
  type        = string
  default     = "keycloak"
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

variable "vault_key_treshold" {
  description = "Treshold to unseal Vault"
  type        = number
  default     = 3
}


variable "devportal_subdomain" {
  description = "subdomain where devportal will be hosted"
  type        = string
  default     = "devportal"
}

variable "vault_backup_bucket_base_uri" {
  description = "AWS S3 bucket base URI for vault backups"
  type        = string
  default     = "s3://dev-rodeo-ewc-vault/vault/"
}

variable "s3_bucket_access_key" {
  description = "AWS access key for S3 bucket"
  type        = string
  sensitive   = true
}

variable "s3_bucket_secret_key" {
  description = "AWS secret key for S3 bucket"
  type        = string
  sensitive   = true
}
