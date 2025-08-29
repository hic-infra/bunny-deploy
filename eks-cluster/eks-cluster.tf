# Full example:
# https://github.com/terraform-aws-modules/terraform-aws-eks/blame/v19.10.0/examples/complete/main.tf
# https://github.com/terraform-aws-modules/terraform-aws-eks/blob/v19.10.0/docs/compute_resources.md

# Get IP of caller to limit SSH inbound IPs
data "http" "myip" {
  url = "https://checkip.amazonaws.com/"
}

data "aws_caller_identity" "current" {}

locals {
  cluster_endpoint_public_access_cidrs = [
    for item in var.k8s_api_cidrs :
    replace(item, "myip", "${chomp(data.http.myip.response_body)}/32")
  ]

  permissions_boundary_arn = (
    var.permissions_boundary_name != null ?
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.permissions_boundary_name}" :
    null
  )
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.36.0"
  cluster_name    = var.cluster_name
  cluster_version = "1.32"
  subnet_ids      = module.vpc.private_subnets

  authentication_mode = "API"

  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = local.cluster_endpoint_public_access_cidrs

  create_cloudwatch_log_group = true

  vpc_id = module.vpc.vpc_id

  iam_role_permissions_boundary = local.permissions_boundary_arn

  eks_managed_node_group_defaults = {
    capacity_type                 = "ON_DEMAND"
    iam_role_permissions_boundary = local.permissions_boundary_arn
    iam_role_additional_policies = {
      ssmcore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }

  eks_managed_node_groups = {
    worker_group-1 = {
      name           = "worker-group-1"
      instance_types = ["t3a.large"]
      ami_type       = "BOTTLEROCKET_x86_64"
      platform       = "bottlerocket"

      # additional_userdata = "echo foo bar"
      vpc_security_group_ids = [
        aws_security_group.all_worker_mgmt.id,
        aws_security_group.worker_group_all.id,
      ]
      min_size     = 1
      max_size     = 3
      desired_size = 1

      # Disk space can't be set with the default custom launch template
      # disk_size = 100
      block_device_mappings = [
        {
          # https://github.com/bottlerocket-os/bottlerocket/discussions/2011
          device_name = "/dev/xvdb"
          ebs = {
            volume_size = 15
            volume_type = "gp3"
          }
        }
      ]

      credit_specification = {
        cpu_credits = "standard"
      }

      subnet_ids = slice(module.vpc.private_subnets, 0, var.worker-group-1-number-azs)
    },
    # Add more worker groups here
  }
}

data "aws_eks_cluster" "cluster" {
  name = split("/", module.eks.cluster_arn)[1]
}

data "aws_eks_cluster_auth" "cluster" {
  name = split("/", module.eks.cluster_arn)[1]
}
