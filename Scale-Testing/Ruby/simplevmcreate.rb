#!/usr/bin/env ruby

require 'azure_mgmt_resources'
require 'azure_mgmt_network'
require 'azure_mgmt_storage'
require 'azure_mgmt_compute'

RG_LOC = 'eastus2'
GROUP_NAME = 'azure-sample-compute-group'
VNET_RG = 'Test-AGW02'
VNET_NAME = 'Test-AGW02'
SUBNET_NAME = 'apps'

Storage = Azure::Storage::Profiles::Latest::Mgmt
Network = Azure::Network::Profiles::Latest::Mgmt
Compute = Azure::Compute::Profiles::Latest::Mgmt
Resources = Azure::Resources::Profiles::Latest::Mgmt

StorageModels = Storage::Models
NetworkModels = Network::Models
ComputeModels = Compute::Models
ResourceModels = Resources::Models

# This sample shows how to manage a Azure virtual machines using using the Azure Resource Manager APIs for Ruby.
#
# This script expects that the following environment vars are set:
#
# AZURE_TENANT_ID: with your Azure Active Directory tenant id or domain
# AZURE_CLIENT_ID: with your Azure Active Directory Application Client ID
# AZURE_CLIENT_SECRET: with your Azure Active Directory Application Secret
# AZURE_SUBSCRIPTION_ID: with your Azure Subscription Id
#

def network_client
  @network_client ||= ClientProvider.network_client
end

def run_example
  #
  # Create the Resource Manager Client with an Application (service principal) token provider
  #
  subscription_id = ENV['AZURE_SUBSCRIPTION_ID'] || '11111111-1111-1111-1111-111111111111' # your Azure Subscription Id
  provider = MsRestAzure::ApplicationTokenProvider.new(
      ENV['AZURE_TENANT_ID'],
      ENV['AZURE_CLIENT_ID'],
      ENV['AZURE_CLIENT_SECRET'])
  credentials = MsRest::TokenCredentials.new(provider)

  options = {
      credentials: credentials,
      subscription_id: subscription_id
  }

  resource_client = Resources::Client.new(options)
  network_client = Network::Client.new(options)
  storage_client = Storage::Client.new(options)
  compute_client = Compute::Client.new(options)

  #
  # Managing resource groups
  #
  resource_group_params = ResourceModels::ResourceGroup.new.tap do |rg|
    rg.location = RG_LOC
  end

  # Create Resource group
  puts 'Create Resource Group'
  print_group resource_client.resource_groups.create_or_update(GROUP_NAME, resource_group_params)

  postfix = rand(1000)

  subnet = network_client.subnets.get(VNET_RG, VNET_NAME, 'apps')

  vm = create_vm(compute_client, network_client, RG_LOC, 'firstvm', subnet)

  export_template(resource_client)

  puts 'Press any key to continue and delete the sample resources'
  gets

  # Delete Resource group and everything in it
  puts 'Delete Resource Group'
  resource_client.resource_groups.delete(GROUP_NAME)
  puts "\nDeleted: #{GROUP_NAME}"

end

def print_group(resource)
  puts "\tname: #{resource.name}"
  puts "\tid: #{resource.id}"
  puts "\tlocation: #{resource.location}"
  puts "\ttags: #{resource.tags}"
  puts "\tproperties:"
  print_item(resource.properties)
end

def print_item(resource)
  resource.instance_variables.sort.each do |ivar|
    str = ivar.to_s.gsub /^@/, ''
    if resource.respond_to? str.to_sym
      puts "\t\t#{str}: #{resource.send(str.to_sym)}"
    end
  end
  puts "\n\n"
end

def export_template(resource_client)
  puts "Exporting the resource group template for #{GROUP_NAME}"
  export_result = resource_client.resource_groups.export_template(
      GROUP_NAME,
      ResourceModels::ExportTemplateRequest.new.tap{ |req| req.resources = ['*'] }
  )
  puts export_result.template
  puts ''
end

# Create a Virtual Machine and return it
def create_vm(compute_client, network_client, location, vm_name, subnet)
  puts "Creating a network interface for the VM #{vm_name}"
  print_item nic = network_client.network_interfaces.create_or_update(
      GROUP_NAME,
      "sample-ruby-nic-#{vm_name}",
      NetworkModels::NetworkInterface.new.tap do |interface|
        interface.location = RG_LOC
        interface.ip_configurations = [
            NetworkModels::NetworkInterfaceIPConfiguration.new.tap do |nic_conf|
              nic_conf.name = "sample-ruby-nic-#{vm_name}"
              nic_conf.private_ipallocation_method = NetworkModels::IPAllocationMethod::Dynamic
              nic_conf.subnet = subnet
            end
        ]
      end
  )

  puts 'Creating a Ubuntu 16.04.0-LTS Standard DS2 V2 virtual machine'
  vm_create_params = ComputeModels::VirtualMachine.new.tap do |vm|
    vm.location = location
    vm.os_profile = ComputeModels::OSProfile.new.tap do |os_profile|
      os_profile.computer_name = vm_name
      os_profile.admin_username = 'notAdmin'
      os_profile.admin_password = 'Pa$$w0rd92'
    end

    vm.storage_profile = ComputeModels::StorageProfile.new.tap do |store_profile|
      store_profile.image_reference = ComputeModels::ImageReference.new.tap do |ref|
        ref.publisher = 'canonical'
        ref.offer = 'UbuntuServer'
        ref.sku = '16.04.0-LTS'
        ref.version = 'latest'
      end
      store_profile.os_disk = ComputeModels::OSDisk.new.tap do |os_disk|
        os_disk.name = "sample-os-disk-#{vm_name}"
        os_disk.caching = ComputeModels::CachingTypes::None
        os_disk.create_option = ComputeModels::DiskCreateOptionTypes::FromImage
      end
    end

    vm.hardware_profile = ComputeModels::HardwareProfile.new.tap do |hardware|
      hardware.vm_size = ComputeModels::VirtualMachineSizeTypes::StandardDS2V2
    end

    vm.network_profile = ComputeModels::NetworkProfile.new.tap do |net_profile|
      net_profile.network_interfaces = [
          ComputeModels::NetworkInterfaceReference.new.tap do |ref|
            ref.id = nic.id
            ref.primary = true
          end
      ]
    end
  end

  print_item vm = compute_client.virtual_machines.create_or_update(GROUP_NAME, "sample-ruby-vm-#{vm_name}", vm_create_params)
  vm
end

if $0 == __FILE__
  run_example
end
