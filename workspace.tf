// Set up the Databricks workspace to use the E2 version of the Databricks on AWS platform.
// See https://registry.terraform.io/providers/databrickslabs/databricks/latest/docs/resources/mws_workspaces
resource "databricks_mws_workspaces" "this" {
  provider        = databricks.mws
  account_id      = var.databricks_account_id
  aws_region      = var.region
  workspace_name  = local.prefix
  deployment_name = local.prefix

  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.this.network_id
}

// Capture the Databricks workspace's URL.
output "databricks_host" {
  value = databricks_mws_workspaces.this.workspace_url
}

// Initialize the Databricks provider in "normal" (workspace) mode.
// See https://registry.terraform.io/providers/databrickslabs/databricks/latest/docs#authentication
provider "databricks" {
  // In workspace mode, you don't have to give providers aliases. Doing it here, however,
  // makes it easier to reference, for example when creating a Databricks personal access token
  // later in this file.
  alias = "created_workspace"
  host = databricks_mws_workspaces.this.workspace_url
}
