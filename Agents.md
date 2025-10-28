# Agent Handbook

This repository powers a conference demo showing how SOPS-encrypted secrets flow through FluxCD and OpenTofu on a local Kind cluster. Use this file to understand the moving pieces before making changes.

## Current Architecture

- `apps/sops-example-app/` – Simple Node.js service (`app.js`, `Dockerfile`, `package.json`) that prints the decrypted secret.
- `gitops/apps/sops-example-app/` – Kustomize bundle (`deployment.yaml`, `service.yaml`, `secret.yaml`, `kustomization.yaml`). `secret.yaml` is SOPS-encrypted for the Flux key only.
- `gitops/clusters/kind-sops-demo/` – Cluster composition. The top-level kustomization references the `flux-system/` subfolder which in turn installs the Flux-managed `Kustomization` for the app.
- `terraform/` – OpenTofu configuration (folder name kept for familiarity). It installs Flux via the Flux provider, decrypts the SOPS GPG private key into `flux-system/sops-gpg`, loads a GitHub PAT from SOPS, and bootstraps the cluster against this Git repo (`https://github.com/nikolaia/sops-example-k8s.git` by default).
- `.sops.yaml` – Routing rules: Flux private key files encrypt for the presenter's YubiKey; Flux secret manifests for both presenter + Flux; app secrets for Flux only.

## Demo Flow (see root `README.md` for exact commands)

1. Import the Flux public key and confirm YubiKey access; decrypt the stored private key once to verify.
2. Build the app image and load it into the Kind cluster (`kind load docker-image`).
3. Run `tofu init && tofu apply` inside `terraform/`. This:
   - Uses the Flux provider to install Flux controllers with embedded manifests.
   - Loads the GitHub PAT from `terraform/secrets/github-pat.yaml` (SOPS) for push access.
   - Commits bootstrap manifests (GitRepository + Kustomization) to `gitops/clusters/kind-sops-demo`.
   - Writes the decrypted Flux SOPS key to `flux-system/sops-gpg`.
4. Verify pods, kustomizations, and the decrypted secret via `kubectl`; port-forward the service for the HTTP demo.
5. Clean up with `tofu destroy` and `kind delete cluster --name sops-demo`.

## Key Material

- Flux public key: `terraform/keys/flux-gpg-public.asc` (plain text).
- Flux private key: `terraform/keys/flux-gpg-private.asc` (SOPS-encrypted, committed).
- Presenter YubiKey fingerprint: `4E548DA00E9B10E5470AAA4CD9E872DE8210DCF7`.
- Flux GPG fingerprint: `83E1F3DE6E8F9410481BB665D5CAC29219AA4A78`.

## Development Notes

- Use `tofu` instead of `terraform`; all docs assume OpenTofu 1.6+.
- Secrets must be re-keyed with `sops updatekeys` if fingerprints change.
- App manifests reside exclusively under `gitops/`; adjust Flux paths accordingly.
- The app image tag `sops-example-app:latest` is referenced by the deployment; keep it in sync with local builds.
- Flux provider requires the locally-encrypted PAT in `terraform/secrets/github-pat.yaml` (template: `github-pat.yaml.example`) to push bootstrap commits; the file is `.gitignore`d so nothing sensitive (even encrypted) lands in the public repo, reducing “harvest now, decrypt later” risk.

## Open Items & Ideas

- Add convenience scripts or a `Makefile` for one-command bootstrap/destroy.
- Decide whether to maintain an offline copy of the Flux private key outside the repo.
- Consider adding health checks/alerts or a second app to showcase broader GitOps scenarios.
- Optional validation steps (e.g., `tofu validate`, `flux check`) could be scripted to streamline rehearsals.

## Troubleshooting

- **Flux namespace stuck terminating** – When tearing down the cluster without Flux controllers running, `GitRepository` and `Kustomization` resources may keep `finalizers.fluxcd.io`, leaving the `flux-system` namespace in the `Terminating` phase. You can run `scripts/finalizers.sh` (defaults to the `flux-system` resources) or create a temporary `ServiceAccount` with `cluster-admin`, run a one-off job (e.g. `bitnami/kubectl:latest`) that executes  
  ```sh
  kubectl patch gitrepositories.source.toolkit.fluxcd.io flux-system -n flux-system --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]'
  kubectl patch kustomizations.kustomize.toolkit.fluxcd.io flux-system -n flux-system --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]'
  ```  
  and then delete the helper RBAC/job resources. Once both CRs disappear, the namespace finishes terminating.
