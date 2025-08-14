# Cluster Access Outputs
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# AI Governance Outputs
output "ai_governance_status" {
  description = "AI Governance platform status"
  value = {
    cluster_name        = module.eks.cluster_name
    opa_enabled        = true
    sentinel_enabled   = true
    gpu_nodes_enabled  = var.enable_gpu_nodes
    model_registry     = var.model_registry_url
    compliance_scope   = join(", ", var.compliance_frameworks)
  }
}

output "cost_monitoring" {
  description = "Cost monitoring configuration"
  value = {
    hourly_cost     = "£0.08"  # 2x t3.medium
    monthly_estimate = "£58"
    gpu_capable     = var.enable_gpu_nodes
    gpu_cost_if_enabled = var.enable_gpu_nodes ? "£379/month per GPU" : "N/A"
  }
}

output "ml_platform_details" {
  description = "ML Platform infrastructure details"
  value = {
    vpc_id              = module.vpc.vpc_id
    node_groups         = keys(module.eks.eks_managed_node_groups)
    model_bucket        = aws_s3_bucket.model_artifacts.id
    kms_key_id          = aws_kms_key.eks.id
    cluster_version     = module.eks.cluster_version
  }
}

output "policy_enforcement" {
  description = "Policy enforcement endpoints"
  value = {
    sentinel_policies = [
      "gpu-instance-control",
      "ai-resource-tagging",
      "ai-spending-limits",
      "model-deployment-rules"
    ]
    opa_policies = [
      "ml-model-governance",
      "ml-registry-requirement"
    ]
  }
}

output "next_steps" {
  description = "Next steps for ML platform setup"
  value = <<-EOT
    1. Configure kubectl: ${module.eks.cluster_name}
    2. Install OPA Gatekeeper: kubectl apply -f opa-policies/
    3. Configure MLflow: helm install mlflow mlflow/mlflow
    4. Enable GPU nodes: terraform apply -var="enable_gpu_nodes=true" (costs £379+/month)
    5. Deploy sample model: kubectl apply -f test-deployments/valid-ml-deployment.yaml
  EOT
}