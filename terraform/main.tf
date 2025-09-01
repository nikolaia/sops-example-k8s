locals {
  flux_components_flag = length(var.flux_components_extra) > 0 ? "--components-extra=${join(",", var.flux_components_extra)}" : ""
  flux_version_flag    = var.flux_version != "" ? "--version ${var.flux_version}" : ""
  flux_secret_files    = fileset(path.module, "secrets/flux-gpg-secret.yaml")
}

locals {
  flux_install_flags = compact([
    "--context ${var.kubeconfig_context}",
    "--namespace flux-system",
    local.flux_components_flag != "" ? local.flux_components_flag : null,
    local.flux_version_flag != "" ? local.flux_version_flag : null
  ])
}

data "sops_file" "flux_gpg_secret" {
  count       = length(local.flux_secret_files) > 0 ? 1 : 0
  source_file = "${path.module}/secrets/flux-gpg-secret.yaml"
}

locals {
  flux_secret_enabled      = length(local.flux_secret_files) > 0
  flux_secret_manifest_raw = local.flux_secret_enabled ? yamldecode(data.sops_file.flux_gpg_secret[0].raw) : null
  flux_secret_metadata     = local.flux_secret_enabled ? try(local.flux_secret_manifest_raw.metadata, {}) : {}
  flux_secret_data         = local.flux_secret_enabled ? try(local.flux_secret_manifest_raw.data, {}) : {}
  flux_secret_string_data  = local.flux_secret_enabled ? try(local.flux_secret_manifest_raw.stringData, {}) : {}
  flux_secret_name         = local.flux_secret_enabled ? try(local.flux_secret_metadata.name, var.flux_sops_secret_name) : var.flux_sops_secret_name
  flux_secret_namespace    = local.flux_secret_enabled ? try(local.flux_secret_metadata.namespace, "flux-system") : "flux-system"
}

provider "kubernetes" {
  config_path    = pathexpand(var.kubeconfig_path)
  config_context = var.kubeconfig_context
}

resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }
}

resource "kubernetes_secret" "flux_sops_key" {
  count = local.flux_secret_enabled ? 1 : 0

  metadata {
    name      = local.flux_secret_name
    namespace = local.flux_secret_namespace
  }

  data        = local.flux_secret_data
  string_data = local.flux_secret_string_data
  type        = try(local.flux_secret_manifest_raw.type, "Opaque")

  depends_on = [kubernetes_namespace.flux_system]
}

resource "null_resource" "flux_bootstrap" {
  triggers = {
    kubeconfig_context   = var.kubeconfig_context
    flux_version_flag    = local.flux_version_flag
    flux_components_flag = local.flux_components_flag
    flux_git_url         = var.flux_git_repository_url
    flux_git_branch      = var.flux_git_branch
    flux_git_source      = var.flux_git_source_name
    flux_kustomization   = var.flux_kustomization_name
    flux_path            = var.flux_kustomization_path
    flux_interval        = var.flux_reconcile_interval
    flux_sops_secret     = var.flux_sops_secret_name
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-lc"]
    command = <<-EOT
      set -euo pipefail

      ${var.flux_cli_path} install ${join(" ", local.flux_install_flags)}

      if [ -n "${var.flux_git_repository_url}" ]; then
        ${var.flux_cli_path} create source git ${var.flux_git_source_name} \
          --context ${var.kubeconfig_context} \
          --url="${var.flux_git_repository_url}" \
          --branch="${var.flux_git_branch}" \
          --interval=${var.flux_reconcile_interval} \
          --export | ${var.kubectl_cli_path} --context ${var.kubeconfig_context} apply -f -

        ${var.flux_cli_path} create kustomization ${var.flux_kustomization_name} \
          --context ${var.kubeconfig_context} \
          --source=GitRepository/${var.flux_git_source_name} \
          --path="${var.flux_kustomization_path}" \
          --prune=true \
          --interval=${var.flux_reconcile_interval} \
          --decryption-provider=sops \
          --decryption-secret=${var.flux_sops_secret_name} \
          --export | ${var.kubectl_cli_path} --context ${var.kubeconfig_context} apply -f -
      fi
    EOT
  }

  depends_on = concat(
    [kubernetes_namespace.flux_system],
    [for s in kubernetes_secret.flux_sops_key : s]
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "null_resource" "flux_cleanup" {
  triggers = {
    kubeconfig_context = var.kubeconfig_context
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      if command -v ${var.flux_cli_path} >/dev/null 2>&1; then
        ${var.flux_cli_path} uninstall --context ${var.kubeconfig_context} --namespace flux-system --silent || true
      fi
    EOT
  }
}
