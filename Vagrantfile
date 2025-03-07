Vagrant.configure("2") do |config|
    # Global settings
    config.vm.provider "virtualbox" do |vb|
      vb.memory = 512
      vb.cpus = 2
      vb.linked_clone = true
      # Uncomment to enable GUI mode for the VM
      # vb.gui = true
    end

    # Define the "monitor" VM
    config.vm.define "monitor" do |pa|
      pa.vm.box = "ubuntu/jammy64" # Set the Ubuntu 22 box   [pa.vm.box = "centos/stream9" # Set the CentOS 9 box]
      pa.vm.box_check_update = false # Disable box version checks for faster provisioning
      pa.vm.hostname = "monitor" # Set hostname for the VM
      pa.vm.network "private_network", ip: "192.168.56.100" # Assign a private network IP
    # Customize resources for the "monitor" VM
        pa.disksize.size = '50GB'  # This option needed plugin  `vagrant plugin install vagrant-disksize`
        pa.vm.provider "virtualbox" do |avm|
            avm.cpus = 4
            avm.memory = 32768 # 32GB of memory for intensive tasks
        end # End customize resources
    # Use Ansible provisioner
        pa.vm.provision "ansible" do |ansible|
            ansible.playbook = "playbook.yml" # Path to the Ansible playbook
        end # End provisioner 
    end # End  monitor node definer

    config.vm.define "node1" do |pa|
        pa.vm.box = "ubuntu/jammy64" # Set the Ubuntu 22 box  [pa.vm.box = "centos/stream9" # Set the CentOS 9 box] ubuntu/focal64 for ubuntu 20.04
        pa.vm.box_check_update = false # Disable box version checks for faster provisioning
        pa.vm.hostname = "node1" # Set hostname for the VM
        pa.vm.network "private_network", ip: "192.168.56.101" # Assign a private network IP
      # Customize resources for the "node1" VM
          pa.disksize.size = '50GB'  # This option needed plugin  `vagrant plugin install vagrant-disksize`
          pa.vm.provider "virtualbox" do |avm|
              avm.cpus = 4
              avm.memory = 4096 # 4Gb of memory for db tasks
          end # End customize resources
      end # End node1 node definer

end #End vagrant configure 