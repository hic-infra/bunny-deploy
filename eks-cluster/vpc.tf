data "aws_availability_zones" "available" {}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.17.0"

  name = var.cluster_name
  cidr = "10.0.0.0/16"
  # azs                  = data.aws_availability_zones.available.names[:1]
  # private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  # public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  # EKS requires at least two AZ (though node groups can be placed in just one)
  azs              = ["${var.region}b", "${var.region}c"]
  private_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  database_subnets = ["10.0.3.0/28", "10.0.3.16/28"]
  public_subnets   = ["10.0.4.0/24", "10.0.5.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  # map_public_ip_on_launch = true

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }

  # https://github.com/terraform-aws-modules/terraform-aws-vpc/blob/v5.17.0/examples/ipv6-dualstack/main.tf
  enable_ipv6                                   = true
  public_subnet_assign_ipv6_address_on_creation = true
  public_subnet_ipv6_prefixes                   = [0, 1]
  private_subnet_ipv6_prefixes                  = [2, 3]
  database_subnet_ipv6_prefixes                 = [4, 5]
}
