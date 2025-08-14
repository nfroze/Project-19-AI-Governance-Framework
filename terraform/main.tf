terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  # Cost allocation tags for AI workloads
  default_tags {
    tags = {
      ManagedBy       = "Terraform"
      Platform        = "AI-Governance"
      CostCenter      = "MLOps"
      ComplianceScope = "EU-AI-Act"
    }
  }
}

# VPC for AI/ML Infrastructure
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "ml-platform-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Enable VPC Flow Logs for AI workload monitoring
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  tags = {
    Environment     = var.environment
    Project         = "AI-Governance-Platform"
    Owner           = "MLOps-Team"
    ML-Team         = "platform"
    Model-Type      = "none"  # No models in demo infrastructure
    Purpose         = "ML-Infrastructure-Governance"
    GPU-Enabled     = "false"  # Would be true with GPU nodes
    Registry        = "mlflow.internal"  # Planned model registry
    "kubernetes.io/cluster/ai-governance-cluster" = "shared"
  }
}

# EKS Cluster for AI Workload Orchestration
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "ai-governance-cluster"
  cluster_version = "1.28"

  # Enable cluster encryption for model security
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Enable IRSA for AI service integrations
  enable_irsa = true

  # EKS Addons for ML workloads
  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["t3.medium"]  # Cost-effective for demo
    
    # Default labels for all nodes
    labels = {
      Environment    = var.environment
      ManagedBy      = "EKS"
      WorkloadType   = "ml-platform"
      GPUCapable     = "false"  # Would be true for GPU instances
    }
  }

  eks_managed_node_groups = {
    # CPU node group for platform services
    ml_platform = {
      name = "ml-platform-nodes"
      
      desired_size = 2
      min_size     = 1
      max_size     = 4
      
      instance_types = ["t3.medium"]  # £0.04/hour per instance
      capacity_type  = "ON_DEMAND"    # Spot for training, on-demand for inference
      
      labels = {
        NodeGroup      = "ml-platform"
        WorkloadType   = "platform-services"
        CostProfile    = "standard"
      }
      
      taints = []  # No taints for platform nodes
      
      tags = {
        Environment     = var.environment
        Project         = "AI-Governance-Platform"
        Owner           = "MLOps-Team"
        ML-Team         = "platform"
        Model-Type      = "none"
        NodeGroupType   = "cpu-standard"
        MaxPodsPerNode  = "110"
        CostPerHour     = "0.04"  # £0.04/hour per t3.medium
      }
    }
    
    # This would be the GPU node group in production
    # ml_gpu = {
    #   name = "ml-gpu-nodes"
    #   
    #   desired_size = 0  # Scale to zero when not in use
    #   min_size     = 0
    #   max_size     = 2
    #   
    #   instance_types = ["g4dn.xlarge"]  # £0.526/hour - T4 GPU
    #   capacity_type  = "SPOT"           # 70% cost savings
    #   
    #   labels = {
    #     NodeGroup      = "ml-gpu"
    #     WorkloadType   = "gpu-inference"
    #     CostProfile    = "expensive"
    #     GPUType        = "nvidia-t4"
    #   }
    #   
    #   taints = [
    #     {
    #       key    = "nvidia.com/gpu"
    #       value  = "true"
    #       effect = "NO_SCHEDULE"
    #     }
    #   ]
    #   
    #   tags = {
    #     NodeGroupType   = "gpu-enabled"
    #     GPUCount        = "1"
    #     CostPerHour     = "0.526"
    #     AutoScaling     = "enabled"
    #   }
    # }
  }

  # Cluster tags for AI governance
  tags = {
    Environment       = var.environment
    Project           = "AI-Governance-Platform"
    Owner             = "MLOps-Team"
    ML-Team           = "platform"
    Model-Type        = "none"
    ClusterType       = "ai-governance"
    MonitoringEnabled = "true"
    OPAEnabled        = "true"
    GitOpsEnabled     = "true"
    ComplianceScope   = "EU-AI-Act"
  }

  # Additional cluster security group rules for ML services
  node_security_group_additional_rules = {
    ingress_mlflow = {
      description = "MLflow model registry"
      protocol    = "tcp"
      from_port   = 5000
      to_port     = 5000
      type        = "ingress"
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
    ingress_tensorboard = {
      description = "TensorBoard monitoring"
      protocol    = "tcp"
      from_port   = 6006
      to_port     = 6006
      type        = "ingress"
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
  }
}

# KMS key for model encryption
resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key for ML Models"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Environment = var.environment
    Project     = "AI-Governance-Platform"
    Owner       = "MLOps-Team"
    ML-Team     = "platform"
    Model-Type  = "none"
    Purpose     = "model-encryption"
  }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/ai-governance-eks"
  target_key_id = aws_kms_key.eks.key_id
}

# S3 bucket for model artifacts (optional but impressive)
resource "aws_s3_bucket" "model_artifacts" {
  bucket = "ai-governance-model-artifacts-${data.aws_caller_identity.current.account_id}"

  tags = {
    Environment = var.environment
    Project     = "AI-Governance-Platform"
    Owner       = "MLOps-Team"
    ML-Team     = "platform"
    Model-Type  = "storage"
    Purpose     = "model-versioning"
  }
}

resource "aws_s3_bucket_versioning" "model_artifacts" {
  bucket = aws_s3_bucket.model_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "model_artifacts" {
  bucket = aws_s3_bucket.model_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.eks.arn
    }
  }
}

# Data source for AWS account ID
data "aws_caller_identity" "current" {}
