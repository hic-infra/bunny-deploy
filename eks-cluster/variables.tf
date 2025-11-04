variable "region" {
  default     = "eu-west-2"
  description = "AWS region"
}

variable "cluster_name" {
  description = "EKS cluster name"
  default     = "hic-bunny-dev"
}

variable "k8s_api_cidrs" {
  default     = ["127.0.0.1/32"]
  description = "CIDRs that have access to the K8s API, default current IP of user"
}

variable "worker-group-1-number-azs" {
  # Use just one so we don't have to deal with node/volume affinity-
  # can't use EBS volumes across AZs
  default     = 1
  description = "Number of AZs to use for worker-group-1"
}

variable "permissions_boundary_name" {
  type        = string
  description = <<-EOT
    The name of the permissions boundary to attach to all IAM roles.
    Specify if you are using a limited IAM role for deployment.
    EOT
  default     = null
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace for running the bunnies"
  default     = "bunny"
}

variable "bunnies_yaml" {
  type        = string
  description = "Relative path to bunnies.yaml"
  default     = "../bunnies.yaml"
}

variable "image" {
  type        = string
  description = "tagged bunny container release"
  default     = "ghcr.io/health-informatics-uon/hutch/bunny:1.4.1"
}
