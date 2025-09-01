# Repo Purpose & Implementation Plan

This repository demonstrates multiple workflows for handling encrypted configuration with Mozilla SOPS. It currently contains:

- `apps/sops-example-app/` – The Node.js demo application (Dockerfile, app, package.json).
- `gitops/apps/sops-example-app/` – Kubernetes manifests (secret/deployment/service) plus a kustomization Flux reconciles.
- `gitops/clusters/kind-sops-demo/` – Cluster composition that pulls in the app via Flux.
- `gitops/keys/public-key.asc` – Legacy SOPS public key for local experiments.
- `terraform/` – Infrastructure-as-code that bootstraps Flux, decrypts the Flux private key secret, and configures Git reconciliation.

The current vision is a turnkey local demo that highlights how Terraform, FluxCD, and SOPS cooperate to run an app whose secrets never live unencrypted on disk.

## Demo Vision

1. A local Kubernetes cluster (Kind by default) runs the sample application defined in `gitops/apps/sops-example-app/`.
2. FluxCD is installed to reconcile application manifests from this repository.
3. Terraform provisions Flux, primes it with a SOPS decryption key, and leaves Flux to manage the rest of the manifests.
4. All sensitive data—including the Flux GPG private key—is stored in-repo encrypted with SOPS, never in plain text.

## Planned Work Breakdown

### 1. Local Cluster & Terraform Bootstrap

- ✅ Terraform assumes a Kind context (configurable) and installs Flux via `flux install`.
- ✅ `flux-system` namespace and SOPS secret are provisioned from an encrypted manifest.
- ☐ Consider packaging optional targets (e.g., Makefile) for quick demo reset.

### 2. SOPS-Encrypted Flux Key Handling

- ✅ Flux key pair committed under `terraform/keys/`.
- ✅ Private key encrypted in-place with SOPS; secret manifest encrypted for Flux + operator.
- ✅ `.sops.yaml` routes:
  - Flux private key → presenter’s YubiKey fingerprint only.
  - Flux secret manifest → both presenter + Flux recipients.
  - App manifests (`gitops/apps/.../secret.yaml`) → Flux recipient only.
- ☐ Decide whether to keep a decrypted backup of the Flux private key outside the repo.

### 3. Flux Configuration

- ✅ Terraform can create GitRepository/Kustomization with SOPS decryption enabled.
- ✅ Defaults point Flux at `https://github.com/nikolaia/sops-example-k8s.git`.
- ☐ Consider Flux health checks or notifications for live UX.

### 4. Demo Documentation & Tooling

- ✅ Root `README.md` documents the bootstrap flow end-to-end.
- ☐ Prepare presenter notes (timings, commands, expected outputs) for the stage run.

### 5. Stretch Ideas (time permitting)

- Show how Flux could watch another Git branch to highlight GitOps flows.
- Add a second environment or namespace managed by Flux to demonstrate multi-environment secrets.
- Provide automated tests or checks (e.g., `terraform validate`, `flux --kubeconfig ...`) to verify everything before the talk.

## Open Questions

- Should the Flux GitRepository in Terraform default to this repo, or be left configurable only?
- Do we want scripted image build/push + Kind image load to ensure the deployment comes up live?
- Is there value in demonstrating Flux multi-recipient secrets (e.g., team vs. robot keys) within the demo?
