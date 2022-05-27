variable "databricks_account_username" {}
variable "databricks_account_password" {}
variable "databricks_account_id" {}

variable "databricks_account_name" {
  type = string
}

variable "required_az_total" {
  default = "3"
}

variable "cidr_block_host" {
  default = "192.160.0.0"
}

variable "cidr_block_prefix" {
  default = "16"
}

variable "subnet_offset" {
  default = 3
}


variable "tags" {
  default = {}
}

variable "region" {
  default = "ap-southeast-2"
}

locals {
  prefix = "nhs-sba-test4"
  cidr_block = "${var.cidr_block_host}/${var.cidr_block_prefix}"
  
  small_subnet_cidrs = [for i in range(0, 10) : cidrsubnet(cidrsubnet(local.cidr_block, var.subnet_offset, pow(2, var.subnet_offset)-1),
   32 - var.cidr_block_prefix - var.subnet_offset - 4,
    pow(2, 32 - var.cidr_block_prefix - var.subnet_offset - 4) - 1 - i)]

  required_azs = var.required_az_total == "all" ? length(data.aws_availability_zones.available.names) : tonumber(var.required_az_total)
}

variable "aws-iam-arn" {
default="arn:aws:iam::303037622152:role/service/nhs-dmsmdm-sba-flood-iam-role"

}
