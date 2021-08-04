variable "default_tags" { 
    type = map 
    default = {
      WorkloadName = "mdw",
      DataClassification = "General",
      Criticality = "High",
      BusinessUnit = "datawarehouse",
      OpsCommitment = "Baseline only",
      OpsTeam = "Cloud operations"
  }
}

variable "resourcegroup" {
    type = string
    default = "ITS-APPOPS-EDL-EUA02-POC-SYN-RG-WS"
}
variable "adfname" {
    type = string
    default = "adfpocncr"    
}

variable "synapsename" {
    type = string
    default = "synapsews"    
}

variable "keyvaultname" {
    type = string
    default = "kvh4ke4a"    
}

variable "secretvaultname" {
    type = string
    default = "kvsecreth4ke4a"    
}

variable "sqladmin" {
    type = string
    default = "synapsesqladminpocws01"    
}

variable "keyname" {
    type = string
    default = "Synapse-poc-key01-ws01"    
}

variable "env" {
    type = string
    default = "dev"
}

variable "region" {
    type = string
    default = "eastus"
}

variable "regionshort" {
    type = string
    default = "eus"
}

variable "workspace" {
    type = string
    default = "adle-poc-syn-ws01"
}

variable "poolname" {
    type = string
    default = "sqlpool_ws01"
}

variable "poolsku" {
    type = string
    default = "DW100c"
}
 
variable "adlsname" {
    type = string
    description = "can only consist of lowercase letters and numbers, and must be between 3 and 24 characters long"
    default = "adlepocadls2storagews"
}

variable "auditstorage" {
    type = string
    description = "can only consist of lowercase letters and numbers, and must be between 3 and 24 characters long"
    default = "adlepocauditstoragews"
}

variable "synapsefs" {
    type = string
    description = "can only consist of lowercase letters and numbers, and must be between 3 and 24 characters long"
    default = "dataws01"
}

variable "countvar" {
    type = string
    description = "can only consist of lowercase letters and numbers, and must be between 3 and 24 characters long"
    default = "05"
}