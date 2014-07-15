#!/usr/bin/env ruby
#
# MySQL Switch Roles
# Copyright 37signals, 2012
# Authors: John Williams (john@37signals.com), Taylor Weibley (taylor@37signals.com), Matthew Kent (matthew@37signals.com)

require 'rubygems'
require 'mysql'
require 'active_record'
require 'statemachine'
require 'colorize'
require 'choice'

PROGRAM_VERSION = "0.12"

MYSQL_BASE_PATH = "/u/mysql"

FORCE = false

EXIT_OK = 0
EXIT_WARNING = 1
EXIT_CRITICAL = 2
EXIT_UNKNOWN = 3

Choice.options do

  header ''
  header 'Specific options:'

  option :config do
    short '-c'
    long '--config=PATH'
    desc 'Path to cluster.yml'
    cast String
  end

  option :database do
    short '-d'
    long '--database=NAME'
    desc 'Name of database'
    cast String
  end

  option :check do
    short '-s'
    long '--check'
    desc 'Just run the initial checks.'
  end

  option :force do
    short '-f'
    long '--force'
    desc 'Do not ask to verify, just fail over.'
    action do
      FORCE = true
    end
  end


  separator ''
  separator 'Common options: '

  option :version do
    short '-v'
    long '--version'
    desc 'Show version'
    action do
      puts "MySQL Role Swap v#{PROGRAM_VERSION}"
      exit
    end
  end
end

CHOICES = Choice.choices

if CHOICES[:database]
  CONFIG = YAML::load(IO.read("#{MYSQL_BASE_PATH}/#{CHOICES[:database].downcase}/config/cluster.yml"))
elsif CHOICES[:config]
  CONFIG = YAML::load(IO.read(CHOICES[:config]))
else
  puts "Usage: #{File.basename(__FILE__)} { -c config_file | -d database_name } [-fsv]"
  exit EXIT_WARNING
end

FLOATING_IP = CONFIG['floating_ip']
FLOATING_IP_CIDR = CONFIG['floating_ip_cidr']
MASTER_IPMI_ADDRESS = CONFIG['master_ipmi_address']

if CONFIG['ssh_username']
  SSH_USERNAME = "-l #{CONFIG['ssh_username']}"
else
  SSH_USERNAME = ""
end
if CONFIG['ssh_key_file']
  SSH_KEY_FILE = "-i #{CONFIG['ssh_key_file']}"
else
  SSH_KEY_FILE = ""
end
SSH_OPTIONS = "#{SSH_USERNAME} #{SSH_KEY_FILE}"


ActiveRecord::Base.configurations = CONFIG

