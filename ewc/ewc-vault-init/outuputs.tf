output "load_balancer_ip" {
  description = "Ip of load balancer created by nginx-ingress-controller"
  value       = join(".", slice(split(".", data.kubernetes_service.ingress-nginx-controller.status[0].load_balancer[0].ingress[0].hostname), 0, 4))
}

output "cluster_issuer" {
  description = "Let's Encrypt cluster issuer's name"
  value       = kubectl_manifest.clusterissuer_letsencrypt_prod.name
}

output "vault_pod_ready_statuses_before_init" {
  description = "Vault cluster status before running init. If this array is true you should have unseal and root token in a previus run"
  value = flatten([
    for pod in data.kubernetes_resource.vault-pods-before : [
      for condition in pod.object.status.conditions : condition.status
      if condition.type == "Ready"
    ]
  ])
}

output "vault_unseal_keys" {
  description = "Keys for vault unsealing. Store somewhere safe. If empty Vault already initialized."
  value       = try([for s in split(",", data.external.vault-init.result.flattened_unseal_keys_b64) : s], null)
  sensitive   = true
}

output "vault_root_token" {
  description = "Root token for vault. Store somewhere safe. If empty Vault already initialized."
  value       = try(data.external.vault-init.result.root_token, null)
  sensitive   = true
}

output "vault_pod_ready_statuses_after_init" {
  description = "Vault cluster status ater running init. Should be true."
  value = flatten([
    for pod in data.kubernetes_resource.vault-pods-after : [
      for condition in pod.object.status.conditions : condition.status
      if condition.type == "Ready"
    ]
  ])
}

output "vault_namespace_name" {
  description = "Name of the namespace where Vault is running"
  value       = kubernetes_namespace.vault.metadata[0].name
}
