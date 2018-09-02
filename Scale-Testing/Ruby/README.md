# Commands:

# Deploy X number of VMs and associated NIC - This script assumes an existing VNET/Subnet in the same Azure Datacenter Region.
ruby vm-create-with-nic-loop.rb <AZURE_REGION> <EXISTING_VNET_RG> <EXISTING_VNET_NAME> <EXISTING_SUBNET> <NUMBER_TO_DEPLOY> <TARGET_RG>

# Deploy X number of VMs and attach to existing NIC - This script assumes existing NICs in the same Azure Datacenter Region.
ruby vm-create-existing-nic-loop.rb <AZURE_REGION> <EXISTING_NIC_RG> <EXISTING_NIC_ROOT_NAME> <NUMBER_TO_DEPLOY> <TARGET_RG>

# Deploy X number of VMs from a custom image and attach to existing NIC - This script assumes existing NICs and custom image in the same Azure Datacenter Region. 
ruby vm-create-existing-nic-custom-image-loop.rb <AZURE_REGION> <EXISTING_NIC_RG> <EXISTING_NIC_ROOT_NAME> <IMAGE_RG> <IMAGE_NAME> <NUMBER_TO_DEPLOY> <TARGET_RG>

# Deploy X number of VMs and associated NICS from a custom image - This script assumes an existing VNET/Subnet and custom image in the same Azure Datacenter Region.  
ruby vm-create-with-nic-custom-image-loop.rb <AZURE_REGION> <EXISTING_VNET_RG> <EXISTING_VNET_NAME> <EXISTING_SUBNET> <IMAGE_RG> <IMAGE_NAME> <NUMBER_TO_DEPLOY> <TARGET_RG>