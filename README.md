# MySQL Replication Lab with Vagrant

This lab provides a fully automated MySQL replication environment using Vagrant and Ubuntu 22.04 VMs. Each node is provisioned with the correct MySQL version, custom configuration, and replication setup. The monitor node is also provisioned for orchestration and management.

## Features
- 4 Ubuntu 22.04 VMs: monitor, mysql57, mysql8, mysql84
- Per-VM resource configuration (memory, CPUs)
- Custom configs for each MySQL node
- Automatic replication setup (5.7 → 8.0 → 8.4)
- Monitor node with Ansible, SSH tools, and public key management
- All nodes on a private network with static IPs/hostnames
- Fully automated provisioning via shell scripts

## Quick Start

1. **Clone this repo and enter the lab directory:**
   ```sh
   cd gascan_lab_docker
   ```

2. **Review and adjust VM resources and order (optional):**
   Edit the `machines` array in the `Vagrantfile` to set per-VM memory, CPUs, and bring-up order:
   ```ruby
   machines = [
     { name: "monitor", ip: "192.168.56.100", provision: "provision/provision_monitor.sh", memory: 6144, cpus: 4, order: 1 },
     { name: "mysql57", ip: "192.168.56.157", provision: "provision/provision_mysql57.sh", memory: 1024, cpus: 2, order: 2 },
     { name: "mysql8", ip: "192.168.56.180", provision: "provision/provision_mysql8.sh", memory: 1024, cpus: 2, order: 3 },
     { name: "mysql84", ip: "192.168.56.184", provision: "provision/provision_mysql84.sh", memory: 1024, cpus: 2, order: 4 }
   ]
   ```

3. **Bring up the lab (serial startup recommended):**
   To ensure correct provisioning order, run:
   ```sh
   vagrant up --no-parallel
   # or, for strict serial startup:
   for vm in monitor mysql57 mysql8 mysql84; do vagrant up $vm; done
   ```

4. **Access VMs:**
   ```sh
   vagrant ssh monitor
   vagrant ssh mysql57
   vagrant ssh mysql8
   vagrant ssh mysql84
   ```

5. **VM Networking:**
   - monitor: 192.168.56.100
   - mysql57: 192.168.56.157
   - mysql8:  192.168.56.180
   - mysql84: 192.168.56.184

6. **Customizing Provisioning:**
   - Edit scripts in `provision/` to change how each VM is set up.
   - Shared scripts/configs are in `/lab_scripts` inside each VM (from `mysql_replication_setup/`).

## Directory Structure
- `Vagrantfile` — Vagrant configuration for the lab
- `provision/` — Provisioning scripts for each VM
- `provision/playbook_monitor.yml` — Ansible playbook for monitor node
- `provision/mysql_users.sql` — MySQL/replication user setup SQL
- `config/` — MySQL configuration files
- `High_level_plan.md` — Advanced scenarios, topology ideas, and manual steps

## How It Works
- Each VM is provisioned with the correct MySQL version and configuration.
- Replication users and monitoring users are created automatically.
- Replication is set up automatically during provisioning.
- The monitor node manages SSH keys and can orchestrate the environment.
- **Environment variables for the `percona` user are set in `.bashrc` by the Ansible playbook. For non-interactive commands, use `sudo -u percona -i <command>` to ensure the environment is loaded.**

## Monitor Node Provisioning & Secrets

The monitor node uses an Ansible playbook for advanced configuration. Secrets (API keys, client identifiers) are now provided via environment variables using a `.env` file placed in the `config/` directory.

1. **Create a `.env` file in the `config/` directory:**
   ```env
   API_KEY=your_api_key_here
   CLIENT_IDENTIFIER=your_client_identifier_here
   ```

2. **Provision the monitor node (automatically done by Vagrant):**
   The provisioning script will source `/vagrant/config/.env` before running the Ansible playbook. If you need to run it manually:
   ```sh
   set -a
   source /vagrant/config/.env
   set +a
   ansible-playbook provision/playbook_monitor.yml
   ```

- The playbook will read `API_KEY` and `CLIENT_IDENTIFIER` from the environment.
- **Do not commit real secrets to version control.**

## Stopping and Cleaning Up
```sh
vagrant halt      # Stop all VMs
vagrant destroy   # Destroy all VMs
```

## Usage Examples

- Connect to MySQL 8.0 node:
  ```sh
  vagrant ssh mysql8
  mysql
  ```

- Check replication status:
  ```sh
  mysql -e 'SHOW SLAVE STATUS\\G'
  ```

## Troubleshooting
- Check provisioning logs in the Vagrant output.
- For custom scripts/configs, edit files in `mysql_replication_setup/`.
- If a VM fails to start, check for duplicate IPs or hostnames in the Vagrantfile.
- If MySQL won't connect, check the config files in `config/` and the logs in `/var/log/mysql/` inside the VM.

## Customization Tips
- To add more VMs, copy and modify an entry in the `machines` array in the Vagrantfile.
- To change MySQL versions, update the provisioning scripts and config files as needed.
- To customize passwords, move them to environment variables or a config file for better security.
- Add `.env` to your `.gitignore` to avoid committing secrets.

## File Overview
| File/Dir                | Purpose                                      |
|------------------------|----------------------------------------------|
| Vagrantfile            | Main Vagrant configuration                   |
| provision/             | All provisioning scripts and configs         |
| provision/playbook_monitor.yml | Ansible playbook for monitor node      |
| provision/mysql_users.sql      | MySQL/replication user setup SQL       |
| config/                | MySQL configuration files                    |
| High_level_plan.md     | Advanced scenarios and topology ideas        |

## Environment Variables and Secrets (.env)

This lab uses a single `.env` file in the `config/` directory to provide environment variables for provisioning, secrets management, and automation. This file is **not** committed to version control and should be created/edited by the user as needed.

**To create a .env file quickly:**
```sh
cat <<EOF > config/.env
USER_PUB_KEY='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDdummykeyhere user@host'
API_KEY=your_api_key_here
CLIENT_IDENTIFIER=your_client_identifier_here
GASCAN_VERSION=v1.30.0
SSH_MS_NAME=lab_name-gascan
CUSTMER_ENV=lab_name_SN-gascan
EOF
```

**Example config/.env file:**
```env
USER_PUB_KEY='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDdummykeyhere user@host'
API_KEY=your_api_key_here
CLIENT_IDENTIFIER=your_client_identifier_here
GASCAN_VERSION=v1.10.0
SSH_MS_NAME=lab_name-gascan
CUSTMER_ENV=lab_name_SN-gascan
```
- `USER_PUB_KEY`: The SSH public key used for provisioning and secure access by the monitor node and/or other automation (replace with your real key).
- `API_KEY`, `CLIENT_IDENTIFIER`: Secrets for the monitor node's Ansible playbook or other automation.
- `GASCAN_VERSION`: Version of the gascan binary to download and use.
- `SSH_MS_NAME`: Custom SSH prompt/monitor name for the monitor node.
- `CUSTMER_ENV`: Environment or customer name for gascan and inventory configuration.

**Usage:**
- The `.env` file is automatically sourced by provisioning scripts and the monitor node's Ansible playbook from `/vagrant/config/.env`.
- To manually source the environment for Ansible or scripts:
  ```sh
  set -a
  source /vagrant/config/.env
  set +a
  ansible-playbook provision/playbook_monitor.yml
  ```
- **Do not commit real secrets to version control.**

---