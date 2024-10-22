
# Resource Group and Location
echo "Creating resource group"
resourceGroup=linuxsandbox-rg
location=eastus
az group create \
--name $resourceGroup \
--location $location

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


# Schedule Auto-Shutdown
echo "Scheduling Auto-Shutdown"
az vm auto-shutdown -g $resourceGroup -n $vmName --time 1900 --email "eqanahmad@gmail.com"