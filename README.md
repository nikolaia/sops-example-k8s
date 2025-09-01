# Live Demo Checklist

Everything below is required to get the SOPS + Flux + Terraform demo running on a fresh laptop.

## Prerequisites

- Kind with Docker running
- Terraform ≥ 1.5
- Flux CLI on your `$PATH`
- kubectl
- SOPS 3.10+
- GnuPG with access to the YubiKey that holds fingerprint `4E548DA00E9B10E5470AAA4CD9E872DE8210DCF7`

## 1. Prepare credentials

```bash
gpg --import terraform/keys/flux-gpg-public.asc
# Plug in the YubiKey that matches fingerprint 4E548DA00E9B10E5470AAA4CD9E872DE8210DCF7
gpg --card-status                     # optional sanity check
sops -d terraform/keys/flux-gpg-private.asc >/dev/null
sops -d terraform/secrets/flux-gpg-secret.yaml >/dev/null
```

Both `sops -d` commands must succeed; they confirm the YubiKey is reachable.

## 2. Build and load the app image

```bash
docker build -t sops-example-app:latest apps/sops-example-app
kind create cluster --name sops-demo
kind load docker-image sops-example-app:latest --name sops-demo
```

## 3. Point Flux at this repo

Terraform defaults `flux_git_repository_url` to `https://github.com/nikolaia/sops-example-k8s.git`. Override only if you are testing from a fork or a local mirror:

```bash
export TF_VAR_flux_git_repository_url="$(git config --get remote.origin.url)"
export TF_VAR_flux_git_branch="$(git rev-parse --abbrev-ref HEAD)"
```

## 4. Run Terraform

```bash
cd terraform
terraform init
terraform apply
```

Terraform will:

1. Install Flux into `flux-system`.
2. Decrypt the Flux SOPS GPG secret and apply it.
3. Create the Flux GitRepository + Kustomization targeting `gitops/clusters/kind-sops-demo`.

## 5. Verify

```bash
kubectl --context kind-sops-demo get pods -n flux-system
kubectl --context kind-sops-demo get kustomizations -A
kubectl --context kind-sops-demo get secrets my-secret -n default -o yaml
kubectl --context kind-sops-demo port-forward svc/sops-example-app 8080:80 &
curl http://localhost:8080/
```

You should see `Hello from SOPS example!` with the decrypted secret value.

## Cleanup

```bash
terraform destroy         # from the terraform/ directory
kind delete cluster --name sops-demo
```
