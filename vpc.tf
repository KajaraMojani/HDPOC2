// Allow access to the list of AWS Availability Zones within the AWS Region that is configured in vars.tf and init.tf.
// See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones
data "aws_availability_zones" "available" {
    state = "available"
}
data "aws_caller_identity" "current" {}

locals {
    azs = slice(data.aws_availability_zones.available.names, 0, local.required_azs)
}


// Create the required VPC resources in your AWS account.
// See https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.11.2"

  name = local.prefix
  cidr = local.cidr_block
  azs  = local.azs
  tags = var.tags

  enable_dns_hostnames = true
  enable_nat_gateway   = true
  single_nat_gateway   = false
  create_igw           = true

  public_subnets = slice(local.small_subnet_cidrs, local.required_azs, local.required_azs * 2)
  private_subnets = [ for raz in range(local.required_azs) : cidrsubnet(local.cidr_block, var.subnet_offset, raz) ]

  manage_default_security_group = true
  default_security_group_name = "${local.prefix}-sg"

  default_security_group_egress = [
    {
      protocol = "tcp"
      from_port = 443
      to_port = 443
      cidr_blocks = "0.0.0.0/0"
      description = "TLS Traffic"
    },
    {
      protocol = "tcp"
      from_port = 6666
      to_port = 6666
      cidr_blocks = "0.0.0.0/0"
      description = "Relay Traffic"
    },
    {
      protocol = "tcp"
      from_port = 3306
      to_port = 3306
      cidr_blocks = "0.0.0.0/0"
      description = "Hive Metastore Traffic"
    },
    {
      self = true
      description = "Allow all internal TCP and UDP"
    }
  ]

  default_security_group_ingress = [{
    description = "Allow all internal TCP and UDP"
    self        = true
  }]
}

// Create the required VPC endpoints within your AWS account.
// See https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest/submodules/vpc-endpoints
module "vpc_endpoints" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "3.11.2"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.vpc.default_security_group_id]

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = flatten([
        module.vpc.private_route_table_ids,
        module.vpc.public_route_table_ids])
      tags            = {
        Name = "${local.prefix}-s3-vpc-endpoint"
      }
    },
    sts = {
      service             = "sts"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      tags                = {
        Name = "${local.prefix}-sts-vpc-endpoint"
      }
    },
    kinesis-streams = {
      service             = "kinesis-streams"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      tags                = {
        Name = "${local.prefix}-kinesis-vpc-endpoint"
      }
    }
  }

  tags = var.tags
}

// Properly configure the VPC and subnets for Databricks within your AWS account.
// See https://registry.terraform.io/providers/databrickslabs/databricks/latest/docs/resources/mws_networks
resource "databricks_mws_networks" "this" {
  provider           = databricks.mws
  account_id         = var.databricks_account_id
  network_name       = "${local.prefix}-network"
  security_group_ids = [module.vpc.default_security_group_id]
  subnet_ids         = module.vpc.private_subnets
  vpc_id             = module.vpc.vpc_id
}

resource "aws_default_network_acl" "main" {
  default_network_acl_id = module.vpc.default_network_acl_id

  ingress {
    protocol   = "all"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no = 100
    action = "allow"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_block  = "0.0.0.0/0"
  }

  egress {
    rule_no = 200
    action = "allow"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_block  = "0.0.0.0/0"
  }

  egress {
    rule_no = 300
    action = "allow"
    from_port   = 6666
    to_port     = 6666
    protocol    = "tcp"
    cidr_block  = "0.0.0.0/0"
  }

  egress {
    rule_no     = 400
    action      = "allow"
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_block  = "${local.cidr_block}"
  }

  tags = merge({
    Name = "${local.prefix}-default-vpc-nacl"
  },
  var.tags)
}
