# ArgoCD — from retail-store-sample-app/terraform/argocd.tf (optional, workload cluster)

resource "time_sleep" "wait_for_cluster" {
  count = var.enable_argocd ? 1 : 0

  create_duration = "30s"
  depends_on = [
    module.eks,
    module.eks_addons,
  ]
}

resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name             = "argocd"
  namespace        = var.argocd_namespace
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  values = [
    yamlencode({
      server = {
        service   = { type = "ClusterIP" }
        ingress   = { enabled = false }
        extraArgs = ["--insecure"]
      }
      controller = {
        resources = {
          requests = { cpu = "100m", memory = "128Mi" }
          limits   = { cpu = "500m", memory = "512Mi" }
        }
      }
      repoServer = {
        resources = {
          requests = { cpu = "50m", memory = "64Mi" }
          limits   = { cpu = "200m", memory = "256Mi" }
        }
      }
      redis = {
        resources = {
          requests = { cpu = "50m", memory = "64Mi" }
          limits   = { cpu = "200m", memory = "128Mi" }
        }
      }
    })
  ]

  depends_on = [time_sleep.wait_for_cluster]
}

resource "kubectl_manifest" "argocd_projects" {
  for_each = var.enable_argocd ? fileset("${var.argocd_root_path}/projects", "*.yaml") : toset([])

  yaml_body  = file("${var.argocd_root_path}/projects/${each.value}")
  depends_on = [helm_release.argocd]
}

resource "kubectl_manifest" "argocd_apps" {
  for_each = var.enable_argocd ? fileset("${var.argocd_root_path}/applications", "*.yaml") : toset([])

  yaml_body  = file("${var.argocd_root_path}/applications/${each.value}")
  depends_on = [kubectl_manifest.argocd_projects]
}
