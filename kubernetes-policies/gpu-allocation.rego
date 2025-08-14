# GPU Allocation Policy
# Controls GPU resource allocation in Kubernetes
# Enforces limits per namespace and requires justification

package kubernetes.admission

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Maximum GPUs per namespace
max_gpus_per_namespace := {
    "ml-training": 8,
    "ml-research": 4,
    "ml-inference": 2,
    "development": 1,
    "default": 0
}

# Deny GPU requests without justification
deny[msg] {
    input.request.kind.kind in ["Pod", "Deployment", "Job"]
    
    # Check if requesting GPUs
    container := input.request.object.spec.containers[_]
    gpu_request := container.resources.requests["nvidia.com/gpu"]
    to_number(gpu_request) > 0
    
    # Check for justification
    not input.request.object.metadata.annotations["gpu-justification"]
    
    msg := "GPU requests require a 'gpu-justification' annotation explaining the use case"
}

# Deny excessive GPU requests per pod
deny[msg] {
    input.request.kind.kind in ["Pod", "Deployment"]
    
    container := input.request.object.spec.containers[_]
    gpu_request := container.resources.requests["nvidia.com/gpu"]
    
    # Limit single pods to 2 GPUs (except training jobs)
    to_number(gpu_request) > 2
    input.request.object.metadata.labels["workload-type"] != "training"
    
    msg := sprintf("Single pod requesting %v GPUs exceeds limit of 2 (use Job for training workloads)", [gpu_request])
}

# Deny GPU requests in unauthorized namespaces
deny[msg] {
    input.request.kind.kind in ["Pod", "Deployment", "Job"]
    
    container := input.request.object.spec.containers[_]
    gpu_request := container.resources.requests["nvidia.com/gpu"]
    to_number(gpu_request) > 0
    
    # Check if namespace is authorized for GPUs
    namespace := input.request.namespace
    not namespace in ["ml-training", "ml-research", "ml-inference", "development"]
    
    msg := sprintf("Namespace '%v' is not authorized for GPU usage", [namespace])
}

# Deny if namespace GPU quota exceeded
deny[msg] {
    input.request.kind.kind in ["Pod", "Deployment", "Job"]
    
    container := input.request.object.spec.containers[_]
    gpu_request := container.resources.requests["nvidia.com/gpu"]
    requested_gpus := to_number(gpu_request)
    
    namespace := input.request.namespace
    max_allowed := max_gpus_per_namespace[namespace]
    
    requested_gpus > max_allowed
    
    msg := sprintf("GPU request (%v) exceeds namespace '%v' quota of %v GPUs", [requested_gpus, namespace, max_allowed])
}

# Deny GPU requests without resource limits
deny[msg] {
    input.request.kind.kind in ["Pod", "Deployment", "Job"]
    
    container := input.request.object.spec.containers[_]
    gpu_request := container.resources.requests["nvidia.com/gpu"]
    to_number(gpu_request) > 0
    
    # Check if limits are set
    not container.resources.limits["nvidia.com/gpu"]
    
    msg := "GPU requests must also specify resource limits"
}

# Deny mismatched GPU requests and limits
deny[msg] {
    input.request.kind.kind in ["Pod", "Deployment", "Job"]
    
    container := input.request.object.spec.containers[_]
    gpu_request := container.resources.requests["nvidia.com/gpu"]
    gpu_limit := container.resources.limits["nvidia.com/gpu"]
    
    gpu_request != gpu_limit
    
    msg := sprintf("GPU request (%v) must match limit (%v)", [gpu_request, gpu_limit])
}

# Deny development workloads with production GPUs
deny[msg] {
    input.request.kind.kind in ["Pod", "Deployment"]
    input.request.namespace == "development"
    
    # Check for high-end GPU node selector
    node_selector := input.request.object.spec.nodeSelector
    node_selector["gpu-type"] in ["a100", "v100"]
    
    msg := "Development namespace cannot use A100/V100 GPUs. Use T4 or consumer GPUs."
}

# Require cost tracking labels for GPU workloads
deny[msg] {
    input.request.kind.kind in ["Pod", "Deployment", "Job"]
    
    container := input.request.object.spec.containers[_]
    gpu_request := container.resources.requests["nvidia.com/gpu"]
    to_number(gpu_request) > 0
    
    # Check for cost tracking labels
    labels := input.request.object.metadata.labels
    not labels["cost-center"]
    
    msg := "GPU workloads must have 'cost-center' label for chargeback"
}

# Warn about GPU requests without priority class
warn[msg] {
    input.request.kind.kind in ["Pod", "Deployment", "Job"]
    
    container := input.request.object.spec.containers[_]
    gpu_request := container.resources.requests["nvidia.com/gpu"]
    to_number(gpu_request) > 0
    
    not input.request.object.spec.priorityClassName
    
    msg := "GPU workloads should specify a priorityClassName for better scheduling"
}