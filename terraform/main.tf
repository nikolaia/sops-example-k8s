data "sops_file" "flux_gpg_private" {
  source_file = "${path.module}/keys/flux-gpg-private.asc"
  input_type  = "raw"
}

data "sops_file" "github_pat" {
  count       = fileexists("${path.module}/secrets/github-pat.yaml") ? 1 : 0
  source_file = "${path.module}/secrets/github-pat.yaml"
  input_type  = "yaml"
}

locals {
  flux_components_flag = var.flux_components_extra
  flux_http_username   = length(data.sops_file.github_pat) > 0 ? trimspace(lookup(data.sops_file.github_pat[0].data, "stringData.username", "")) : ""
  flux_http_password   = length(data.sops_file.github_pat) > 0 ? trimspace(lookup(data.sops_file.github_pat[0].data, "stringData.token", "")) : ""
}

provider "kubernetes" {
  config_path    = pathexpand(var.kubeconfig_path)
  config_context = var.kubeconfig_context
}

provider "flux" {
  kubernetes = {
    config_path    = pathexpand(var.kubeconfig_path)
    config_context = var.kubeconfig_context
  }

  git = {
    url    = var.flux_git_repository_url
    branch = var.flux_git_branch

    http = {
      username = local.flux_http_username
      password = local.flux_http_password
    }
  }
}

resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }
}

resource "kubernetes_secret" "flux_sops_key" {
  metadata {
    name      = var.flux_sops_secret_name
    namespace = "flux-system"
  }

  type = "Opaque"

  data = {
    "sops.asc" = data.sops_file.flux_gpg_private.raw
  }

  depends_on = [kubernetes_namespace.flux_system]
}

resource "flux_bootstrap_git" "this" {
  depends_on = [kubernetes_secret.flux_sops_key]

  components_extra    = local.flux_components_flag
  embedded_manifests  = true
  interval            = var.flux_reconcile_interval
  namespace           = "flux-system"
  path                = trim(var.flux_kustomization_path, "./")
  delete_git_manifests = false
  keep_namespace       = true

  kustomization_override = templatefile("${path.module}/templates/flux-kustomization.yaml", {
    path              = trim(var.flux_kustomization_path, "./")
    interval          = var.flux_reconcile_interval
    prune             = "true"
    decryption_secret = var.flux_sops_secret_name
  })

  lifecycle {
    precondition {
      condition     = length(local.flux_http_username) > 0 && length(local.flux_http_password) > 0
      error_message = "Create terraform/secrets/github-pat.yaml, populate username/token, and encrypt it with SOPS before running OpenTofu."
    }
  }
}
