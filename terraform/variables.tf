variable "aws_region" {
  description = "AWS region for AI infrastructure deployment"
  type        = string
  default     = "eu-west-2"  # London - EU AI Act compliance region
}

variable "environment" {
  description = "Environment name (dev/staging/production)"
  type        = string
  default     = "demo"
  
  validation {
    condition     = contains(["dev", "staging", "production", "demo"], var.environment)
    error_message = "Environment must be dev, staging, production, or demo."
  }
}

variable "enable_gpu_nodes" {
  description = "Enable GPU node group (expensive - costs £379+/month)"
  type        = bool
  default     = false  # Disabled for cost-effective demo
}

variable "ml_team_budgets" {
  description = "Monthly budget limits per ML team in GBP"
  type        = map(number)
  default = {
    nlp_team      = 5000   # £5K for NLP team
    cv_team       = 8000   # £8K for computer vision (needs GPUs)
    platform_team = 3000   # £3K for platform team
  }
}

variable "model_registry_url" {
  description = "URL for MLflow or other model registry"
  type        = string
  default     = "mlflow.internal"
}

variable "gpu_instance_types" {
  description = "Allowed GPU instance types (require approval)"
  type        = list(string)
  default     = ["g4dn.xlarge", "g4dn.2xlarge", "p3.2xlarge"]
}

variable "compliance_frameworks" {
  description = "Active compliance frameworks"
  type        = list(string)
  default     = ["EU-AI-Act", "ISO-27001", "SOC2"]
}