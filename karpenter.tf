module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "21.10.1"

  cluster_name                    = module.eks.cluster_name
  create_pod_identity_association = true

  # Create IAM role for nodes launched by Karpenter
  create_node_iam_role = true
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

resource "helm_release" "karpenter" {
  namespace  = "kube-system"
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.8.2"
  wait       = false

  values = [
    <<-EOT
    tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
        effect: NoSchedule
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    EOT
  ]

  depends_on = [module.karpenter]
}

resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = templatefile("${path.module}/karpenter-node-class.yaml", {
    node_iam_role_name = module.karpenter.node_iam_role_name
    cluster_name       = module.eks.cluster_name

    env = local.tags["env"]
    geo = local.tags["geo"]
  })

  depends_on = [helm_release.karpenter]
}


resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = file("${path.module}/karpenter-node-pool.yaml")

  depends_on = [kubectl_manifest.karpenter_node_class]
}