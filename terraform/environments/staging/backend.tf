terraform {
  # The remote-state bootstrap creates the Azure Storage Account used here later.
  # Initialize with -backend=false until backend values are supplied securely.
  backend "azurerm" {}
}
