module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  #version = "v3.2.0"
  version = "~> 3.0"

  name = var.name
  cidr = var.vpc_cidr

  azs  = var.azs
  public_subnets  = [for k, v in var.azs : cidrsubnet(var.vpc_cidr, 8, k)]
  private_subnets = [for k, v in var.azs : cidrsubnet(var.vpc_cidr, 8, k + 10)]

  enable_nat_gateway   = true
  create_igw           = true
  enable_dns_hostnames = true
  single_nat_gateway   = true

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${var.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${var.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${var.name}-default" }  

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.name}" = "shared"
    "kubernetes.io/role/elb"              = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = "1"
  }

  tags = merge(
    var.tags,
  )
  
}

resource "aws_security_group" "database" {
  name        = "database_security_group"
  description = "Allow postgresql traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "PostgreSQL"
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    #cidr_blocks      = [var.vpc_cidr]
    security_groups = [aws_security_group.container.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "PostgreSQL"
  }
}

resource "aws_security_group" "container" {
  name        = "container_security_group"
  description = "Allow postgresql traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "to container"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [var.vpc_cidr]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "container security_groups"
  }
}