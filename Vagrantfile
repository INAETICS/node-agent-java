# -*- mode: ruby -*-
# # vi: set ft=ruby :

require 'fileutils'
Vagrant.require_version ">= 1.6.0"

$instance_name="node-agent-service-%02d"
$instance_ip="172.17.8.2%02d"
$num_instances = 2

$coreos_channel="alpha"
$coreos_name="coreos-" + $coreos_channel 
$coreos_version=">= 361.0.0"

$virtualbox_gui = false
$virtualbox_memory = 2048
$virtualbox_cpus = 2

Vagrant.configure("2") do |config|

  config.vm.box = $coreos_name
  config.vm.box_version = $coreos_version
  config.vm.box_url = "http://" + $coreos_channel + ".release.core-os.net/amd64-usr/current/coreos_production_vagrant.json"

  (1..$num_instances).each do |i|

    config.vm.define vm_name = $instance_name % i do |config|

      config.vm.hostname = vm_name
      config.vm.network :private_network, ip: $instance_ip % i

      config.vm.provider :virtualbox do |virtualbox|
        # virtualbox.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        # virtualbox.customize ["setextradata", :id, "VBoxInternal/Devices/e1000/0/LUN#0/Config/HostResolverMappings/docker_repository/HostIP", "172.17.8.120"]
        # virtualbox.customize ["setextradata", :id, "VBoxInternal/Devices/e1000/0/LUN#0/Config/HostResolverMappings/docker_repository/HostNamePattern", "dockerregistry"]
        virtualbox.gui = $virtualbox_gui
        virtualbox.memory = $virtualbox_memory
        virtualbox.cpus = $virtualbox_cpus
      end

      # Provision service with nfs
      # config.vm.synced_folder ".", "/mnt/node-agent-service", id: "node-agent-service", :nfs => true, :mount_options => ['nolock,vers=3,udp']

      # Provision service with shell
      # config.vm.provision :file, :source => ".", :destination => "/tmp/node-agent-service"
      # config.vm.provision :shell, :inline => "rm -rf /var/lib/node-agent-service; mv /tmp/node-agent-service /var/lib/node-agent-service", :privileged => true

      config.vm.provision :file, :source => "coreos-userdata", :destination => "/tmp/vagrantfile-user-data"
      config.vm.provision :shell, :inline => "mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/", :privileged => true
    end
  end
end
