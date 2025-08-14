# Non-Compliant Infrastructure - Will FAIL Sentinel Policies
# This configuration deliberately violates policies for demonstration

terraform {
  cloud {
    organization = "your-org-name"  # Replace with your TF Cloud org
    
    workspaces {
      name = "ai-governance-demo"
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

# ❌ VIOLATION 1: Model deployment without registry
# This will trigger: model-registry-required policy
resource "aws_sagemaker_model" "non_compliant_model" {
  name               = "facial-recognition-model-v1"
  execution_role_arn = aws_iam_role.sagemaker_role.arn

  primary_container {
    # Direct S3 path instead of model registry - VIOLATION!
    model_data_url = "s3://my-bucket/models/model.tar.gz"
    image          = "123456789012.dkr.ecr.eu-west-2.amazonaws.com/my-model:latest"
  }

  tags = {
    environment = "production"  # Production requires registry
    team        = "ai-team"
  }
}

# ❌ VIOLATION 2: Missing data classification
# This will trigger: data-classification-required policy
resource "aws_s3_bucket" "training_data" {
  bucket = "ai-training-data-${random_string.suffix.result}"
  
  tags = {
    environment = "production"
    purpose     = "ml-training"
    # MISSING: data-classification, data-owner, retention-policy
  }
}

# ❌ VIOLATION 3: High-risk AI without EU AI Act compliance
# This will trigger: eu-ai-act-compliance policy
resource "aws_sagemaker_endpoint" "facial_recognition" {
  name                 = "facial-recognition-endpoint"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.config.name

  tags = {
    environment   = "production"
    ai-category   = "biometric-identification"  # HIGH RISK!
    ai-use-case   = "facial-recognition-public"
    # MISSING: EU AI Act documentation tags
    # MISSING: human-oversight-type
    # MISSING: bias-testing-date
  }
}

# ❌ VIOLATION 4: No encryption or VPC isolation
# This will trigger: security-baseline policy
resource "aws_sagemaker_endpoint_configuration" "config" {
  name = "endpoint-config-insecure"

  production_variants {
    variant_name           = "variant-1"
    model_name            = aws_sagemaker_model.non_compliant_model.name
    initial_instance_count = 1
    instance_type         = "ml.g4dn.xlarge"  # GPU instance
    
    # MISSING: No KMS encryption specified
  }
  
  # MISSING: No VPC configuration
  
  tags = {
    environment = "production"
  }
}

# ❌ VIOLATION 5: S3 bucket without encryption
# This will trigger: security-baseline policy
resource "aws_s3_bucket" "model_artifacts" {
  bucket = "model-artifacts-${random_string.suffix.result}"
  
  # MISSING: server_side_encryption_configuration
  
  tags = {
    environment = "production"
    purpose     = "model-storage"
  }
}

# ❌ VIOLATION 6: GPU instance with public IP
# This will trigger: security-baseline policy
resource "aws_instance" "gpu_training" {
  ami           = "ami-12345678"  # Not from approved list!
  instance_type = "g4dn.xlarge"   # GPU instance
  
  # VIOLATION: Public IP assigned
  associate_public_ip_address = true
  
  # MISSING: metadata_options for IMDSv2
  
  tags = {
    Name        = "gpu-training-instance"
    environment = "production"
    # MISSING: gpu-monitoring tag
  }
}

# Supporting resources
resource "aws_iam_role" "sagemaker_role" {
  name = "sagemaker-execution-role"

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
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}