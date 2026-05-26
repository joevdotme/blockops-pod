variable "aws_region" {
  description = "AWS region where signing resources will be provisioned."
  type        = string
  default     = "us-east-1"
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the provisioning role, formatted as owner/repo."
  type        = string
}

variable "github_environment" {
  description = "Protected GitHub Environment allowed to assume the provisioning role."
  type        = string
  default     = "signing-production"
}

variable "github_oidc_subjects" {
  description = "Optional explicit GitHub OIDC subject allowlist. Defaults to the protected environment subject."
  type        = list(string)
  default     = []
}

variable "create_github_oidc_provider" {
  description = "Create the token.actions.githubusercontent.com OIDC provider. Set false if the account already has one."
  type        = bool
  default     = true
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub Actions OIDC provider ARN. Required when create_github_oidc_provider is false."
  type        = string
  default     = ""
}

variable "role_name" {
  description = "IAM role name to expose as AWS_PROVISION_ROLE_ARN in GitHub."
  type        = string
  default     = "blockops-github-actions-signing-provisioner"
}

variable "policy_name" {
  description = "IAM policy name for signing infrastructure provisioning."
  type        = string
  default     = "blockops-signing-provisioner"
}

variable "managed_role_name_prefix" {
  description = "Role name prefix the provisioner is allowed to manage."
  type        = string
  default     = "blockops-"
}

variable "managed_policy_name_prefix" {
  description = "Policy name prefix the provisioner is allowed to manage."
  type        = string
  default     = "blockops-"
}
