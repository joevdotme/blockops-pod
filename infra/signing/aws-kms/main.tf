terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity",
    ]

    principals {
      type = "Federated"
      identifiers = [
        var.github_oidc_provider_arn,
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repository}:ref:${var.github_ref}",
      ]
    }
  }
}

resource "aws_kms_key" "release_signer" {
  description              = "BlockOps release signing key"
  deletion_window_in_days  = var.kms_deletion_window_days
  key_usage                = "SIGN_VERIFY"
  customer_master_key_spec = "ECC_SECG_P256K1"
  enable_key_rotation      = false

  tags = {
    Project = "blockops"
    Purpose = "release-signing"
  }
}

resource "aws_kms_alias" "release_signer" {
  name          = "alias/${var.kms_alias}"
  target_key_id = aws_kms_key.release_signer.key_id
}

resource "aws_iam_role" "github_actions_signer" {
  name               = var.github_actions_role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

data "aws_iam_policy_document" "kms_signer" {
  statement {
    sid    = "AllowReleaseSigning"
    effect = "Allow"

    actions = [
      "kms:DescribeKey",
      "kms:GetPublicKey",
      "kms:Sign",
    ]

    resources = [
      aws_kms_key.release_signer.arn,
    ]
  }
}

resource "aws_iam_policy" "kms_signer" {
  name   = var.github_actions_policy_name
  policy = data.aws_iam_policy_document.kms_signer.json
}

resource "aws_iam_role_policy_attachment" "kms_signer" {
  role       = aws_iam_role.github_actions_signer.name
  policy_arn = aws_iam_policy.kms_signer.arn
}
