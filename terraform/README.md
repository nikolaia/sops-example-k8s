# Tofu Notes

Follow the root `README.md` for the exact bootstrap sequence. This directory keeps the OpenTofu configuration (the folder name stays `terraform/` for compatibility); all required commands and environment variables are described at the repo root.

Key files:

- `main.tf` – Flux provider bootstrap, SOPS key material wiring (from `keys/flux-gpg-private.asc`), GitHub PAT loading.
- `keys/flux-gpg-private.asc` – SOPS-encrypted GPG private key; decrypted at apply time to create the `flux-system/sops-gpg` secret.
- `templates/flux-kustomization.yaml` – Patch injected into the Flux bootstrap kustomization to enable SOPS decryption.
- `secrets/github-pat.yaml` – SOPS-encrypted GitHub PAT (create from the example in the root README). The file is `.gitignore`d; keep it local.
