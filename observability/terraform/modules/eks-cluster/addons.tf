# EKS add-ons — from retail-store-sample-app/terraform/addons.tf

module "eks_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = var.enable_adot ? {
    adot = {
      most_recent = true
    }
  } : {}

  enable_cert_manager = var.enable_ingress_nginx || var.enable_adot
  cert_manager = {
    most_recent = true
    namespace   = "cert-manager"
  }

  enable_ingress_nginx = var.enable_ingress_nginx
  ingress_nginx = {
    most_recent = true
    namespace   = "ingress-nginx"
    set = [
      {
        name  = "controller.service.type"
        value = "LoadBalancer"
      },
      {
        name  = "controller.service.externalTrafficPolicy"
        value = "Local"
      },
      {
        name  = "controller.resources.requests.cpu"
        value = "100m"
      },
      {
        name  = "controller.resources.requests.memory"
        value = "128Mi"
      },
      {
        name  = "controller.resources.limits.cpu"
        value = "200m"
      },
      {
        name  = "controller.resources.limits.memory"
        value = "256Mi"
      }
    ]
    set_sensitive = [
      {
        name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
        value = "internet-facing"
      },
      {
        name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
        value = "nlb"
      },
      {
        name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-nlb-target-type"
        value = "instance"
      },
      {
        name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-health-check-path"
        value = "/healthz"
      },
      {
        name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-health-check-port"
        value = "10254"
      },
      {
        name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-health-check-protocol"
        value = "HTTP"
      }
    ]
  }

  enable_kube_prometheus_stack = var.enable_kube_prometheus_stack
  kube_prometheus_stack = {
    most_recent      = true
    name             = var.kube_prometheus_release_name
    namespace        = var.monitoring_namespace
    create_namespace = true
    values           = var.enable_kube_prometheus_stack ? [file("${path.module}/helm-values/kube-prometheus-obs.yaml")] : []
  }

  depends_on = [module.eks]
}
