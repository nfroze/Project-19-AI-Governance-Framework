# AI Governance Policy Set for Infrastructure
# Enforces GPU controls, ML resource tracking, and AI spending limits

policy "gpu-instance-control" {
  source            = "./gpu-instance-control.sentinel"
  enforcement_level = "hard-mandatory"
  description       = "Prevent unauthorised GPU instance provisioning to avoid £10K+ monthly overruns"
}

policy "ai-resource-tagging" {
  source            = "./ai-resource-tagging.sentinel"
  enforcement_level = "hard-mandatory"
  description       = "Enforce ML resource tagging for cost attribution and experiment tracking"
}

policy "ai-spending-limits" {
  source            = "./ai-spending-limits.sentinel"
  enforcement_level = "soft-mandatory"
  description       = "Control AI/ML infrastructure spending with budget limits"
}

policy "model-deployment-rules" {
  source            = "./model-deployment-rules.sentinel"
  enforcement_level = "advisory"
  description       = "Ensure ML models follow deployment best practices"
}