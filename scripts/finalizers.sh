#!/usr/bin/env bash

set -euo pipefail

ns="${1:-flux-system}"
git_repo="${2:-flux-system}"
kustomization="${3:-flux-system}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required on PATH" >&2
  exit 1
fi

echo "Checking Flux resources in namespace '${ns}'..."

if kubectl get gitrepositories.source.toolkit.fluxcd.io "${git_repo}" -n "${ns}" >/dev/null 2>&1; then
  echo "Patching GitRepository ${ns}/${git_repo}"
  kubectl patch gitrepositories.source.toolkit.fluxcd.io "${git_repo}" -n "${ns}" \
    --type=json \
    -p='[{"op":"remove","path":"/metadata/finalizers"}]'
else
  echo "GitRepository ${ns}/${git_repo} not found, skipping"
fi

if kubectl get kustomizations.kustomize.toolkit.fluxcd.io "${kustomization}" -n "${ns}" >/dev/null 2>&1; then
  echo "Patching Kustomization ${ns}/${kustomization}"
  kubectl patch kustomizations.kustomize.toolkit.fluxcd.io "${kustomization}" -n "${ns}" \
    --type=json \
    -p='[{"op":"remove","path":"/metadata/finalizers"}]'
else
  echo "Kustomization ${ns}/${kustomization} not found, skipping"
fi

echo "Finalizer cleanup complete."