class DatabaseOne < ActiveRecord::Base

  def self.database
    "database_one"
  end

  establish_connection(self.database)

  def self.config
    CONFIG[database]
  end

  def self.floating_dev
    if self.config['floating_dev']
      self.config['floating_dev']
    else
      "bond0"
    end
  end

  def self.role
   if self.mysql_rep_role == "master" && self.ip_role == "master"
    "master"
  else
    "slave"
   end
 end

 def self.mysql_rep_role
   if self.connection.execute("SHOW SLAVE STATUS").fetch_hash.nil?
    "master"
  else
    "slave"
   end
 end

 def self.ip_role
   `ssh #{SSH_OPTIONS} #{self.config['host']} 'sudo /sbin/ip addr | grep #{FLOATING_IP}#{FLOATING_IP_CIDR}'`
   if $?.exitstatus == 0
    "master"
  else
    "slave"
   end
 end

 def self.add_vip
   if self.config['host'] == `hostname`.chomp
     `sudo /sbin/ip addr add #{FLOATING_IP}#{FLOATING_IP_CIDR} dev #{self.floating_dev}`
    else
     `ssh #{SSH_OPTIONS} #{self.config['host']} 'sudo /sbin/ip addr add #{FLOATING_IP}#{FLOATING_IP_CIDR} dev #{self.floating_dev}'`
   end
   if $?.exitstatus == 0
    true
  else
    false
   end
 end

 def self.remove_vip
   if self.config['host'] == `hostname`.chomp
     `sudo /sbin/ip addr del #{FLOATING_IP}#{FLOATING_IP_CIDR} dev #{self.floating_dev}`
   else
     `ssh #{SSH_OPTIONS} #{self.config['host']} 'sudo /sbin/ip addr del #{FLOATING_IP}#{FLOATING_IP_CIDR} dev #{self.floating_dev}'`
   end
   if $?.exitstatus == 0
    true
  else
    false
   end
 end

 def self.arping_path
   `ssh #{SSH_OPTIONS} #{self.config['host']} 'sudo /sbin/arping -V 2> /dev/null'`
   if $?.exitstatus == 0
     return "/sbin/arping"
   end
   `ssh #{SSH_OPTIONS} #{self.config['host']} 'sudo /usr/bin/arping -V 2> /dev/null'`
   if $?.exitstatus == 0
     return "/usr/bin/arping"
   end
 end

 def self.arping
   if self.config['host'] == `hostname`.chomp
     `sudo #{self.arping_path} -U -c 4 -I #{self.floating_dev} #{FLOATING_IP}`
   else
     `ssh #{SSH_OPTIONS} #{self.config['host']} 'sudo #{self.arping_path} -U -c 4 -I #{self.floating_dev} #{FLOATING_IP}'`
   end
   if $?.exitstatus == 0
    true
  else
    false
   end
 end

 def self.database?
   unless self.connection.execute("SHOW DATABASES LIKE '#{self.config['primary_database']}'").fetch_hash.nil?
     true
   else
     false
   end
 end

  def self.read_only?
   if self.connection.execute("SHOW GLOBAL VARIABLES LIKE 'read_only';").fetch_hash["Value"] == "ON"
      true
    else
      false
   end
 end

 def self.version
    self.connection.execute("SELECT version();").fetch_hash["version()"]
 end

 def self.max_connections
    self.connection.execute("SHOW GLOBAL VARIABLES LIKE 'max_connections';").fetch_hash["Value"]
 end

 def self.hostname
    name = `host #{self.config['host']}`
    if $?.exitstatus == 0
      name.split(" ").last.gsub(/.\Z/, "").split(".").first
    else
      self.config['host']
    end
  end

  def self.print_info
    printf "%-22s: %s:%d\n", self.role.capitalize, self.hostname, self.config['port']
    puts "MySQL Replication Role: #{self.mysql_rep_role}"
    puts "Floating IP Role      : #{self.ip_role}"
    puts "Floating IP Interface : #{self.floating_dev}"
    puts "MySQL Version         : [#{self.version}]"
    puts "Read-Only             : #{self.read_only?}"
    puts "Arping Path           : #{self.arping_path}\n\n"
  end

end

