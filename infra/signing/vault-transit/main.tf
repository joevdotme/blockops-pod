terraform {
  required_version = ">= 1.6.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

provider "vault" {
  address = var.vault_addr
}

resource "vault_mount" "transit" {
  path        = var.transit_mount
  type        = "transit"
  description = "BlockOps release signing transit backend"
}

resource "vault_transit_secret_backend_key" "release_signer" {
  backend          = vault_mount.transit.path
  name             = var.transit_key_name
  type             = var.transit_key_type
  deletion_allowed = false
  exportable       = false
}

data "vault_policy_document" "release_signer" {
  rule {
    path = "${vault_mount.transit.path}/sign/${vault_transit_secret_backend_key.release_signer.name}"

    capabilities = [
      "update",
    ]
  }

  rule {
    path = "${vault_mount.transit.path}/keys/${vault_transit_secret_backend_key.release_signer.name}"

    capabilities = [
      "read",
    ]
  }
}

resource "vault_policy" "release_signer" {
  name   = var.policy_name
  policy = data.vault_policy_document.release_signer.hcl
}

resource "vault_jwt_auth_backend" "github" {
  count = var.create_github_jwt_auth_backend ? 1 : 0

  path               = var.github_jwt_auth_path
  oidc_discovery_url = "https://token.actions.githubusercontent.com"
  bound_issuer       = "https://token.actions.githubusercontent.com"
}

resource "vault_jwt_auth_backend_role" "github_actions_release_signer" {
  backend   = var.github_jwt_auth_path
  role_name = var.github_jwt_role_name
  role_type = "jwt"

  token_policies = [
    vault_policy.release_signer.name,
  ]

  bound_audiences = [
    "sts.amazonaws.com",
  ]

  bound_claims = {
    repository = var.github_repository
    ref        = var.github_ref
  }

  user_claim = "sub"
}
