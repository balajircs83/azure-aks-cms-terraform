provider "azurerm" {
  features {}
  subscription_id = "b83326f1-b625-4cbc-b5c3-c2f240c6665d"
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.24.0" # Use a recent version
    }
  }
}


locals {
  common_tags = {
    "Owner Name"        = var.owner_name
    "Owner Phone-Email" = var.owner_phone_email
    "POC Name"          = var.poc_name
    "Approver"          = var.approver
    "Valid till Date"   = var.valid_till_date
  }
}


# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags = local.common_tags
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "cms-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags = local.common_tags
}

# Subnet for AKS
resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Azure Container Registry (ACR)
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
  tags = local.common_tags
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "cms-aks"

  default_node_pool {
    name                = "default"
    node_count          = 2
    vm_size             = "Standard_D2s_v3"
    vnet_subnet_id      = azurerm_subnet.aks_subnet.id
    tags = local.common_tags
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
  }

  depends_on = [azurerm_subnet.aks_subnet]
  tags = local.common_tags
}

# Azure SQL Server
resource "azurerm_mssql_server" "sql_server" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
  tags = local.common_tags
}

# Azure SQL Database
resource "azurerm_mssql_database" "sql_db" {
  name           = "cms-db"
  server_id      = azurerm_mssql_server.sql_server.id
  sku_name       = "Basic"
  tags = local.common_tags
}

# Enable Azure Monitor for AKS (Diagnostics)
resource "azurerm_monitor_diagnostic_setting" "aks_monitor" {
  name                       = "aks-diagnostics"
  target_resource_id         = azurerm_kubernetes_cluster.aks.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.monitor.id

  enabled_log {
    category = "kube-apiserver"
  }

  metric {
    category = "AllMetrics"
  }
  
}

# Log Analytics Workspace for Monitoring
resource "azurerm_log_analytics_workspace" "monitor" {
  name                = "cms-log-analytics"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  tags = local.common_tags
}