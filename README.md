# MySQL Replication & ProxySQL Cluster Lab (Vagrant)

---

## Table of Contents

1. [Overview](#overview)
2. [Vagrant IP Range Note](#vagrant-ip-range-note)
3. [VM Topology](#vm-topology)
4. [Replication & Cluster Architecture](#replication--cluster-architecture)
5. [Quick Start](#quick-start)
6. [Full Lab Provisioning: Step-by-Step](#full-lab-provisioning-step-by-step)
7. [Configuration & Secrets](#configuration--secrets)
8. [Directory Structure](#directory-structure)
9. [Provisioning System Details](#provisioning-system-details)
10. [Manual Ansible Playbook Usage](#manual-ansible-playbook-usage)
11. [Customization](#customization)
12. [Troubleshooting](#troubleshooting)
13. [Legacy Scripts](#legacy-scripts)
14. [To-Do / Ideas](#to-do--ideas)

---

## Overview

A Vagrant-based lab for MySQL replication (5.7 → 8.0 → 8.4), disaster recovery, and ProxySQL clustering. Features a monitor node for orchestration, dynamic Ansible provisioning, and modular roles for all major components.

---

## Vagrant IP Range Note

> **Important:**  
> Vagrant (with VirtualBox) uses the `192.168.56.x` subnet by default for private networks.  
> **You must use IPs in the `192.168.56.*` range** for all VMs in this lab, or you may encounter networking issues, conflicts, or failures to bring up VMs.  
> - Do not use `10.x.x.x`, `172.x.x.x`, or other subnets unless you have specifically reconfigured VirtualBox host-only adapters.
> - If you need to change the subnet, update both the `Vagrantfile` and all references in the Ansible inventory and config files.
> - If you see errors about "host-only adapter" or "IP already in use", check for conflicts with other Vagrant projects or VirtualBox networks on your system.

---

## VM Topology

| Name           | IP              | Role/Description                                 |
|----------------|-----------------|--------------------------------------------------|
| monitor        | 192.168.56.100  | Orchestration, Ansible, SSH mgmt, gascan         |
| proxysql1      | 192.168.56.101  | ProxySQL cluster node 1                          |
| proxysql2      | 192.168.56.102  | ProxySQL cluster node 2                          |
| mysql57        | 192.168.56.157  | MySQL 5.7 (Source)                               |
| mysql8         | 192.168.56.180  | MySQL 8.0 (Intermediate)                         |
| mysql8backup   | 192.168.56.181  | MySQL 8.0 (Backup, replicates from mysql8)       |
| mysql8restore  | 192.168.56.182  | MySQL 8.0 (Restore node)                         |
| mysql84        | 192.168.56.184  | MySQL 8.4 (Target, main replication endpoint)    |
| mysql84backup  | 192.168.56.185  | MySQL 8.4 (Backup, replicates from mysql84)      |
| mysql84restore | 192.168.56.186  | MySQL 8.4 (Restore node)                         |

---

## Replication & Cluster Architecture

```
mysql57 (Source) → mysql8 (Intermediate) → mysql84 (Target) → mysql84backup (Backup)
```
- `mysql84` is the main replication target, replicating from `mysql8`.
- `mysql84backup` and `mysql8backup` are disaster recovery replicas.
- Restore nodes (`mysql8restore`, `mysql84restore`) are for testing restores.

---

## Quick Start

1. **Clone and enter the lab:**
   ```sh
   git clone <repo-url>
   cd gascan_lab_vagrant
   ```
2. **(Optional) Edit VM resources/order in `Vagrantfile`.**
3. **Create a `.env` file in `config/` (see below).**
4. **Start the lab (serial recommended):**
   ```sh
   vagrant up --no-parallel
   # or strict order:
   for vm in monitor proxysql1 proxysql2 mysql57 mysql8 mysql8backup mysql8restore mysql84 mysql84backup mysql84restore; do vagrant up $vm; done
   ```
5. **SSH into any VM:**
   ```sh
   vagrant ssh monitor   # or any other node
   ```

---

## Full Lab Provisioning: Step-by-Step

1. **Install Prerequisites**
   - Install [Vagrant](https://www.vagrantup.com/downloads) and [VirtualBox](https://www.virtualbox.org/wiki/Downloads) on your host machine.
   - (Optional) Install `git` if you want to clone the repository.

2. **Clone the Repository**
   ```sh
   git clone <repo-url>
   cd gascan_lab_vagrant
   ```

3. **Create the `.env` File**
   - Copy the example below to `config/.env` and fill in your values:
   ```env
   USER_PUB_KEY='ssh-rsa ...yourkey...'
   API_KEY=your_api_key_here
   CLIENT_IDENTIFIER=your_client_identifier_here
   GASCAN_VERSION=v1.30.0
   CUSTOMER_ENV=lab_name-gascan
   # Optional for backup S3 integration:
   S3_BUCKET=s3://your-bucket-name/
   AWS_ACCESS_KEY_ID=your_aws_access_key
   AWS_SECRET_ACCESS_KEY=your_aws_secret_key
   ```
   - The `USER_PUB_KEY` is required for SSH access to all nodes. You can generate one with `ssh-keygen` if needed.

4. **(Optional) Edit VM Resources**
   - Open `Vagrantfile` to adjust CPU, RAM, or VM order as needed for your system.

5. **Bring Up the Lab**
   - Recommended: bring up VMs serially to avoid race conditions:
   ```sh
   vagrant up --no-parallel
   # or strict order:
   for vm in monitor proxysql1 proxysql2 mysql57 mysql8 mysql8backup mysql8restore mysql84 mysql84backup mysql84restore; do vagrant up $vm; done
   ```

6. **Monitor Node Bootstrapping**
   - The monitor node will install Ansible and run the Ansible playbook automatically as part of its provisioning script.
   - All other nodes will be prepared for Ansible by their shell provisioners.

7. **(Optional) Run the Playbook Manually**
   - SSH into the monitor node:
   ```sh
   vagrant ssh monitor
   cd /vagrant/provision/ansible
   sudo ansible-playbook -i inventory/lab site.yml
   ```
   - You can use `--limit` to target specific groups or hosts (see section below).

8. **Access the Lab**
   - SSH into any node with `vagrant ssh <nodename>`.
   - MySQL, ProxySQL, and all tools are pre-configured and ready for testing.

9. **Cleanup**
   - To stop all VMs:
     ```sh
     vagrant halt
     ```
   - To destroy all VMs:
     ```sh
     vagrant destroy
     ```

**Tip:** You can re-run the Ansible playbook at any time from the monitor node to re-apply or update configuration.

---

## Configuration & Secrets

- `config/.env`: Main environment file for secrets and dynamic config. Required for monitor provisioning.
- `config/mysql_users.sql`: SQL for creating the `percona` user and grants on all MySQL nodes.
- `config/.vagrant_profile`: Customizes the vagrant user's shell environment.
- `config/monitor_id_rsa.pub`: Public key for monitor node, used for SSH setup.

---

## Directory Structure

- `Vagrantfile` — VM definitions and provisioning logic.
- `provision/` — All provisioning scripts and Ansible roles.
  - `provision_monitor.sh` — Monitor node bootstrap and Ansible trigger.
  - `percona_user_ssh_setup.sh` — Percona user and SSH setup for all nodes.
  - `ansible/` — Ansible playbooks, roles, inventory, and group_vars.
  - `legacy_provision_scripts/` — Old shell scripts for reference.
- `config/` — MySQL/ProxySQL config, secrets, and .env file.

---

## Provisioning System Details

- **Vagrantfile:** Defines all VMs, their resources, and provisioning scripts.
- **Provisioning Scripts:** 
  - `provision_monitor.sh`: Installs Ansible and runs the monitor Ansible role.
  - `percona_user_ssh_setup.sh`: Sets up the `percona` user, SSH keys, and sudo on all MySQL/ProxySQL nodes.
  - `legacy_provision_scripts/`: Contains older, now mostly unused, shell scripts for reference.
- **Ansible Structure:**
  - `provision/ansible/site.yml`: Main playbook, runs all roles.
  - `provision/ansible/inventory/lab`: Inventory file, with groupings for monitors, MySQL, ProxySQL, backups, restores.
  - `provision/ansible/group_vars/`: Group variables for each host group.
  - `provision/ansible/roles/`: Modular roles for:
    - `monitor`: Monitor node setup, gascan, .env parsing, SSH, etc.
    - `mysql_install`: MySQL installation and configuration.
    - `backup`: Backup node setup, S3 integration, GPG, cron.
    - `restore`: Restore node setup, config templating, GPG, S3/SSH.
    - `replication`: Replication setup and management.
    - `proxysql`: ProxySQL cluster setup, dynamic MySQL backend discovery.
    - `collect_restore_pubkeys`: Collects restore node SSH keys for backup nodes.

---

## Manual Ansible Playbook Usage

Once the monitor node is provisioned and you have SSH access to it, you can run the Ansible playbook at any time to re-provision or update any part of the lab.

**Basic usage:**
```sh
sudo ansible-playbook -i inventory/lab.ini site.yml --limit <group_or_host>
```

**Examples:**
- Run all roles for all nodes:
  ```sh
  sudo ansible-playbook -i inventory/lab.ini site.yml
  ```
- Run only the monitor role:
  ```sh
  sudo ansible-playbook -i inventory/lab.ini site.yml --limit monitors
  ```
- Run only the backup role for backup nodes:
  ```sh
  sudo ansible-playbook -i inventory/lab.ini site.yml --limit backups
  ```
- Run a specific role for a specific host:
  ```sh
  sudo ansible-playbook -i inventory/lab.ini site.yml --limit mysql8
  ```

**Notes:**
- You must run as `sudo` (or as the `percona` user) for full permissions.
- The inventory file is at `/vagrant/provision/ansible/inventory/lab.ini`.
- You can use `--tags` or `--skip-tags` to run only certain parts of the playbook.
- The playbook is idempotent: you can run it multiple times safely.

---

## Customization

- Add/modify VMs in `Vagrantfile`.
- Edit provisioning scripts in `provision/` or Ansible roles in `provision/ansible/roles/`.
- Change passwords/secrets in `.env` (never commit real secrets).
- Add or configure backup/restore nodes as needed.
- Extend Ansible roles for new features or custom logic.

---

## Troubleshooting

- Check Vagrant output for provisioning errors.
- Check `/var/log/mysql/` or `/var/log/proxysql/` inside VMs.
- If a VM fails to start, check for duplicate IPs/hostnames in `Vagrantfile`.
- If you can't SSH, check your `.env` public key and Vagrant status.
- For Ansible errors, check the monitor node's `/var/log/ansible.log` (if enabled).

---

## Legacy Scripts

- `provision/legacy_provision_scripts/`: Contains old shell scripts for reference. All new logic should use Ansible roles.

---

## To-Do / Ideas

- Instead of using bash provisioning, change to ansible provision
- Deploy auto-gascan update binary
- pxc 3 instance 8.0 (replicas of 57)
- Basic setup with PD alerting DMS etc
- Orchestrator configuration
- VIP over db nodes
- VIP over proxysql node
- Backup node (Auto configuration)
- Restore instance
- Consul DNS
- mysql84 should have 2 mysql instances on a host
- Multi-source replication: use 8.4 multiple instances for this purpose (8.4 is a replica of 8.4)

---