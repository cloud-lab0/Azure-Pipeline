terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}
# even though we have no features, this stil needs to be here
# otherwise terraform validate will throw an error
provider "azurerm" {
  features {}
}
