# Data Protection Policy
# Enforces GDPR compliance and PII handling requirements
# Ensures proper data classification and encryption

package kubernetes.admission

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Data classification levels
valid_classifications := ["public", "internal", "confidential", "restricted"]

# Deny workloads without data classification
deny[msg] {
    input.request.kind.kind in ["Deployment", "StatefulSet", "Job"]
    
    # Check if workload handles data
    labels := input.request.object.metadata.labels
    labels["app-type"] in ["ml-training", "ml-inference", "data-processing", "ml-model"]
    
    # Check for data classification
    not labels["data-classification"]
    
    msg := "Data processing workloads must have 'data-classification' label"
}

# Deny invalid data classification
deny[msg] {
    input.request.kind.kind in ["Deployment", "StatefulSet", "Job"]
    
    classification := input.request.object.metadata.labels["data-classification"]
    not classification in valid_classifications
    
    msg := sprintf("Invalid data classification '%v'. Must be one of: %v", [classification, valid_classifications])
}

# Deny PII processing without encryption
deny[msg] {
    input.request.kind.kind in ["Deployment", "StatefulSet"]
    
    # Check if handling PII
    labels := input.request.object.metadata.labels
    labels["data-classification"] in ["confidential", "restricted"]
    
    # Check for encryption in volumes
    volume := input.request.object.spec.volumes[_]
    volume.persistentVolumeClaim
    
    # Check if PVC has encryption annotation
    annotations := input.request.object.metadata.annotations
    not annotations["storage-encryption-enabled"]
    
    msg := "PII data (confidential/restricted) requires encrypted storage volumes"
}

# Deny PII processing without GDPR compliance annotations
deny[msg] {
    input.request.kind.kind in ["Deployment", "StatefulSet", "Job"]
    
    labels := input.request.object.metadata.labels
    labels["data-classification"] in ["confidential", "restricted"]
    
    annotations := input.request.object.metadata.annotations
    
    # Check GDPR requirements
    required_gdpr := ["gdpr-compliant", "data-retention-days", "purpose-of-processing", "lawful-basis"]
    missing_gdpr := [field | 
        field := required_gdpr[_]
        not annotations[field]
    ]
    
    count(missing_gdpr) > 0
    
    msg := sprintf("PII processing requires GDPR annotations: %v", [missing_gdpr])
}

# Deny training jobs without data source documentation
deny[msg] {
    input.request.kind.kind == "Job"
    input.request.object.metadata.labels["job-type"] == "model-training"
    
    # Check for data source documentation
    annotations := input.request.object.metadata.annotations
    not annotations["training-data-source"]
    
    msg := "ML training jobs must document data source in 'training-data-source' annotation"
}

# Deny external data access without approval
deny[msg] {
    input.request.kind.kind in ["Deployment", "Job"]
    
    # Check if accessing external data
    container := input.request.object.spec.containers[_]
    env := container.env[_]
    env.name in ["S3_BUCKET", "AZURE_STORAGE", "GCS_BUCKET", "EXTERNAL_API"]
    
    # Check for approval
    annotations := input.request.object.metadata.annotations
    not annotations["external-data-approved-by"]
    
    msg := "External data access requires 'external-data-approved-by' annotation"
}

# Deny production PII without data protection officer approval
deny[msg] {
    input.request.namespace == "production"
    input.request.kind.kind in ["Deployment", "StatefulSet"]
    
    labels := input.request.object.metadata.labels
    labels["data-classification"] == "restricted"
    
    annotations := input.request.object.metadata.annotations
    not annotations["dpo-approved"]
    
    msg := "Production deployments with restricted data require DPO approval"
}

# Deny data exports without audit logging
deny[msg] {
    input.request.kind.kind in ["Job", "CronJob"]
    
    labels := input.request.object.metadata.labels
    labels["job-type"] in ["data-export", "data-migration"]
    
    # Check for audit logging
    annotations := input.request.object.metadata.annotations
    not annotations["audit-logging-enabled"]
    
    msg := "Data export jobs must have audit logging enabled"
}

# Require data anonymization for non-production
deny[msg] {
    input.request.namespace in ["development", "staging"]
    input.request.kind.kind in ["Deployment", "StatefulSet", "Job"]
    
    labels := input.request.object.metadata.labels
    labels["data-classification"] in ["confidential", "restricted"]
    
    annotations := input.request.object.metadata.annotations
    not annotations["data-anonymized"]
    
    msg := "Non-production environments must use anonymized data for confidential/restricted classifications"
}

# Deny cross-region data transfer without compliance check
deny[msg] {
    input.request.kind.kind in ["Deployment", "Job"]
    
    annotations := input.request.object.metadata.annotations
    annotations["data-region-source"]
    annotations["data-region-target"]
    
    source := annotations["data-region-source"]
    target := annotations["data-region-target"]
    
    source != target
    not annotations["cross-region-transfer-approved"]
    
    msg := sprintf("Cross-region data transfer from %v to %v requires approval", [source, target])
}

# Warn about retention policy nearing expiration
warn[msg] {
    input.request.kind.kind in ["Deployment", "StatefulSet"]
    
    annotations := input.request.object.metadata.annotations
    retention_days := annotations["data-retention-days"]
    
    # Simplified check - in production would calculate actual dates
    to_number(retention_days) > 365
    
    msg := sprintf("Data retention period of %v days exceeds recommended maximum", [retention_days])
}