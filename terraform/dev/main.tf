terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    #  version = "2.46.0"
    }
  }
  backend "azurerm" {
#    organization = "NCR"
  }
}
#    workspaces {
#      name = "sandbox"
#    }

data "azurerm_client_config" "current" {
}

provider "azurerm" {
    features {}
}

resource "random_string" "random" {
  length = 6
  special = false
  upper = false
}

data "azurerm_resource_group" "rg" {
  name     = "${var.resourcegroup}${var.countvar}"
#  depends_on = [azurerm_resource_group.rg]
}

# Azure Data Lake
data "azurerm_storage_account" "adls" {
  name                     = "${var.adlsname}${var.countvar}"
  resource_group_name      = data.azurerm_resource_group.rg.name
}

resource "azurerm_storage_container" "synapsefs" {
  name                  = "dataws01"
  storage_account_name  = data.azurerm_storage_account.adls.name
  container_access_type = "private"
}

# Synapse

resource "random_password" "password" {
  length = 24
  special = true
  override_special = "_%@"
}

resource "azurerm_synapse_workspace" "synapseworkspace" {
  name                                 = "${var.synapsename}${var.countvar}"
  resource_group_name                  = data.azurerm_resource_group.rg.name
  location                             = data.azurerm_resource_group.rg.location
  storage_data_lake_gen2_filesystem_id = "https://${data.azurerm_storage_account.adls.name}.dfs.core.windows.net/${var.synapsefs}"
  sql_administrator_login              = "${var.sqladmin}"
  sql_administrator_login_password     = random_password.password.result
  managed_virtual_network_enabled = true
  sql_identity_control_enabled = true
  customer_managed_key_versionless_id  = "https://${data.azurerm_key_vault.kv.name}.vault.azure.net/keys/${data.azurerm_key_vault_key.generated.name}"
  tags = var.default_tags
  depends_on = [data.azurerm_storage_account.adls, data.azurerm_key_vault_key.generated]
}

data "azurerm_synapse_workspace" "synapseworkspace"{
  name                                 = "${var.synapsename}${var.countvar}"
  resource_group_name                  = data.azurerm_resource_group.rg.name
  depends_on = [azurerm_synapse_workspace.synapseworkspace]
}
# Key Vault
data "azurerm_key_vault" "kv" {
  name                        = "${var.keyvaultname}"
  resource_group_name         = data.azurerm_resource_group.rg.name
}

data "azurerm_key_vault_key" "generated" {
  name         = "${var.keyname}"
  key_vault_id = data.azurerm_key_vault.kv.id  
}

data "azurerm_key_vault" "kvsecret" {
  name                        = "${var.secretvaultname}"
  resource_group_name         = data.azurerm_resource_group.rg.name
}

resource "azurerm_key_vault_secret" "kvs_synws" {
  name         = "synwsname"
  value        = azurerm_synapse_workspace.synapseworkspace.name
  key_vault_id = data.azurerm_key_vault.kvsecret.id
#  depends_on = [azurerm_key_vault_access_policy.currentobject]
}

resource "azurerm_key_vault_secret" "kvs_sqlpass" {
  name         = "sqlpassword"
  value        = random_password.password.result
  key_vault_id = data.azurerm_key_vault.kvsecret.id
  depends_on = [data.azurerm_key_vault.kvsecret]
}

#post deployment access

resource "azurerm_key_vault_access_policy" "workspace" {
  key_vault_id = data.azurerm_key_vault.kv.id
  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = azurerm_synapse_workspace.synapseworkspace.identity.0.principal_id

  secret_permissions = [
      "get", "list", "set"
    ]
  key_permissions = [
      "get", "wrapkey", "unwrapkey"
    ]
  depends_on = [azurerm_synapse_workspace.synapseworkspace]
}
/* 
resource "azurerm_role_assignment" "adf_storage_ra" {
  scope                 = azurerm_storage_account.adls.id 
  role_definition_name  = "Storage Blob Data Contributor"
  principal_id          = azurerm_data_factory.adf.identity[0].principal_id
}

resource "azurerm_key_vault_access_policy" "adfobject" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = azurerm_data_factory.adf.identity.0.principal_id

  secret_permissions = [
    "get", "list", "set", "delete", "purge"
    ]
  key_permissions = [
      "create", "get", "wrapkey", "unwrapkey", "delete", "purge"
    ]
  depends_on = [azurerm_data_factory.adf]
}
*/
