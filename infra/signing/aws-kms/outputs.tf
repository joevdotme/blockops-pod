output "kms_key_arn" {
  description = "ARN of the release signing KMS key."
  value       = aws_kms_key.release_signer.arn
}

output "kms_key_id" {
  description = "ID of the release signing KMS key."
  value       = aws_kms_key.release_signer.key_id
}

output "kms_alias" {
  description = "Alias for the release signing KMS key."
  value       = aws_kms_alias.release_signer.name
}

output "github_actions_role_arn" {
  description = "IAM role GitHub Actions can assume with OIDC."
  value       = aws_iam_role.github_actions_signer.arn
}
