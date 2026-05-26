output "aws_provision_role_arn" {
  description = "Add this value to the GitHub signing-production environment as AWS_PROVISION_ROLE_ARN."
  value       = aws_iam_role.github_actions_signing_provisioner.arn
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN."
  value       = local.github_oidc_provider_arn
}

output "allowed_oidc_subjects" {
  description = "GitHub OIDC subjects allowed to assume the provisioning role."
  value       = local.oidc_subjects
}

output "policy_arn" {
  description = "Provisioning policy ARN."
  value       = aws_iam_policy.signing_provisioner.arn
}
