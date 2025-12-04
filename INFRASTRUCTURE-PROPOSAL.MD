## Architecture Summary

The Innovate Inc. application is deployed on Amazon EKS in multiple AWS accounts, with the following key components:

    CloudFront + WAF as the public edge, protecting all traffic
    
    ALB in public subnet, but restricted to CloudFront-only access
    
    EKS in private subnets, scaled dynamically with Karpenter
    
    Aurora PostgreSQL for Production
    
    RDS PostgreSQL for Dev/Test/Staging
    
    GitOps-driven deployments via ArgoCD
    
    CI with GitHub Actions, Trivy vulnerability scanning, and ECR push


![Architecture Diagram](./images/prod_architecture.png)



## Cloud Environment Structure

The infrastructure uses a multi-account strategy aligned with AWS best practices:

## Mandatory AWS Accounts
| Account                   | Purpose                                                                    | Access                             |
| ------------------------- | -------------------------------------------------------------------------- | ---------------------------------- |
| Management / Security     | Centralized IAM Identity Center, GuardDuty, CloudTrail, Security Hub, SCPs | Admin only                         |
| Shared Services           | Central ECR, shared networking or global services                          | Ops/Admin                          |
| Development               | Dev EKS cluster, RDS DB, ArgoCD for Dev                                    | Developers: Read/Write             |
| Production                | Production EKS cluster, Aurora PostgreSQL, ArgoCD for Prod                 | Developers: Read-Only, Ops limited |

## Optional AWS Accounts
| Account | Purpose                                     | Access                 |
| ------- | ------------------------------------------- | ---------------------- |
| Test    | QA/Functional Testing with EKS + RDS        | Developers: Read-Only  |
| Staging | Pre-production environment, production-like | Developers: Read-Only  |
| UAT     | User Acceptance Testing                     | Business/Test teams    |
| Sandbox | Experimentation environment                 | Developers: Read/Write |
| DR      | Disaster Recovery (cross-region standby)    | Ops only               |

Enfore tagging on all resources with SCP policies. 

![AWS accounts diagram](./images/aws_accounts.png)



## Network Design

Each environment has a dedicated VPC with:
    3 Availability Zones
    9 subnets: Public, Private, Restricted
    VPC Endpoints: ECR, CloudWatch
    NAT Gateways for private subnet outbound access
    VPC Flow Logs centralized to Security account to CloudWatch Logs
    Network ACLs (NACLs): Applied to all subnets to provide an additional layer of subnet-level security
    Security groups: Used at instance/pod level for fine-grained access control
    CloudFront + WAF: Fronts all public traffic, restricting access to the ALB
    ALB: Placed in public subnets but only accessible via CloudFront



## EKS

Each AWS account has an EKS cluster in private subnets. 
Managed Node Group: Runs Istio control plane, ArgoCD, Karpenter controller, core system pods, add-ons
Karpenter: Autoscaling based on pod resource requests, Spot + On-Demand mix


## CI/CD Workflow

    1. Checkout code
    2. Trivy vulnerability scan
    3. Build Docker images
    4. Push to Shared Services ECR
    5. Update relevant GitOps repo
    6. Dev environment automatically deploys
    7. Test/Staging/Prod require manual approval


## Database Architecture
| Environment      | DB Type           | HA                                    | 
| ---------------- | ----------------- | --------------------------------------|
| Production       | Aurora PostgreSQL | Multi-AZ, Aurora replicas             |
| Dev/Test/Staging | RDS PostgreSQL    | Multi-AZ (Test/Staging), Single-AZ Dev|

### Backups
Aurora: Continuous backups, Point-in-time restore, cross-account snapshots
RDS: Automated backups (7–14 days), manual snapshots

### High Availability
Aurora: Multi-AZ, sub-30s failover, distributed storage
RDS: Multi-AZ in Test/Staging, single-AZ Dev



## Disaster Recovery

### Aurora 
    Cross-region read replica in DR region. 
    Global Database option for near-zero RPO. 
    Cross-account, encrypted snapshots for recovery.
### EKS
    Cluster state backed by GitOps (ArgoCD manifests). 
    DR cluster in separate region/account can restore workloads and config quickly
### Infrastructure

    Deploy infrastructure on DR scenario/Have it already deployed in standby
