# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant::Config.run do |config|
  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box     = "CentOS-6.3-x86_64-minimal"
  config.vm.box_url = "https://dl.dropbox.com/u/7225008/Vagrant/#{config.vm.box}.box"

  # Boot with a GUI so you can see the screen. (Default is headless)
  #config.vm.boot_mode = :gui

  #
  # Shared folders
  #
  #config.vm.share_folder("vagrant-configs", "/tmp/vagrant-configs", "vagrant-configs")


  #
  # Provisioning
  #
  config.vm.provision :shell, :inline => 'rpm -q --quiet mysql-server || yum install -y mysql-server'                              # Install mysql-server if it does not exist
  config.vm.provision :shell, :inline => 'service mysqld status >> /dev/null || service mysqld start'                              # Start mysqld if it is not running
  #config.vm.provision :shell, :inline => 'mysql -u root -p rootpw -e "SHOW MASTER STATUS" || mysqladmin -u root password rootpw'  # Set root's password


  #
  # Targets
  #
  config.vm.define :mysql1 do |target_config|
    target_config.vm.host_name = 'test-mysql-1'
    target_config.vm.network :hostonly, "192.168.50.31"
    target_config.vm.provision :shell, :inline => 'if [ ! -L /etc/my.cnf ]; then rm -f /etc/my.cnf && ln -s /vagrant/vagrant-configs/master.cnf /etc/my.cnf && service mysqld restart ; fi'
  end

  config.vm.define :mysql2 do |target_config|
    target_config.vm.host_name = 'test-mysql-2'
    target_config.vm.network :hostonly, "192.168.50.32"
    target_config.vm.provision :shell, :inline => 'if [ ! -L /etc/my.cnf ]; then rm -f /etc/my.cnf && ln -s /vagrant/vagrant-configs/slave.cnf /etc/my.cnf && service mysqld restart ; fi'
  end
end