class DatabaseTwo < ActiveRecord::Base

  def self.database
    "database_two"
  end

  establish_connection(self.database)

  def self.config
    CONFIG[database]
  end

  def self.floating_dev
    if self.config['floating_dev']
      self.config['floating_dev']
    else
      "bond0"
    end
  end
  def self.role
   if self.mysql_rep_role == "master" && self.ip_role == "master"
    "master"
  else
    "slave"
   end
 end

 def self.mysql_rep_role
   if self.connection.execute("SHOW SLAVE STATUS").fetch_hash.nil?
    "master"
  else
    "slave"
   end
 end

 def self.ip_role
   `ssh #{SSH_OPTIONS} #{self.config['host']} 'sudo /sbin/ip addr | grep -q #{FLOATING_IP}#{FLOATING_IP_CIDR}'`
   if $?.exitstatus == 0
    "master"
  else
    "slave"
   end
 end

 def self.add_vip
   if self.config['host'] == `hostname`.chomp
     `sudo /sbin/ip addr add #{FLOATING_IP}#{FLOATING_IP_CIDR} dev #{self.floating_dev}`
    else
     `ssh #{SSH_OPTIONS} #{self.config['host']} 'sudo /sbin/ip addr add #{FLOATING_IP}#{FLOATING_IP_CIDR} dev #{self.floating_dev}'`
   end
   if $?.exitstatus == 0
    true
  else
    false
   end
 end

 def self.remove_vip
   if self.config['host'] == `hostname`.chomp
     `sudo /sbin/ip addr del #{FLOATING_IP}#{FLOATING_IP_CIDR} dev #{self.floating_dev}`
   else
     `ssh #{SSH_OPTIONS} #{self.config['host']} 'sudo /sbin/ip addr del #{FLOATING_IP}#{FLOATING_IP_CIDR} dev #{self.floating_dev}'`
   end
   if $?.exitstatus == 0
    true
  else
    false
   end
 end

 def self.arping_path
   `ssh #{SSH_OPTIONS} #{self.config['host']} 'sudo /sbin/arping -V 2> /dev/null'`
   if $?.exitstatus == 0
     return "/sbin/arping"
   end
   `ssh #{SSH_OPTIONS} #{self.config['host']} 'sudo /usr/bin/arping -V 2> /dev/null'`
   if $?.exitstatus == 0
     return "/usr/bin/arping"
   end
 end

 def self.arping
   if self.config['host'] == `hostname`.chomp
     `sudo #{self.arping_path} -U -c 4 -I #{slef.floating_dev} #{FLOATING_IP}`
   else
     `ssh #{SSH_OPTIONS} #{self.config['host']} 'sudo #{self.arping_path} -U -c 4 -I #{self.floating_dev} #{FLOATING_IP}'`
   end
   if $?.exitstatus == 0
    true
  else
    false
   end
 end

 def self.database?
   unless self.connection.execute("SHOW DATABASES LIKE '#{self.config['primary_database']}'").fetch_hash.nil?
     true
   else
     false
   end
 end

  def self.read_only?
   if self.connection.execute("SHOW GLOBAL VARIABLES LIKE 'read_only';").fetch_hash["Value"] == "ON"
      true
    else
      false
   end
 end

 def self.version
    self.connection.execute("SELECT version();").fetch_hash["version()"]
 end

 def self.max_connections
    self.connection.execute("SHOW GLOBAL VARIABLES LIKE 'max_connections';").fetch_hash["Value"]
 end

 def self.hostname
    name = `host #{self.config['host']}`
    if $?.exitstatus == 0
      name.split(" ").last.gsub(/.\Z/, "").split(".").first
    else
      self.config['host']
    end
  end

  def self.print_info
    printf "%-22s: %s:%d\n", self.role.capitalize, self.hostname, self.config['port']
    puts "MySQL Replication Role: #{self.mysql_rep_role}"
    puts "Floating IP Role      : #{self.ip_role}"
    puts "Floating IP Interface : #{self.floating_dev}"
    puts "MySQL Version         : [#{self.version}]"
    puts "Read-Only             : #{self.read_only?}"
    puts "Arping Path           : #{self.arping_path}\n\n"
  end

end

