# -*- mode: ruby -*-
# # vi: set ft=ruby :

require 'fileutils'
Vagrant.require_version ">= 1.6.0"

$num_instances = 1

$coreos_channel="coreos-alpha"
$coreos_version=">= 361.0.0"

$virtualbox_gui = false
$virtualbox_memory = 4096
$virtualbox_cpus = 2

Vagrant.configure("2") do |config|


  config.vm.box = $coreos_channel
  config.vm.box_version = $coreos_version
  config.vm.box_url = "http://" + $coreos_channel + ".release.core-os.net/amd64-usr/current/coreos_production_vagrant.json"

  (1..$num_instances).each do |i|
    config.vm.define vm_name = "node-agent-%02d" % i do |config|
      config.vm.hostname = vm_name

      config.vm.provider :virtualbox do |virtualbox|
        virtualbox.gui = $virtualbox_gui
        virtualbox.memory = $virtualbox_memory
        virtualbox.cpus = $virtualbox_cpus
      end

      ip = "172.17.8.#{i+100}"
      config.vm.network :private_network, ip: ip



      # Provision service with nfs
      #config.vm.synced_folder ".", "/var/lib/node-agent-service", id: "node-agent-service", :nfs => true, :mount_options => ['nolock,vers=3,udp']

      # Provision service with shell
      config.vm.provision :file, :source => ".", :destination => "/tmp/node-agent-service"
      config.vm.provision :shell, :inline => "rm -rf /var/lib/node-agent-service; mv /tmp/node-agent-service /var/lib/node-agent-service", :privileged => true

      config.vm.provision :file, :source => "coreos-userdata", :destination => "/tmp/vagrantfile-user-data"
      config.vm.provision :shell, :inline => "mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/", :privileged => true

    end
  end
end
