# Namespace Isolation Policy
# Enforces team boundaries and multi-tenancy rules
# Prevents cross-namespace access and resource conflicts

package kubernetes.admission

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Define namespace ownership
namespace_teams := {
    "ml-training": "data-science-team",
    "ml-research": "research-team",
    "ml-inference": "ml-platform-team",
    "production": "ml-platform-team",
    "staging": "ml-platform-team",
    "development": "all-teams"
}

# Define namespace resource quotas
namespace_quotas := {
    "ml-training": {"cpu": "100", "memory": "500Gi", "gpu": "8"},
    "ml-research": {"cpu": "50", "memory": "200Gi", "gpu": "4"},
    "ml-inference": {"cpu": "200", "memory": "400Gi", "gpu": "4"},
    "production": {"cpu": "500", "memory": "1Ti", "gpu": "8"},
    "development": {"cpu": "20", "memory": "50Gi", "gpu": "1"}
}

# Deny deployments without team label
deny[msg] {
    input.request.kind.kind in ["Deployment", "StatefulSet", "Job"]
    
    labels := input.request.object.metadata.labels
    not labels["team"]
    
    msg := "All workloads must have a 'team' label for ownership tracking"
}

# Deny cross-namespace service references
deny[msg] {
    input.request.kind.kind == "Service"
    
    # Check for external name services pointing to other namespaces
    spec := input.request.object.spec
    spec.type == "ExternalName"
    
    external_name := spec.externalName
    contains(external_name, ".svc.cluster.local")
    
    # Extract referenced namespace
    not is_same_namespace(external_name, input.request.namespace)
    not is_allowed_cross_reference(input.request.namespace, external_name)
    
    msg := sprintf("Cross-namespace service reference to %v is not allowed", [external_name])
}

# Deny ConfigMap/Secret references across namespaces
deny[msg] {
    input.request.kind.kind in ["Deployment", "StatefulSet", "Job"]
    
    container := input.request.object.spec.containers[_]
    env_from := container.envFrom[_]
    
    # Check ConfigMap references
    config_ref := env_from.configMapRef.name
    contains(config_ref, ".")  # Indicates cross-namespace reference
    
    msg := "Cross-namespace ConfigMap references are not allowed"
}

# Deny production namespace access without approval
deny[msg] {
    input.request.namespace == "production"
    input.request.kind.kind in ["Deployment", "StatefulSet"]
    
    annotations := input.request.object.metadata.annotations
    not annotations["production-approved-by"]
    
    msg := "Production deployments require 'production-approved-by' annotation"
}

# Deny workloads from wrong team in namespace
deny[msg] {
    input.request.kind.kind in ["Deployment", "StatefulSet", "Job"]
    
    namespace := input.request.namespace
    expected_team := namespace_teams[namespace]
    
    labels := input.request.object.metadata.labels
    actual_team := labels["team"]
    
    expected_team != "all-teams"
    actual_team != expected_team
    
    msg := sprintf("Namespace %v is owned by %v, but workload is from %v", [namespace, expected_team, actual_team])
}

# Deny NetworkPolicy modifications by non-platform team
deny[msg] {
    input.request.kind.kind == "NetworkPolicy"
    input.request.namespace in ["production", "staging"]
    
    annotations := input.request.object.metadata.annotations
    modifier := annotations["modified-by"]
    
    modifier != "ml-platform-team"
    
    msg := "Only ml-platform-team can modify NetworkPolicies in production/staging"
}

# Deny resource requests exceeding namespace quota
deny[msg] {
    input.request.kind.kind in ["Deployment", "StatefulSet"]
    
    namespace := input.request.namespace
    quota := namespace_quotas[namespace]
    
    container := input.request.object.spec.containers[_]
    cpu_request := container.resources.requests.cpu
    
    # Simplified check - in production would sum all resources
    not is_within_quota(cpu_request, quota.cpu)
    
    msg := sprintf("CPU request exceeds namespace quota of %v", [quota.cpu])
}

# Deny privileged containers in multi-tenant namespaces
deny[msg] {
    input.request.kind.kind in ["Pod", "Deployment", "StatefulSet"]
    input.request.namespace in ["ml-training", "ml-research", "development"]
    
    container := input.request.object.spec.containers[_]
    container.securityContext.privileged == true
    
    msg := "Privileged containers are not allowed in multi-tenant namespaces"
}

# Deny host network in shared namespaces
deny[msg] {
    input.request.kind.kind in ["Pod", "Deployment", "StatefulSet"]
    input.request.namespace != "kube-system"
    
    spec := input.request.object.spec
    spec.hostNetwork == true
    
    msg := "Host network is not allowed in application namespaces"
}

# Require network policies in production
deny[msg] {
    input.request.kind.kind in ["Deployment", "StatefulSet"]
    input.request.namespace == "production"
    
    labels := input.request.object.metadata.labels
    not labels["network-policy-applied"]
    
    msg := "Production workloads must reference a NetworkPolicy via 'network-policy-applied' label"
}

# Helper functions
is_same_namespace(external_name, namespace) {
    contains(external_name, sprintf("%v.svc", [namespace]))
}

is_allowed_cross_reference(namespace, external_name) {
    # Allow specific cross-namespace references
    namespace == "ml-inference"
    contains(external_name, "ml-training.svc")
}

is_within_quota(request, limit) {
    # Simplified comparison - in production would parse units
    true  # Placeholder for actual comparison logic
}

# Warn about missing resource limits
warn[msg] {
    input.request.kind.kind in ["Deployment", "StatefulSet"]
    
    container := input.request.object.spec.containers[_]
    not container.resources.limits
    
    msg := "Container missing resource limits - this may affect namespace quotas"
}