# Live Demo Checklist

Everything below is required to get the SOPS + Flux + OpenTofu demo running on a fresh laptop.

## Prerequisites

- Kind with Docker running
- OpenTofu (`tofu` CLI) ≥ 1.6
- kubectl
- SOPS 3.10+
- GnuPG with access to the YubiKey that holds fingerprint `4E548DA00E9B10E5470AAA4CD9E872DE8210DCF7`
- Git credentials with push access to `github.com/nikolaia/sops-example-k8s`

## 1. Prepare credentials

```bash
gpg --import terraform/keys/flux-gpg-public.asc
# Plug in the YubiKey that matches fingerprint 4E548DA00E9B10E5470AAA4CD9E872DE8210DCF7
gpg --card-status                     # optional sanity check
sops -d terraform/keys/flux-gpg-private.asc >/dev/null
```

The `sops -d` command must succeed; it confirms the YubiKey is reachable.

## 2. Build and load the app image

```bash
docker build -t sops-example-app:latest apps/sops-example-app
kind create cluster --name sops-demo
kind load docker-image sops-example-app:latest --name sops-demo
```

## 3. Provide a SOPS-encrypted GitHub PAT

Flux must push commits to `github.com/nikolaia/sops-example-k8s.git`. Copy `terraform/secrets/github-pat.yaml.example` to `terraform/secrets/github-pat.yaml`, fill in your GitHub username + classic PAT (scope: `repo`), and encrypt it with SOPS:

```bash
cat <<'EOF' > terraform/secrets/github-pat.yaml
apiVersion: v1
kind: Secret
metadata:
  name: github-pat
  namespace: flux-system
stringData:
  username: your-github-username
  token: ghp_your_pat_here
EOF

sops --encrypt --in-place terraform/secrets/github-pat.yaml
```

> `terraform/secrets/github-pat.yaml` is git-ignored on purpose—keep the encrypted secret local to avoid “harvest now, decrypt later” attacks against this public repo. Delete any plaintext copy once it is safely encrypted.

Flux bootstrapping commits manifests under `gitops/clusters/kind-sops-demo`. After `tofu apply`, review and push the generated commit.

## 4. Run OpenTofu

```bash
cd terraform
tofu init
tofu apply
```

> The first `tofu init` requires internet access to download the Flux provider.

OpenTofu will:

1. Create the `flux-system` namespace and install Flux controllers (via the Flux provider).
2. Decrypt the Flux GPG private key and create the `flux-system/sops-gpg` secret through the Kubernetes provider.
3. Commit Flux bootstrap manifests to the Git repository targeting `gitops/clusters/kind-sops-demo` with SOPS decryption enabled.

## 5. Verify

```bash
kubectl --context kind-sops-demo get pods -n flux-system
kubectl --context kind-sops-demo get kustomizations -A
kubectl --context kind-sops-demo get secrets my-secret -n default -o yaml
```

Once the app pod is ready, port-forward its service to expose the decrypted secret on your laptop:

```bash
kubectl --context kind-sops-demo port-forward svc/sops-example-app 8080:80 &
curl http://localhost:8080/
```

You should see `Hello from SOPS example!` with the decrypted secret value.

## Cleanup

```bash
tofu destroy         # from the terraform/ directory
kind delete cluster --name sops-demo
```
