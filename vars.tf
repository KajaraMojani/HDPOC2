variable "databricks_account_username" {}
variable "databricks_account_password" {}
variable "databricks_account_id" {}

variable "tags" {
  default = {}
}

variable "cidr_block" {
  default = "194.160.0.0/16"
}

variable "region" {
  default = "ap-southeast-2"
}

locals {
  prefix = "nhs-sba-test2"
}