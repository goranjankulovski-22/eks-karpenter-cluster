# EKS Cluster with Karpenter Autoscaling

This Terraform repository deploys an AWS EKS cluster with Karpenter for intelligent, cost-optimized node autoscaling.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                           VPC                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │ AZ-a        │  │ AZ-b        │  │ AZ-c        │              │
│  │ Private     │  │ Private     │  │ Private     │              │
│  │ Subnet      │  │ Subnet      │  │ Subnet      │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
│         │               │               │                       │
│         └───────────────┼───────────────┘                       │
│                         │                                       │
│              ┌──────────┴──────────┐                            │
│              │    EKS Cluster      │                            │
│              └──────────┬──────────┘                            │
│                         │                                       │
│    ┌────────────────────┼────────────────────┐                  │
│    │                    │                    │                  │
│    ▼                    ▼                    ▼                  │
│ ┌──────────┐    ┌──────────────┐    ┌──────────────┐            │
│ │ Managed  │    │  Karpenter   │    │  Karpenter   │            │
│ │ Node     │    │  Nodes       │    │  Nodes       │            │
│ │ Group    │    │  (Spot)      │    │  (Graviton)  │            │
│ │          │    │              │    │              │            │
│ │ Critical │    │  Workloads   │    │  Workloads   │            │
│ │ Add-ons  │    │              │    │              │            │
│ └──────────┘    └──────────────┘    └──────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

## Features

- **EKS Cluster** with Kubernetes 1.34
- **Managed Node Group** for critical add-ons (Karpenter, CoreDNS, kube-proxy, vpc-cni)
- **Karpenter** for intelligent autoscaling with:
  - Graviton (ARM64) support for ~20% cost savings
  - Spot instances for up to 90% cost savings
  - Automatic node consolidation
- **VPC** with public/private subnets across 3 AZs

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- [kubectl](https://kubernetes.io/docs/tasks/tools/) for cluster access

## Quick Start

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Review the Plan

```bash
terraform plan
```

### 3. Deploy the Cluster

```bash
terraform apply
```

This will take approximately 15-20 minutes.

### 4. Configure kubectl

```bash
aws eks update-kubeconfig --region eu-west-2 --name test01-eks-cluster
```

### 5. Verify the Cluster

```bash
# Check nodes
kubectl get nodes

# Check Karpenter is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter

# Check NodePool and EC2NodeClass
kubectl get nodepools
kubectl get ec2nodeclasses
```

## Deploying Workloads

Karpenter automatically provisions the right nodes based on your pod requirements. Use node selectors to control instance type selection.

### Example: Graviton + Spot Deployment (Maximum Savings)

Deploy using the example in the `applications/` folder:

```bash
kubectl apply -f applications/karpenter-workload-example.yaml
```

This deploys an nginx application on **Graviton (ARM64) Spot instances** for maximum cost savings:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-graviton-spot
  namespace: default
spec:
  replicas: 5
  selector:
    matchLabels:
      app: my-app-graviton-spot
  template:
    metadata:
      labels:
        app: my-app-graviton-spot
    spec:
      nodeSelector:
        kubernetes.io/arch: arm64           
        karpenter.sh/capacity-type: spot    
      containers:
        - name: app
          image: nginx:latest  
          resources:
            requests:
              cpu: "500m"
              memory: "512Mi"
            limits:
              cpu: "1"
              memory: "1Gi"
      terminationGracePeriodSeconds: 30
```

**Key node selectors:**
- `kubernetes.io/arch: arm64` - Forces Graviton instances (~20% cheaper)
- `karpenter.sh/capacity-type: spot` - Uses Spot pricing (up to 90% cheaper)

## Node Selector Reference

| Selector | Values | Use Case |
|----------|--------|----------|
| `kubernetes.io/arch` | `amd64`, `arm64` | Choose x86 or Graviton |
| `karpenter.sh/capacity-type` | `spot`, `on-demand` | Choose pricing model |
| `karpenter.k8s.aws/instance-size` | `medium`, `large`, `xlarge`, `2xlarge` | Choose instance size |
| `karpenter.k8s.aws/instance-category` | `c`, `m`, `r`, `t` | Choose instance family |


## Cost Optimization Tips

1. **Use Graviton (ARM64)** - ~20% cheaper than x86, most container images support it
2. **Use Spot instances** - Up to 90% cheaper, great for stateless workloads
3. **Set appropriate resource requests** - Karpenter bins pods efficiently
4. **Enable consolidation** - Already configured to consolidate underutilized nodes


## Files Structure

```
.
├── README.md                 # This file
├── providers.tf              # AWS, Helm, kubectl providers
├── locals.tf                 # Local variables and tags
├── vpc.tf                    # VPC with public/private subnets
├── eks.tf                    # EKS cluster and managed node group
├── karpenter.tf              # Karpenter module, Helm release, manifests
├── karpenter-node-class.yaml # EC2NodeClass configuration
├── karpenter-node-pool.yaml  # NodePool configuration
└── applications/
    └── karpenter-workload-example.yaml  # Example deployment
```
