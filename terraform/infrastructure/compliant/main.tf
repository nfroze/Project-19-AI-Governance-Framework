# Compliant Infrastructure - Will PASS All Sentinel Policies
# This configuration follows all governance requirements

terraform {
  cloud {
    organization = "nfroze"
    
    workspaces {
      name = "Project-19-AI-Policy-as-Code"
    }
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

# ✅ COMPLIANT: Model from approved registry
resource "aws_sagemaker_model" "compliant_model" {
  name               = "recommendation-model-v2"
  execution_role_arn = aws_iam_role.sagemaker_role.arn

  primary_container {
    # Using model registry URL - COMPLIANT!
    model_data_url = "s3://sagemaker-eu-west-2-123456789012/model-registry/recommendation-model/v2/model.tar.gz"
    image          = "123456789012.dkr.ecr.eu-west-2.amazonaws.com/approved-inference:latest"
  }

  # VPC configuration for network isolation
  vpc_config {
    subnets            = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_group_ids = [aws_security_group.sagemaker_sg.id]
  }

  tags = {
    environment          = "production"
    team                = "ai-team"
    model-registry      = "sagemaker.amazonaws.com/model-registry"
    model-version       = "2.0.1"
    approved-by         = "ml-governance-team"
  }
}

# ✅ COMPLIANT: Proper data classification
resource "aws_s3_bucket" "training_data" {
  bucket = "ai-training-data-${random_string.suffix.result}"
  
  tags = {
    environment          = "production"
    purpose             = "ml-training"
    data-classification = "internal"              # ✅ Required tag
    data-owner          = "data-science-team"     # ✅ Required tag
    retention-policy    = "90-days"               # ✅ Required tag
    gdpr-compliant      = "true"
    purpose-of-processing = "product-recommendations"
    encryption          = "enabled"               # ✅ For policy check
  }
}

# ✅ COMPLIANT: S3 bucket with encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "training_data_encryption" {
  bucket = aws_s3_bucket.training_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.ml_key.arn
    }
  }
}

# ✅ COMPLIANT: Low-risk AI with proper documentation
resource "aws_sagemaker_endpoint" "recommendation_engine" {
  name                 = "product-recommendation-endpoint"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.config.name

  tags = {
    environment           = "production"
    ai-category          = "recommendation-system"     # Low risk
    ai-use-case          = "product-recommendations"
    
    # EU AI Act compliance (even for low-risk)
    "eu-ai-act-risk-assessment"    = "s3://compliance-docs/risk-assessment-rec-v2.pdf"
    "eu-ai-act-human-oversight-plan" = "s3://compliance-docs/human-oversight.pdf"
    "eu-ai-act-accuracy-metrics"    = "precision:0.92,recall:0.89"
    "eu-ai-act-bias-testing"        = "s3://compliance-docs/bias-test-results.json"
    "eu-ai-act-transparency-notice" = "s3://compliance-docs/ai-transparency.pdf"
    
    # Additional compliance
    human-oversight-type  = "human-on-the-loop"
    human-oversight-sla   = "4-hours"
    override-mechanism    = "enabled"
    ai-disclosure        = "enabled"
    explainability-method = "SHAP"
    contestation-mechanism = "enabled"
    bias-testing-date    = "2024-01-15"
    fairness-metrics     = "demographic-parity:0.95"
    demographic-parity   = "achieved"
    
    # CloudWatch logging
    cloudwatch-logs = "enabled"
  }
}

# ✅ COMPLIANT: Encrypted endpoint configuration
resource "aws_sagemaker_endpoint_configuration" "config" {
  name = "endpoint-config-secure"
  
  # KMS encryption
  kms_key_arn = aws_kms_key.ml_key.arn

  production_variants {
    variant_name           = "variant-1"
    model_name            = aws_sagemaker_model.compliant_model.name
    initial_instance_count = 1
    instance_type         = "ml.m5.xlarge"
  }
  
  tags = {
    environment = "production"
    encryption  = "kms"
    network     = "private"
  }
}

# ✅ COMPLIANT: GPU instance with proper security
resource "aws_instance" "gpu_training" {
  ami           = "ami-nvidia-deep-learning-base"  # Approved AMI
  instance_type = "g4dn.xlarge"
  
  # No public IP - COMPLIANT
  associate_public_ip_address = false
  
  # VPC configuration
  subnet_id              = aws_subnet.private_1.id
  vpc_security_group_ids = [aws_security_group.gpu_sg.id]
  
  # IMDSv2 required - COMPLIANT
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  
  # Encrypted root volume
  root_block_device {
    encrypted = true
    kms_key_id = aws_kms_key.ml_key.arn
  }
  
  tags = {
    Name             = "gpu-training-instance"
    environment      = "production"
    gpu-monitoring   = "enabled"        # ✅ Required for GPU instances
    cloudwatch-logs  = "enabled"
    data-classification = "internal"
  }
}

# KMS key for encryption
resource "aws_kms_key" "ml_key" {
  description             = "KMS key for ML workloads"
  deletion_window_in_days = 10
  
  tags = {
    purpose = "ml-encryption"
  }
}

# VPC and networking resources
resource "aws_vpc" "ml_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "ml-vpc"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.ml_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-2a"
  
  tags = {
    Name = "ml-private-subnet-1"
    Type = "private"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.ml_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-2b"
  
  tags = {
    Name = "ml-private-subnet-2"
    Type = "private"
  }
}

# Security groups
resource "aws_security_group" "sagemaker_sg" {
  name        = "sagemaker-endpoint-sg"
  description = "Security group for SageMaker endpoints"
  vpc_id      = aws_vpc.ml_vpc.id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "sagemaker-sg"
  }
}

resource "aws_security_group" "gpu_sg" {
  name        = "gpu-instance-sg"
  description = "Security group for GPU instances"
  vpc_id      = aws_vpc.ml_vpc.id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "gpu-sg"
  }
}

# IAM role with proper naming
resource "aws_iam_role" "sagemaker_role" {
  name = "SageMakerMLOpsExecutionRole"  # Follows naming convention

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    purpose = "ml-operations"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}