class MysqlSwitchRoleContext

  attr_accessor :statemachine

  def initialize
    #Missing cluster config info.
    if (FLOATING_IP == nil || FLOATING_IP_CIDR == nil)
      puts "\nCluster config is missing floating IP information.\n".red
      exit EXIT_WARNING
    elsif(MASTER_IPMI_ADDRESS == nil)
      puts "\nMaster IPMI Address missing from cluster.yml file.\n".red
      exit EXIT_WARNING
    end

    # Gather info.
    databases = [DatabaseOne, DatabaseTwo]
    puts "\nCurrent Cluster Configuration:\n\n".white
    puts "Floating IP           : ".white + FLOATING_IP + "\n\n"

    databases.sort {|x,y| x.role <=> y.role}.each do |db|
      begin
        db.print_info

        if db.role == "slave"
          unless @slave
            @slave = db
          else
            puts "Both of your servers look to have the slave role. Please check your configuration.".red
            exit EXIT_WARNING
          end
        elsif db.role == "master"
          unless @master
            @master = db
          else
            puts "Both of your servers look to have the master role. Please check your configuration.".red
            exit EXIT_WARNING
          end
        end
      rescue Mysql::Error
        puts "Got mysql error".red
      end
    end

    if @slave && ! @master
      puts "Master:\nUnavailable. Which is probably why you are here.\n\n".red
      puts "You should probably stonith the master if you haven't already!\n".red
      puts "Try ipmitool -I lan -U signal -H #{MASTER_IPMI_ADDRESS} -a chassis power off -force\n\n".red
      unless confirm?("You ready to switch the roles without master")
        exit EXIT_WARNING
      end
    elsif ! @slave && @master
      puts "The Slave is down so there is nothing to fail to.".red
      exit EXIT_WARNING
    elsif ! @master && ! @slave
      puts "Master:\n Unavailable.\n\n".red
      puts "Slave:\n Unavailable.\n\n".red
      puts "There are no available servers. Please check your configurations.".red
      exit EXIT_WARNING
    end
  end

  def check_max_connections
    if @master.max_connections.to_i == @slave.max_connections.to_i
      @statemachine.max_connections_ok
    else
      puts "Master and slave need to have same max_connections value....Fail.".red
      @statemachine.max_connections_fail
    end
  end

  def check_configuration
    if (! @master || ! @master.read_only?) && @slave.read_only?
       if (! @master || @master.database?) && @slave.database?
         if @master.arping_path && @slave.arping_path
           @statemachine.good_config
         else
           puts "\nPreflight Checks:\n\n".white
           puts "Can't find the arping binary on one of the MySQL servers. Please verify that your configuration is correct.".red
           @statemachine.bad_config
           exit EXIT_WARNING
         end
       else
         puts "\nPreflight Checks:\n\n".white
         puts "MySQL Configuration....Fail. The primary database does not exist on both MySQL servers. Please verify that your configuration is correct.".red
         @statemachine.bad_config
         exit EXIT_WARNING
       end
    else
       puts "\nPreflight Checks:\n\n".white
       puts "MySQL Configuration....Fail. The read/write states of the master or slave are wrong.".red
       @statemachine.bad_config
       exit EXIT_WARNING
    end
  end

  def check_replicaton
    if replication_ok?(@slave) == true
       @statemachine.replication_ready
    else
       @statemachine.replication_not_ready
       exit EXIT_WARNING
    end
  end

  def preflight_verify
    @statemachine.cluster_ready
  end

  def prompt_user
    unless CHOICES[:check].nil?
      exit EXIT_OK
    else
      if FORCE == true || confirm?("You ready to switch the roles")
        puts "\n\n"
        @statemachine.start_switching_roles
      end
    end
  end

  def pause_traffic
    `touch /tmp/hold`
    sleep 1
    puts "Paused proxy traffic....OK"
    @statemachine.traffic_paused
  end

  def remove_vip
    if @master
      if @master.remove_vip
        puts "Remove VIP from Master....OK"
        @statemachine.next_set_read_only
      else
        puts "Remove VIP from Master....Fail"
        if confirm?("Do you want to continue (probably not)")
          @statemachine.next_set_read_only
        else
          @statemachine.failed_to_remove_vip
        end
      end
    else
      puts "Remove VIP from Master....DOWN"
      @statemachine.next_set_read_only
    end
  end

  def set_read_only
    if @master
      @master.connection.execute("SET GLOBAL read_only = ON")
      puts "Set Master to Read-Only....OK"
      @statemachine.verify_master_binlog_position
    else
      puts "Set Master to Read-Only....DOWN"
      @statemachine.verify_master_binlog_position
    end
  end

  def verify_master_binlog_position
    if @master
      puts "Checking binlog position a couple times.....WAITING"
      status_one_position = show_master_binlog_position(@master)
      status_one_file = show_master_binlog_file(@master)
      sleep 3
      status_two_position = show_master_binlog_position(@master)
      status_two_file = show_master_binlog_file(@master)

      if status_one_position == status_two_position && status_one_file == status_two_file
        puts "Master Binlog Position Verify....OK"
        @statemachine.get_slave_binlog_status
      else
        @statemachine.master_is_being_written_to
        exit EXIT_WARNING
      end
    else
      puts "Master Binlog Position Verify....DOWN"
      @statemachine.get_slave_binlog_status
    end

  end

  def get_slave_binlog_status
    #Get Slave Binlog Position, incase something fails you will know where to start the slave.

    @slave_binlog_position = show_master_binlog_position(@slave)
    @slave_binlog_file = show_master_binlog_file(@slave)

    puts "\nSlave (master-to-be) binlog info:".white
    puts "\nPosition....#{@slave_binlog_position}\nFile....#{@slave_binlog_file}"
    puts "Copy&Paste Emergency Command....CHANGE MASTER TO MASTER_HOST='#{@slave.config['host']}', MASTER_PORT=#{@slave.config['port']}, MASTER_USER='slave', MASTER_PASSWORD='#{@slave.config['slave_password']}',MASTER_LOG_FILE='#{@slave_binlog_file}', MASTER_LOG_POS=#{@slave_binlog_position}\n\n".blue
    @statemachine.promote_slave_to_master
  end

  def promote_slave_to_master
    @slave.connection.execute("STOP SLAVE;")
    if @slave.version =~ /^5.5/
      @slave.connection.execute("RESET SLAVE ALL;")
    else
      @slave.connection.execute("CHANGE MASTER TO master_host='';")
    end
    @slave.connection.execute("SET GLOBAL read_only='OFF'")
    puts "Switching Roles (Cont.)\n".white
    puts "Promote slave and make it read-write....OK"
    @statemachine.add_vip_to_slave
  end

  def add_vip_to_slave
    if @slave.add_vip
      puts "Add VIP to new Master (existing slave)....OK"
      @statemachine.do_arping
    else
      puts "Add VIP to new Master (existing slave)....Fail"
      @statemachine.failed_to_add_vip
      exit EXIT_WARNING
    end
  end

  def arping_from_slave
    if @slave.arping
      puts "Arping 4x....OK"
      @statemachine.demote_old_master_to_slave
    else
      puts "Arping 4x....Fail"
      @statemachine.failed_to_arping
    end
  end

  def unpause_traffic
    `rm -rf /tmp/hold`
    sleep 1
    puts "Unpaused proxy traffic....OK"
    @statemachine.traffic_unpaused
  end

  def demote_old_master_to_slave
    change_master_command = "CHANGE MASTER TO MASTER_HOST='#{@slave.config['host']}', MASTER_PORT=#{@slave.config['port']}, MASTER_USER='slave', MASTER_PASSWORD='#{@slave.config['slave_password']}',MASTER_LOG_FILE='#{@slave_binlog_file}', MASTER_LOG_POS=#{@slave_binlog_position}"
    if @master
      @master.connection.execute(change_master_command)
      @master.connection.execute("START SLAVE")
      puts "Demote old master to slave....OK"
    else
      puts "Demote old master to slave....DOWN".red
      puts "Here is how to manually get the slave up to speed when it comes back up."
      puts "****"
      puts "SET GLOBAL read_only = ON;"
      puts "#{change_master_command};"
      puts "START SLAVE;"
      puts "****"
    end
    @statemachine.verify_slave_catches_up
  end

  def verify_slave_catches_up
    if @master
      case replication_ok?(@master)
      when true
        puts "Slave up to date....OK\n\n"
        @statemachine.check_read_write_states
      else
        puts "Slave is #{replication_seconds_behind(@master)} seconds behind.....WAITING\n\n"
        sleep 10
        verify_slave_catches_up
      end
    else
      puts "Slave up to date....DOWN"
      @statemachine.check_read_write_states
    end
  end

  def check_read_write_states
    if @master
      if ! @slave.read_only? && @master.read_only?
         @statemachine.done
      else
         @statemachine.verify_fail
         exit EXIT_WARNING
      end
    else
      puts "Read-Write States Verify....DOWN".red
      @statemachine.done
    end
  end

  def done
    puts "You have successfully switched roles!\n".white
    puts "\nNew Cluster Configuration:\n\n".white
    databases = [DatabaseOne, DatabaseTwo]
    databases.sort {|x,y| x.role <=> y.role}.each do |db|
      begin
        db.print_info
      rescue
      end
    end
  end

  def confirm?(question)
    $stdout.print question + "? (Y/N) "
    answer = $stdin.readline.chomp!
    case answer
    when "Y", "y"
      true
    when "N", "n"
      @statemachine.exit
      exit 3
    else
      puts "This is a Y or N question. OK?"
      confirm?(question)
    end
  end

  def show_master_binlog_position(db)
    db.connection.execute("SHOW MASTER STATUS").fetch_hash['Position']
  end
  def show_master_binlog_file(db)
    status = db.connection.execute("SHOW MASTER STATUS").fetch_hash['File']
  end

  def replication_ok?(db)
    #if things are broken in mm we might not have replication on the "slave" which causes this no method error
    begin
      if db.connection.execute("SHOW SLAVE STATUS").fetch_hash["Seconds_Behind_Master"].to_i == 0
        true
      end
    rescue NoMethodError
      false
    end
  end

  def replication_seconds_behind(db)
    db.connection.execute("SHOW SLAVE STATUS").fetch_hash["Seconds_Behind_Master"].to_i
  end

