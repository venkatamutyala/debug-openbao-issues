variable "root_token" {
  description = "The root token for Vault authentication"
  type        = string
}


terraform {
  required_providers {

    vault = {
      source = "hashicorp/vault"
    }
  }
}


provider "vault" {
  address = "https://127.0.0.1:8200"
  token   = var.root_token
}



resource "vault_policy" "reader" {
  name = "reader"

  policy = <<EOF
    path "secret/*" {
    capabilities = ["read", "list"]
    }
    
    path "/cubbyhole/*" {
      capabilities = ["deny"]
    }
    EOF
}


resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}



resource "vault_kubernetes_auth_backend_config" "config" {
  backend         = vault_auth_backend.kubernetes.path
  kubernetes_host = "https://kubernetes.default.svc.cluster.local:443"
}



resource "vault_kubernetes_auth_backend_role" "env_roles" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "reader-role"
  bound_service_account_names      = ["*"]
  bound_service_account_namespaces = ["*"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.reader.name]
}

resource "vault_mount" "secrets_kvv2" {
  path        = "secret"
  type        = "kv-v2"
  description = "KV Version 2 secrets mount"
}


resource "vault_generic_secret" "example" {
  # Create a set of strings from "1" to "400"
  for_each = toset([for i in range(1, 401) : tostring(i)])

  # "each.value" (or "each.key") will be the string ("1", "2", etc.)
  path = "secret/foo${each.value}"

  data_json = <<EOT
{
  "foo":   "bar",
  "pizza": "cheese",
  "pizza2": "mushroom",
  "pizza3": "pork",
  "pizza4": "beef",
  "pizza5": "chicken"
}
EOT
}