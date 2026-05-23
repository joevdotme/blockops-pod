variable "aws_region" {
  description = "AWS region for the KMS key."
  type        = string
  default     = "us-east-1"
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the signer role, formatted as owner/repo."
  type        = string
}

variable "github_ref" {
  description = "Git ref allowed to assume the signer role."
  type        = string
  default     = "refs/heads/main"
}

variable "github_oidc_provider_arn" {
  description = "Existing IAM OIDC provider ARN for token.actions.githubusercontent.com."
  type        = string
}

variable "github_actions_role_name" {
  description = "IAM role name for GitHub Actions release signing."
  type        = string
  default     = "blockops-github-actions-release-signer"
}

variable "github_actions_policy_name" {
  description = "IAM policy name for KMS signing."
  type        = string
  default     = "blockops-kms-release-signing"
}

variable "kms_alias" {
  description = "KMS alias without the alias/ prefix."
  type        = string
  default     = "blockops-release-signer"
}

variable "kms_deletion_window_days" {
  description = "KMS deletion window. Keep high for production."
  type        = number
  default     = 30
}
