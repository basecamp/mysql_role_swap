require 'vagrant'

# Default to running a test
task :default => :test

# Functional test
desc "Test the code!"
task :test do
  # Startup the environment
  env = Vagrant::Environment.new
  puts "Configuring vagrant instances..."
  env.cli("up")

  if $?.exitstatus == 0
    # Run the script against vagrant
    exec("./mysql_role_swap.rb -c cluster.yml -f")
  else
    puts "Failed to start the vagrant environment!"
  end
end

desc "Shutdown the vagrant environment"
task :stop do
  # Startup the environment
  env = Vagrant::Environment.new
  puts "Stopping vagrant instances..."
  env.cli("halt")
end

desc "Remove any lingering vagrant instances"
task :clean do
  # Startup the environment
  env = Vagrant::Environment.new
  puts "Stopping vagrant instances..."
  env.cli("halt")
  puts "Deleting vagrant instances..."
  env.cli("destroy", "--force")
end
