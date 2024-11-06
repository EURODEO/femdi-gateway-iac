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


variable "vault_project_id" {
  description = "Rancher project where vault namespace will be created"
  type        = string
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


