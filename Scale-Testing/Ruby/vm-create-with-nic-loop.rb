require 'azure_mgmt_resources'
require 'azure_mgmt_network'
require 'azure_mgmt_storage'
require 'azure_mgmt_compute'

# RG_LOC = 'eastus2'
# GROUP_NAME = 'melitest'
# VNET_RG = 'melinet'
# VNET_NAME = 'melinet'
# SUBNET_NAME = 'melisub'

RG_LOC = ARGV[0]
VNET_RG = ARGV[1]
VNET_NAME = ARGV[2]
SUBNET_NAME = ARGV[3]
VM_COUNT = ARGV[4].to_i
GROUP_NAME = ARGV[5]

Storage = Azure::Storage::Profiles::Latest::Mgmt
Network = Azure::Network::Profiles::Latest::Mgmt
Compute = Azure::Compute::Profiles::Latest::Mgmt
Resources = Azure::Resources::Profiles::Latest::Mgmt

StorageModels = Storage::Models
NetworkModels = Network::Models
ComputeModels = Compute::Models
ResourceModels = Resources::Models

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

  def print_item(resource)
    resource.instance_variables.sort.each do |ivar|
      str = ivar.to_s.gsub /^@/, ''
      if resource.respond_to? str.to_sym
        puts "\t\t#{str}: #{resource.send(str.to_sym)}"
      end
    end
    puts "\n\n"
  end

  # Grab network data for creating network interface
  print_item subnet = network_client.subnets.get(VNET_RG, VNET_NAME, SUBNET_NAME)

  start = Time.now
  count = 0
  arr = []
  
  # Loop creates number of VMs based on VM_COUNT input 
  VM_COUNT.times do |i|
      arr[i] = Thread.new {
         Thread.current["mycount"] = count
         number = count
         count += 1
         vm_name= "testvm#{number}"

  print_item nic = network_client.network_interfaces.create_or_update(
    GROUP_NAME,
    "sample-ruby-nic-#{number}",
    NetworkModels::NetworkInterface.new.tap do |interface|
        interface.location = RG_LOC
        interface.ip_configurations = [
            NetworkModels::NetworkInterfaceIPConfiguration.new.tap do |nic_conf|
                nic_conf.name = "nic-#{number}"
                nic_conf.private_ipallocation_method = NetworkModels::IPAllocationMethod::Dynamic
                nic_conf.subnet = subnet
            end
        ]
    end
  )

vm_create_params = ComputeModels::VirtualMachine.new.tap do |vm|
    vm.location = RG_LOC
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
        hardware.vm_size = ComputeModels::VirtualMachineSizeTypes::StandardA2
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

# Quick calculation on how long it took to deploy VMs.
finish = Time.now
puts "Time elapsed: #{((finish - start)/60).truncate(2)} minutes have passed."
puts

}
end

arr.each {|t| t.join; print t["mycount"], ", " }
puts "count = #{count}"