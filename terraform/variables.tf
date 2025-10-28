variable "kubeconfig_path" {
  type        = string
  description = "Path to the kubeconfig file the OpenTofu run should use."
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  type        = string
  description = "The kubeconfig context name that points at your demo cluster."
  default     = "kind-sops-demo"
}

variable "flux_components_extra" {
  type        = list(string)
  description = "Additional Flux components to enable during installation."
  default     = ["image-reflector-controller", "image-automation-controller"]
}

variable "flux_git_repository_url" {
  type        = string
  description = "Git repository URL Flux should reconcile."
  default     = "https://github.com/nikolaia/sops-example-k8s.git"
}

variable "flux_git_branch" {
  type        = string
  description = "Git branch Flux should reconcile."
  default     = "main"
}

variable "flux_kustomization_path" {
  type        = string
  description = "Path within the Git repository that contains the manifests Flux should apply."
  default     = "./gitops/clusters/kind-sops-demo"
}

variable "flux_reconcile_interval" {
  type        = string
  description = "How often Flux should reconcile sources and kustomizations."
  default     = "1m0s"
}

variable "flux_sops_secret_name" {
  type        = string
  description = "Name of the Kubernetes secret that stores the Flux SOPS GPG key."
  default     = "sops-gpg"
}
