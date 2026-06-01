output "namespace" {
  description = "Namespace ArgoCD is installed into. Pass this to downstream resources that need to create things in the ArgoCD namespace (Applications, AppProjects, repository Secrets)."
  value       = helm_release.argocd.namespace
}

output "release_name" {
  description = "Helm release name. Useful for kubectl-scoped queries (e.g. `kubectl get pods -l app.kubernetes.io/instance=$(release_name)`)."
  value       = helm_release.argocd.name
}
