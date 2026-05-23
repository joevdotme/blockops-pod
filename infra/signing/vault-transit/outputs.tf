output "transit_mount" {
  description = "Vault Transit mount path."
  value       = vault_mount.transit.path
}

output "transit_key_name" {
  description = "Vault Transit release signer key name."
  value       = vault_transit_secret_backend_key.release_signer.name
}

output "policy_name" {
  description = "Vault policy for release signing."
  value       = vault_policy.release_signer.name
}

output "github_jwt_role_name" {
  description = "Vault JWT role for GitHub Actions."
  value       = vault_jwt_auth_backend_role.github_actions_release_signer.role_name
}
