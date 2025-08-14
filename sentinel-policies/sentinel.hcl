# AI Governance Policy Set for Infrastructure
# Enforces GPU controls, ML resource tracking, and AI spending limits

policy "gpu-instance-control" {
  source            = "./gpu-instance-control.sentinel"
  enforcement_level = "hard-mandatory"
}

policy "ai-resource-tagging" {
  source            = "./ai-resource-tagging.sentinel"
  enforcement_level = "hard-mandatory"
}

policy "ai-spending-limits" {
  source            = "./ai-spending-limits.sentinel"
  enforcement_level = "soft-mandatory"
}

policy "model-deployment-rules" {
  source            = "./model-deployment-rules.sentinel"
  enforcement_level = "advisory"
}