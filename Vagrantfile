# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "centos/7"

  # Boot with a GUI so you can see the screen. (Default is headless)
  #config.vm.boot_mode = :gui

  #
  # Targets
  #
  config.vm.define :mysql1 do |target_config|
    target_config.vm.host_name = 'test-mysql-1'
    target_config.vm.provider "virtualbox"
    target_config.vm.network "private_network", ip: "192.168.50.31"
    target_config.vm.provision :shell, :path => 'vagrant-configs/setup.sh', :args => "master"
  end

  config.vm.define :mysql2 do |target_config|
    target_config.vm.host_name = 'test-mysql-2'
    target_config.vm.provider "virtualbox"
    target_config.vm.network "private_network", ip: "192.168.50.32"
    target_config.vm.provision :shell, :path => 'vagrant-configs/setup.sh', :args => "slave"
  end
end
