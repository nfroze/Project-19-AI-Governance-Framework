# Sentinel Configuration - AI Governance Framework

policy "model-registry-required" {
  source            = "./model-registry.sentinel"
  enforcement_level = "hard-mandatory"
}

policy "data-classification-required" {
  source            = "./data-classification.sentinel"
  enforcement_level = "hard-mandatory"
}

policy "eu-ai-act-compliance" {
  source            = "./eu-ai-compliance.sentinel"
  enforcement_level = "hard-mandatory"
}

policy "ai-security-baseline" {
  source            = "./security-baseline.sentinel"
  enforcement_level = "hard-mandatory"
}