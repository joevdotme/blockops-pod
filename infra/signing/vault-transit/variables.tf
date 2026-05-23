variable "vault_addr" {
  description = "Vault address."
  type        = string
}

variable "transit_mount" {
  description = "Vault Transit mount path."
  type        = string
  default     = "transit"
}

variable "transit_key_name" {
  description = "Vault Transit key name."
  type        = string
  default     = "blockops-release-signer"
}

variable "transit_key_type" {
  description = "Vault Transit key type. Confirm secp256k1 compatibility before Ethereum production use."
  type        = string
  default     = "ecdsa-p256"
}

variable "policy_name" {
  description = "Vault policy name for release signing."
  type        = string
  default     = "blockops-release-signer"
}

variable "create_github_jwt_auth_backend" {
  description = "Whether to create the GitHub Actions JWT auth backend."
  type        = bool
  default     = false
}

variable "github_jwt_auth_path" {
  description = "Vault JWT auth mount path for GitHub Actions."
  type        = string
  default     = "jwt-github"
}

variable "github_jwt_role_name" {
  description = "Vault JWT role name for GitHub Actions release signing."
  type        = string
  default     = "blockops-github-actions-release-signer"
}

variable "github_repository" {
  description = "GitHub repository allowed to sign releases, formatted as owner/repo."
  type        = string
}

variable "github_ref" {
  description = "Git ref allowed to sign releases."
  type        = string
  default     = "refs/heads/main"
}
