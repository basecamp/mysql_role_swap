# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant::Config.run do |config|
  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box     = "CentOS-6.3-x86_64-minimal"
  config.vm.box_url = "https://dl.dropbox.com/u/7225008/Vagrant/#{config.vm.box}.box"

  # Boot with a GUI so you can see the screen. (Default is headless)
  #config.vm.boot_mode = :gui


  #
  # Targets
  #
  config.vm.define :mysql1 do |target_config|
    target_config.vm.host_name = 'test-mysql-1'
    target_config.vm.network :hostonly, "192.168.50.31"
    target_config.vm.provision :shell, :path => 'vagrant-configs/setup.sh', :args => "master"
  end

  config.vm.define :mysql2 do |target_config|
    target_config.vm.host_name = 'test-mysql-2'
    target_config.vm.network :hostonly, "192.168.50.32"
    target_config.vm.provision :shell, :path => 'vagrant-configs/setup.sh', :args => "slave"
  end
end

