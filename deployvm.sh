
# Resource Group and Location
echo "Creating resource group"
resourceGroup=linuxsandbox-rg
location=eastus
az group create \
--name $resourceGroup \
--location $location


#Key Vault Creation
kvName=linuxsandbox-kv
az keyvault create \
--name $kvName \
--resource-group $resourceGroup \
 --location $location

# Let calling user have a role
upn=$(az ad signed-in-user show --query userPrincipalName -o tsv)
subscriptionid=$(az account list --query "[0].id" -o tsv)
az role assignment create \
 --role "Key Vault Secrets Officer" \
 --assignee $upn \
 --scope "/subscriptions/$subscriptionid/resourceGroups/$resourceGroup/providers/Microsoft.KeyVault/vaults/$kvName"


# VNet and Subnet
echo "Creating vnet and subnet"
vnetName=linuxsandbox-vnet1
subnetName=linuxsandbox-subnet1
vnetAddressPrefix=10.0.0.0/16
subnetAddressPrefix=10.0.0.0/24
az network vnet create \
    --name $vnetName \
    --resource-group $resourceGroup \
    --address-prefixes $vnetAddressPrefix \
    --subnet-name $subnetName \
    --subnet-prefixes $subnetAddressPrefix

# Read the SSH private key content
SSH_PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub)

# Store the SSH key as a secret in the Key Vault
secretName="linuxsandbox-pubkey"
az keyvault secret set \
--vault-name $kvName \
--name $secretName \
--value "$SSH_PUBLIC_KEY"

echo '#!/bin/bash
az login --identity
secret_value=$(az keyvault secret show --name $secretName --vault-name $kvName --query value --output tsv)
echo "$secret_value" > ~/.ssh/id_rsa.pub
chmod 600 ~/.ssh/id_rsa.pub' > startup-script.sh

# VM Creation
echo "Creating VM"
vmName=linuxsandbox-vm1
az vm create \
  --resource-group $resourceGroup \
  --name $vmName \
  --image Ubuntu2204 \
  --vnet-name $vnetName \
  --subnet $subnetName \
  --size Standard_B1ls \
  --storage-sku Standard_LRS \
  --generate-ssh-keys \
  --output json \
  --verbose

#Enable managed identity
az vm identity assign -g $resourceGroup -n $vmName

#Add role
managedidentityid=$(az vm show -g $resourceGroup -n $vmName --query identity.principalId --output tsv)
az role assignment create \
--assignee managedidentityid \
--role "Key Vault Secrets User" \
--scope "/subscriptions/$subscriptionid/resourceGroups/$resourceGroup/providers/Microsoft.KeyVault/vaults/$kvName"


# Schedule Auto-Shutdown
echo "Scheduling Auto-Shutdown"
az vm auto-shutdown -g $resourceGroup -n $vmName --time 1900 --email "eqanahmad@gmail.com"

az vm restart --resource-group $resourceGroup --name  $vmName


