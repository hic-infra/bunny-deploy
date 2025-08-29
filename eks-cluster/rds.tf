resource "random_password" "rds_password" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "rds_password" {
  name = format("/%s/credentials/aurora", var.cluster_name)

  value = random_password.rds_password.result

  type = "SecureString"
}

resource "aws_db_subnet_group" "bunny_rds" {
  name       = format("%s-rds", var.cluster_name)
  subnet_ids = module.vpc.database_subnets
}

resource "aws_kms_key" "bunny_rds" {
  description             = format("%s-rds", var.cluster_name)
  deletion_window_in_days = 10

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = format("arn:aws:iam::%s:root", data.aws_caller_identity.current.account_id)
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_rds_cluster" "bunny" {
  cluster_identifier = var.cluster_name

  engine      = "aurora-postgresql"
  engine_mode = "provisioned"

  database_name   = "postgres"
  master_username = "bunny"
  master_password = random_password.rds_password.result

  engine_version = "15.10"

  vpc_security_group_ids = [
    aws_security_group.bunny_rds.id
  ]
  db_subnet_group_name = aws_db_subnet_group.bunny_rds.name

  kms_key_id        = aws_kms_key.bunny_rds.arn
  storage_encrypted = true

  serverlessv2_scaling_configuration {
    max_capacity = 5.0
    min_capacity = 0.5
  }
}

resource "aws_rds_cluster_instance" "bunny" {
  cluster_identifier = var.cluster_name
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.bunny.engine
  engine_version     = aws_rds_cluster.bunny.engine_version
}

resource "aws_security_group" "bunny_rds" {
  name        = format("%s-rds", var.cluster_name)
  description = format("Security group for RDS instance used by %s", var.cluster_name)
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "bunny_rds" {
  type      = "ingress"
  from_port = 5432
  to_port   = 5432
  protocol  = "tcp"

  cidr_blocks      = module.vpc.private_subnets_cidr_blocks
  ipv6_cidr_blocks = module.vpc.private_subnets_ipv6_cidr_blocks

  security_group_id = aws_security_group.bunny_rds.id

  description = "Inbound PostgreSQL traffic from the bunnies"
}
