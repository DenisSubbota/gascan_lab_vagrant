Vagrant.configure("2") do |config|
  # VM definitions with per-VM resources and bring-up order
  # Set :order to control the order in which VMs are defined and brought up
  machines = [
    { name: "monitor", ip: "192.168.56.100", provision: "provision/provision_monitor.sh", memory: 6144, cpus: 4, order: 1 },
    { name: "proxysql1", ip: "192.168.56.101", provision: "provision/percona_user_ssh_setup.sh", memory: 512, cpus: 1, order: 2 },
    { name: "proxysql2", ip: "192.168.56.102", provision: "provision/percona_user_ssh_setup.sh", memory: 512, cpus: 1, order: 3 },
    { name: "mysql57", ip: "192.168.56.157", provision: "provision/percona_user_ssh_setup.sh", memory: 1024, cpus: 2, order: 4 },
    { name: "mysql8", ip: "192.168.56.180", provision: "provision/percona_user_ssh_setup.sh", memory: 1024, cpus: 2, order: 5 },
    { name: "mysql8backup", ip: "192.168.56.181", provision: "provision/percona_user_ssh_setup.sh", memory: 1024, cpus: 2, order: 6 },
    { name: "mysql8restore", ip: "192.168.56.182", provision: "provision/percona_user_ssh_setup.sh", memory: 1024, cpus: 2, order: 7 },
    { name: "mysql84", ip: "192.168.56.184", provision: "provision/percona_user_ssh_setup.sh", memory: 1024, cpus: 2, order: 8 },
    { name: "mysql84backup", ip: "192.168.56.185", provision: "provision/percona_user_ssh_setup.sh", memory: 1024, cpus: 2, order: 9 },
    { name: "mysql84restore", ip: "192.168.56.186", provision: "provision/percona_user_ssh_setup.sh", memory: 1024, cpus: 2, order: 10 }
  ]

  # Sort machines by :order before defining VMs
  machines.sort_by { |m| m[:order] }.each do |machine|
    config.vm.define machine[:name] do |node|
      node.vm.box = "ubuntu/jammy64"
      node.vm.hostname = machine[:name]
      node.vm.network "private_network", ip: machine[:ip]
      node.vm.synced_folder "./provision", "/vagrant/provision", create: true
      node.vm.synced_folder "./config", "/vagrant/config", create: true
      node.vm.provider "virtualbox" do |vb|
        vb.memory = machine[:memory]
        vb.cpus = machine[:cpus]
      end
      node.vm.provision "shell", path: machine[:provision]
    end
  end
end

# === SERIAL STARTUP INSTRUCTIONS ===
# To enforce serial bring-up, run:
#   vagrant up --no-parallel
# Or use the following helper command in your shell:
#   for vm in monitor proxysql1 proxysql2 mysql57 mysql8 mysql8backup mysql8restore mysql84 mysql84backup mysql84restore; do vagrant up $vm; done
# This will bring up each VM in the order specified in the machines array. 