# Resource Group and Location
echo "Creating resource group"
resourceGroup=linuxSandboxRg
location=eastUs
az group create \
--name $resourceGroup \
--location $location

# Key Vault Creation
kvName=linuxSandboxKv
az keyvault create \
--name $kvName \
--resource-group $resourceGroup \
--location $location

# Let calling user have a role
upn=$(az ad signed-in-user show --query userPrincipalName -o tsv)
subscriptionId=$(az account list --query "[0].id" -o tsv)
az role assignment create \
--role "Key Vault Secrets Officer" \
--assignee $upn \
--scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.KeyVault/vaults/$kvName"

# VNet and Subnet
echo "Creating VNet and Subnet"
vnetName=linuxSandboxVnet1
subnetName=linuxSandboxSubnet1
vnetAddressPrefix=10.0.0.0/16
subnetAddressPrefix=10.0.0.0/24
az network vnet create \
    --name $vnetName \
    --resource-group $resourceGroup \
    --address-prefixes $vnetAddressPrefix \
    --subnet-name $subnetName \
    --subnet-prefixes $subnetAddressPrefix

#Generate ssh keys 
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# Read the SSH public key content
sshPublicKey=$(cat ~/.ssh/id_rsa.pub)

# Store the SSH key as a secret in the Key Vault
secretName="linuxSandboxPubkey"
az keyvault secret set \
--vault-name $kvName \
--name $secretName \
--value "$sshPublicKey"

# Create startup script to retrieve the public key
echo '#!/bin/bash
az login --identity
secretValue=$(az keyvault secret show --name '"$secretName"' --vault-name '"$kvName"' --query value --output tsv)
mkdir -p ~/.ssh
echo "$secretValue" > ~/.ssh/id_rsa.pub
chmod 600 ~/.ssh/id_rsa.pub' > startupScript.sh

# VM Creation
echo "Creating VM"
vmName=linuxSandboxVm1
az vm create \
  --resource-group $resourceGroup \
  --name $vmName \
  --image Ubuntu2204 \
  --vnet-name $vnetName \
  --subnet $subnetName \
  --size Standard_B1ls \
  --storage-sku Standard_LRS \
  --custom-data startupScript.sh \
  --output json \
  --verbose

# Enable managed identity
az vm identity assign -g $resourceGroup -n $vmName

# Add role to the VM
managedIdentityId=$(az vm show -g $resourceGroup -n $vmName --query identity.principalId --output tsv)
az role assignment create \
--assignee $managedIdentityId \
--role "Key Vault Secrets User" \
--scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.KeyVault/vaults/$kvName"

# Schedule Auto-Shutdown
echo "Scheduling Auto-Shutdown"
az vm auto-shutdown -g $resourceGroup -n $vmName --time 1900 --email "username@email.com"

#Restart VM to run startup script.
az vm restart --resource-group $resourceGroup --name $vmName
