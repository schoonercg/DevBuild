terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    #  version = "2.46.0"
    }
  }
  backend "local" {
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
# Data Factory
data "azurerm_data_factory" "adf" {
  name                = "${var.adfname}${var.countvar}"
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Azure Data Lake
data "azurerm_storage_account" "adls" {
  name                     = "${var.adlsname}${var.countvar}"
  resource_group_name      = data.azurerm_resource_group.rg.name
}

# Synapse

resource "random_password" "password" {
  length = 24
  special = true
  override_special = "_%@"
}

data "azurerm_synapse_workspace" "synapseworkspace"{
  name                                 = "${var.synapsename}${var.countvar}"
  resource_group_name                  = data.azurerm_resource_group.rg.name
#  depends_on = [azurerm_synapse_workspace.synapseworkspace]
}

resource "azurerm_synapse_sql_pool" "synapsepool" {
  name                 = var.poolname
  synapse_workspace_id = data.azurerm_synapse_workspace.synapseworkspace.id
  sku_name             = var.poolsku
  create_mode          = "Default"
  tags = var.default_tags
  depends_on = [data.azurerm_synapse_workspace.synapseworkspace]
}

resource "azurerm_key_vault_secret" "kvs_syndb" {
  name         = "dwname"
  value        = azurerm_synapse_sql_pool.synapsepool.name
  key_vault_id = data.azurerm_key_vault.kvsecret.id
#  depends_on = [azurerm_key_vault_access_policy.currentobject]
}

resource "azurerm_synapse_firewall_rule" "synfwr" {
  name                 = "AllowAllWindowsAzureIps"
  synapse_workspace_id = data.azurerm_synapse_workspace.synapseworkspace.id
  start_ip_address     = "0.0.0.0"
  end_ip_address       = "0.0.0.0"

  depends_on = [azurerm_synapse_sql_pool.synapsepool]
}

resource "azurerm_key_vault_secret" "kv" {
  name         = "sqlpoolconn"
  value        = "Server=tcp:${data.azurerm_synapse_workspace.synapseworkspace.name}.database.windows.net,1433;Initial Catalog=${azurerm_synapse_sql_pool.synapsepool.name};Persist Security Info=False;User ID=sqladminuser;Password=${random_password.password.result};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = data.azurerm_key_vault.kvsecret.id
#  depends_on = [azurerm_key_vault_access_policy.currentobject]
}
# Key Vault
data "azurerm_key_vault" "kv" {
  name                        = "${var.keyvaultname}"
  resource_group_name         = data.azurerm_resource_group.rg.name
}

data "azurerm_key_vault" "kvsecret" {
  name                        = "${var.secretvaultname}"
  resource_group_name         = data.azurerm_resource_group.rg.name
}
resource "azurerm_synapse_firewall_rule" "example" {
  name                 = "AllowAll"
  synapse_workspace_id = data.azurerm_synapse_workspace.synapseworkspace.id
  start_ip_address     = "0.0.0.0"
  end_ip_address       = "255.255.255.255"
}

resource "azurerm_storage_account" "example_connect" {
  name                     = "examplestorage${var.randstring}"
  resource_group_name      = data.azurerm_resource_group.rg.name
  location                 = data.azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "BlobStorage"
}

resource "azurerm_synapse_managed_private_endpoint" "SQL" {
  name                 = "adle-poc-syn-ws01-pe-01"
  synapse_workspace_id = data.azurerm_synapse_workspace.synapseworkspace.id
  target_resource_id   = azurerm_storage_account.example_connect.id
  subresource_name     = "blob"

  depends_on = [azurerm_synapse_firewall_rule.example]
}
/*
resource "azurerm_synapse_managed_private_endpoint" "SQLOnDemand" {
  name                 = "adle-poc-syn-ws01-pe-02"
  synapse_workspace_id = data.azurerm_synapse_workspace.synapseworkspace.id
  target_resource_id   = azurerm_storage_account.example_connect.id
  subresource_name     = "blob"

  depends_on = [azurerm_synapse_firewall_rule.example]
}

resource "azurerm_synapse_managed_private_endpoint" "Dev" {
  name                 = "adle-poc-syn-ws01-pe-03"
  synapse_workspace_id = data.azurerm_synapse_workspace.synapseworkspace.id
  target_resource_id   = azurerm_storage_account.example_connect.id
  subresource_name     = "blob"

  depends_on = [azurerm_synapse_firewall_rule.example]
}

resource "azurerm_synapse_role_assignment" "example" {
  synapse_workspace_id = data.azurerm_synapse_workspace.synapseworkspace.id
  role_name            = "Synapse SQL Administrator"
  principal_id         = data.azurerm_client_config.current.object_id

  depends_on = [azurerm_synapse_firewall_rule.example]
}*/

resource "azurerm_synapse_spark_pool" "example" {
  name                 = "pocsynsparkws01"
  synapse_workspace_id = data.azurerm_synapse_workspace.synapseworkspace.id
  node_size_family     = "MemoryOptimized"
  node_size            = "Small"

  auto_scale {
    max_node_count = 6
    min_node_count = 3
  }

  auto_pause {
    delay_in_minutes = 10
  }

  tags = {
    ENV = "Production"
  }
}

#vnets
#ITS-APPOPS-EDL-POC-EUA01-VNET 
#ITS-APPOPS-EDL-POC-EUA01-STREAM01-SNET
