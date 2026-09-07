terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.10"   # Developer SKU / virtual_network_id 需 4.10 以上
    }
  }
}

provider "azurerm" {
  features {}
  # subscription_id = var.subscription_id   # azurerm v4 起建議明確指定
}
