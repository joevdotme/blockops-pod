terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  count = var.create_github_oidc_provider ? 1 : 0

  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    data.tls_certificate.github_actions.certificates[0].sha1_fingerprint,
  ]

  tags = {
    Project = "blockops"
    Purpose = "github-actions-oidc"
  }
}

locals {
  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github_actions[0].arn : var.github_oidc_provider_arn

  default_subjects = [
    "repo:${var.github_repository}:environment:${var.github_environment}",
  ]

  oidc_subjects = length(var.github_oidc_subjects) > 0 ? var.github_oidc_subjects : local.default_subjects
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity",
    ]

    principals {
      type = "Federated"
      identifiers = [
        local.github_oidc_provider_arn,
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
      values   = local.oidc_subjects
    }
  }
}

resource "aws_iam_role" "github_actions_signing_provisioner" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  description        = "Allows protected GitHub Actions jobs to provision BlockOps signing infrastructure."

  tags = {
    Project = "blockops"
    Purpose = "signing-provisioning"
  }
}

data "aws_iam_policy_document" "signing_provisioner" {
  statement {
    sid    = "AllowKmsSignerProvisioning"
    effect = "Allow"

    actions = [
      "kms:CreateAlias",
      "kms:CreateKey",
      "kms:DeleteAlias",
      "kms:DescribeKey",
      "kms:DisableKey",
      "kms:EnableKey",
      "kms:GetKeyPolicy",
      "kms:GetPublicKey",
      "kms:ListAliases",
      "kms:ListResourceTags",
      "kms:PutKeyPolicy",
      "kms:ScheduleKeyDeletion",
      "kms:Sign",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:UpdateAlias",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  statement {
    sid    = "AllowIamSignerRoleProvisioning"
    effect = "Allow"

    actions = [
      "iam:AttachRolePolicy",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:CreateRole",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:DeleteRole",
      "iam:DetachRolePolicy",
      "iam:GetOpenIDConnectProvider",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetRole",
      "iam:ListAttachedRolePolicies",
      "iam:ListPolicyVersions",
      "iam:ListRolePolicies",
      "iam:TagPolicy",
      "iam:TagRole",
      "iam:UntagPolicy",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.managed_role_name_prefix}*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.managed_policy_name_prefix}*",
      local.github_oidc_provider_arn,
    ]
  }
}

resource "aws_iam_policy" "signing_provisioner" {
  name        = var.policy_name
  description = "Allows provisioning of BlockOps KMS signing resources from a protected GitHub Actions environment."
  policy      = data.aws_iam_policy_document.signing_provisioner.json

  tags = {
    Project = "blockops"
    Purpose = "signing-provisioning"
  }
}

resource "aws_iam_role_policy_attachment" "signing_provisioner" {
  role       = aws_iam_role.github_actions_signing_provisioner.name
  policy_arn = aws_iam_policy.signing_provisioner.arn
}
