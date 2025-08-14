# Sentinel Configuration - AI Governance Framework
# This file defines all policies and their enforcement levels

# Policy 1: Model Registry Enforcement
policy "model-registry-required" {
  source            = "./model-registry.sentinel"
  enforcement_level = "hard-mandatory"
  
  params = {
    allowed_registries = [
      "mlflow.company.internal",
      "sagemaker.amazonaws.com/model-registry",
      "azureml.azure.com/models"
    ]
    environments_requiring_registry = ["production", "staging"]
  }
}

# Policy 2: Data Classification for AI Workloads
policy "data-classification-required" {
  source            = "./data-classification.sentinel"
  enforcement_level = "hard-mandatory"
  
  params = {
    required_tags = ["data-classification", "data-owner", "retention-policy"]
    valid_classifications = ["public", "internal", "confidential", "restricted"]
    pii_environments = ["production", "staging"]
  }
}

# Policy 3: EU AI Act Compliance
policy "eu-ai-act-compliance" {
  source            = "./eu-ai-compliance.sentinel"
  enforcement_level = "hard-mandatory"
  
  params = {
    high_risk_systems = [
      "biometric-identification",
      "critical-infrastructure", 
      "education-scoring",
      "employment-screening",
      "credit-scoring",
      "law-enforcement",
      "migration-control"
    ]
    required_documentation = [
      "risk-assessment",
      "human-oversight-plan",
      "accuracy-metrics",
      "bias-testing",
      "transparency-notice"
    ]
  }
}

# Policy 4: Security Baseline for AI Infrastructure
policy "ai-security-baseline" {
  source            = "./security-baseline.sentinel"
  enforcement_level = "hard-mandatory"
  
  params = {
    require_encryption = true
    require_private_endpoints = true
    require_vpc_isolation = true
    allowed_amis = [
      "ami-ml-base-*",
      "ami-nvidia-*", 
      "ami-deeplearning-*"
    ]
    require_imdsv2 = true
  }
}

# Module policy sets can be defined for different environments
module "production" {
  source = "./model-registry.sentinel"
  enforcement_level = "hard-mandatory"
}

module "development" {
  source = "./model-registry.sentinel"
  enforcement_level = "soft-mandatory"
}