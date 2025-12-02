module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.10.1"

  name               = "${locals.name}-eks-cluster"
  kubernetes_version = "1.34"

  #Cluster networking settings
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Add the cluster creator as an administrator
  enable_cluster_creator_admin_permissions = true

  # Cluster endpoint access
  endpoint_public_access       = true
  endpoint_public_access_cidrs = ["89.205.56.57/32"]


  # EKS Managed Node Group(s) - Only for Karpenter and critical add-ons
  eks_managed_node_groups = {
    default = {
      ami_type       = "BOTTLEROCKET_x86_64"
      instance_types = ["m7i.xlarge", "m7i.2xlarge", "m7i.4xlarge", "c7i.xlarge", "c7i.2xlarge", "c7i.4xlarge"]
      min_size       = 2
      max_size       = 3
      desired_size   = 2

      create_iam_role = true
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      # Taints to ensure only critical workloads run here
      taints = {
        critical_addons_only = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      # Tags for EC2 instances launched by this node group
      tags = local.tags
    }
  }

  # Tags for EKS cluster and resources
  tags = local.tags

  #Critical Add-ons installation
  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  # Tag node security group for Karpenter discovery
  node_security_group_tags = {
    "karpenter.sh/discovery" = "${local.name}-eks-cluster"
  }
}
