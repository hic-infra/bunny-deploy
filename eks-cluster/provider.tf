terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.36"
    }
  }

  required_version = ">= 1.5.7"

  backend "s3" {}
}

provider "aws" {
  region = var.region
}