end

mysql_switch_role = Statemachine.build do
  state :unknown do
    event :bad_config, :configuration_fail
    event :good_config, :configuration_ok
    on_entry :check_configuration
  end
  state :configuration_ok do
    event :max_connections_ok, :max_connections_ok
    event :max_connections_fail, :max_connections_fail
    on_entry :check_max_connections
  end
  state :max_connections_ok do
    event :replication_not_ready, :replication_not_ready, Proc.new { puts "Checking MySQL Replication....Replicaiton is NOT up to date, or slave is not running! Please catch up before changing roles.".red }
    event :replication_ready, :preflight_verify
    on_entry :check_replicaton
  end
  state :preflight_verify do
    event :cluster_ready, :cluster_ready
    on_entry :preflight_verify
  end
  state :cluster_ready do
    event :start_switching_roles, :pause_traffic, Proc.new { puts "Switching Roles:\n\n".white }
    event :exit, :exit, Proc.new { puts "\nFAIL: We are SO done here. You said NO.\n" }
    on_entry :prompt_user
  end
  state :pause_traffic do
    event :traffic_paused, :switch_roles
    on_entry :pause_traffic
  end
  state :switch_roles do
    event :next_set_read_only, :do_set_read_only
    event :failed_to_remove_vip, :vip_removal_fail, Proc.new { puts "Failed to remove VIP from master....FAIL".red}
    on_entry :remove_vip
  end
  state :do_set_read_only do
    event :verify_master_binlog_position, :verify_master_binlog_position
    on_entry :set_read_only
  end
  state :verify_master_binlog_position do
    event :master_is_being_written_to, :master_not_ready, Proc.new { puts "Master Binlog Position Verify....FAIL\nThe master is being written to so we can't fail over.".red }
    event :get_slave_binlog_status, :get_slave_binlog_status
    on_entry :verify_master_binlog_position
  end
  state :get_slave_binlog_status do
    event :promote_slave_to_master, :promote_slave_to_master
    on_entry :get_slave_binlog_status
  end
  state :promote_slave_to_master do
    event :add_vip_to_slave, :add_vip_to_slave
    on_entry :promote_slave_to_master
  end
  state :add_vip_to_slave do
    event :do_arping, :do_arping
    event :failed_to_add_vip, :vip_add_fail, Proc.new { puts "Failed to add VIP to slave....FAIL".red}
    on_entry :add_vip_to_slave
  end
  #At some point need to diverge paths here and rollback if this fails.
  #We keep on going because *of course* worked...
  state :do_arping do
    event :demote_old_master_to_slave, :unpause_traffic
    event :failed_to_arping, :vip_arping_fail, Proc.new { puts "Failed to arping 4x from slave....FAIL".red}
    on_entry :arping_from_slave
  end
  state :unpause_traffic do
    event :traffic_unpaused, :demote_old_master_to_slave
    on_entry :unpause_traffic
  end
  state :demote_old_master_to_slave do
    event :verify_slave_catches_up, :verify_slave_catches_up
    on_entry :demote_old_master_to_slave
  end
  state :verify_slave_catches_up do
    event :check_read_write_states, :check_read_write_states
    on_entry :verify_slave_catches_up
  end
  state :check_read_write_states do
    event :verify_fail, :verify_fail, Proc.new { puts "Read-Write States Verify....FAIL".red }
    event :done, :done, :done
    on_entry :check_read_write_states
  end
  context MysqlSwitchRoleContext.new
end
