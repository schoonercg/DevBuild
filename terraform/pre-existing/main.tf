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

resource "azurerm_resource_group" "rg" {
  name     = "${var.resourcegroup}${var.countvar}"
  location = var.region
  tags = var.default_tags
}


data "azurerm_resource_group" "rg" {
  name     = "${var.resourcegroup}${var.countvar}"
  depends_on = [azurerm_resource_group.rg]
}


# Data Factory
resource "azurerm_data_factory" "adf" {
  name                = "${var.adfname}${var.countvar}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  tags = var.default_tags
  
  identity {
    type = "SystemAssigned"
  }

  vsts_configuration {
            account_name    = "jpazuredev"
            branch_name     = "main" 
            project_name    = "moderndatawarehouse"
            repository_name = "mdw-azure-terraform" 
            root_folder     = "/adf" 
            tenant_id       = data.azurerm_client_config.current.tenant_id  
  }

}

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

resource "azurerm_key_vault_secret" "kvs_adf" {
  name         = "adfname"
  value        = azurerm_data_factory.adf.name
  key_vault_id = azurerm_key_vault.kv.id
  depends_on = [azurerm_key_vault_access_policy.currentobject]
}

# Azure Data Lake
resource "azurerm_storage_account" "adls" {
  name                     = "${var.adlsname}${var.countvar}"
  resource_group_name      = data.azurerm_resource_group.rg.name
  location                 = data.azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = "true"
#  network_rules {
#    default_action = Deny
#    bypass = "AzureServices"
#  }
  tags = var.default_tags
}

resource "azurerm_storage_container" "synapsefs" {
  name                  = "${var.synapsefs}${var.countvar}"
  storage_account_name  = azurerm_storage_account.adls.name
  container_access_type = "private"
}

# Synapse

resource "random_password" "password" {
  length = 24
  special = true
  override_special = "_%@"
}

resource "azurerm_storage_account" "auditstorage" {
  name                     = "${var.auditstorage}${var.countvar}"
  resource_group_name      = data.azurerm_resource_group.rg.name
  location                 = data.azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = "true"
  tags = var.default_tags
}

# Key Vault
resource "azurerm_key_vault" "kv" {
  name                        = "${var.keyvaultname}${random_string.random.result}"
  location                    = data.azurerm_resource_group.rg.location
  resource_group_name         = data.azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = true
  sku_name = "standard"
}

resource "azurerm_key_vault" "kvsecret" {
  name                        = "${var.secretvaultname}${random_string.random.result}"
  location                    = data.azurerm_resource_group.rg.location
  resource_group_name         = data.azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = true
  sku_name = "standard"
}

resource "azurerm_key_vault_access_policy" "currentobject" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
     "create", "get", "wrapkey", "unwrapkey", "delete", "purge", "list"
  ]

  secret_permissions = [
      "Get", "list", "set", "delete", "purge"

  ]
}

resource "azurerm_key_vault_access_policy" "currentobjectsecret" {
  key_vault_id = azurerm_key_vault.kvsecret.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
     "create", "get", "wrapkey", "unwrapkey", "delete", "purge", "list"
  ]

  secret_permissions = [
      "Get", "list", "set", "delete", "purge"

  ]
}

resource "azurerm_key_vault_secret" "kvs_rg" {
  name         = "rgname"
  value        = data.azurerm_resource_group.rg.name
  key_vault_id = azurerm_key_vault.kv.id
  depends_on = [azurerm_key_vault_access_policy.currentobject]
}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_key_vault_secret" "test_build" {
  name         = "tfkey"
  value        = base64encode("${tls_private_key.example.private_key_pem}")
  key_vault_id = azurerm_key_vault.kv.id

  tags = {
    env = "dev"
    app = "app1"
  }
  depends_on = [azurerm_key_vault_access_policy.currentobject]
}

resource "azurerm_key_vault_key" "generated" {
  name         = "${var.keyname}"
  key_vault_id = azurerm_key_vault.kv.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
  depends_on = [azurerm_key_vault_access_policy.currentobject]
}

