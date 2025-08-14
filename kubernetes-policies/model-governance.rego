# ML Model Governance Policy
# Enforces model deployment standards for Kubernetes
# Ensures only approved, versioned models from registry

package kubernetes.admission

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Deny deployments without model registry reference
deny[msg] {
    input.request.kind.kind == "Deployment"
    input.request.object.metadata.labels["app-type"] == "ml-model"
    
    # Check if model source is specified
    not input.request.object.metadata.annotations["model-registry-url"]
    
    msg := "ML model deployments must reference a model from the approved registry (MLflow/SageMaker)"
}

# Deny models without version tags
deny[msg] {
    input.request.kind.kind == "Deployment"
    input.request.object.metadata.labels["app-type"] == "ml-model"
    
    # Check for model version
    not input.request.object.metadata.labels["model-version"]
    
    msg := "ML models must have a model-version label"
}

# Deny unapproved model sources
deny[msg] {
    input.request.kind.kind == "Deployment"
    input.request.object.metadata.labels["app-type"] == "ml-model"
    
    model_url := input.request.object.metadata.annotations["model-registry-url"]
    
    # Check if URL is from approved registries
    not is_approved_registry(model_url)
    
    msg := sprintf("Model source '%v' is not from an approved registry. Use MLflow, SageMaker Model Registry, or Azure ML", [model_url])
}

# Deny production deployments without approval
deny[msg] {
    input.request.kind.kind == "Deployment"
    input.request.namespace == "production"
    input.request.object.metadata.labels["app-type"] == "ml-model"
    
    # Check for approval annotation
    not input.request.object.metadata.annotations["approved-by"]
    
    msg := "Production ML model deployments require 'approved-by' annotation"
}

# Deny models without required governance labels
deny[msg] {
    input.request.kind.kind == "Deployment"
    input.request.object.metadata.labels["app-type"] == "ml-model"
    
    required_labels := ["model-name", "model-version", "model-framework", "team"]
    missing_labels := [label | 
        label := required_labels[_]
        not input.request.object.metadata.labels[label]
    ]
    
    count(missing_labels) > 0
    
    msg := sprintf("ML model deployment missing required labels: %v", [missing_labels])
}

# Deny models without monitoring configuration
deny[msg] {
    input.request.kind.kind == "Deployment"
    input.request.object.metadata.labels["app-type"] == "ml-model"
    
    # Check for monitoring annotations
    not input.request.object.metadata.annotations["prometheus.io/scrape"]
    
    msg := "ML models must have Prometheus monitoring enabled (prometheus.io/scrape: 'true')"
}

# Deny high-risk models without additional checks
deny[msg] {
    input.request.kind.kind == "Deployment"
    input.request.object.metadata.labels["ai-risk-level"] == "high"
    
    # High-risk models need human oversight annotation
    not input.request.object.metadata.annotations["human-oversight-enabled"]
    
    msg := "High-risk AI models require human-oversight-enabled annotation"
}

# Helper function to check approved registries
is_approved_registry(url) {
    contains(url, "mlflow")
}

is_approved_registry(url) {
    contains(url, "sagemaker")
}

is_approved_registry(url) {
    contains(url, "azureml")
}

is_approved_registry(url) {
    contains(url, "vertex-ai")
}

# Warn about models nearing expiration (soft policy)
warn[msg] {
    input.request.kind.kind == "Deployment"
    input.request.object.metadata.labels["app-type"] == "ml-model"
    
    # Check model training date
    training_date := input.request.object.metadata.annotations["model-training-date"]
    
    # This is a simplified check - in production, you'd calculate actual date difference
    contains(training_date, "2023")
    
    msg := sprintf("Warning: Model was trained in %v and may need retraining", [training_date])
}