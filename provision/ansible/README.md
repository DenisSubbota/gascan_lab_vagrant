# Ansible Provisioning for MySQL/ProxySQL Lab


This directory contains a fully role-based Ansible provisioning system for the lab. It is designed to be run from the monitor node and can provision all nodes (MySQL, backup, restore, ProxySQL, monitor) using a single playbook and reusable roles.

## Structure
- `site.yml` — Main playbook to provision all nodes
- `inventory/` — Example inventory files for the lab
- `roles/` — Ansible roles for:
  - `mysql_install` (MySQL installation and config)
  - `backup` (Backup node setup)
  - `restore` (Restore node setup)
  - `proxysql` (ProxySQL node setup)
  - `monitor` (Monitor node setup)

## Usage
1. SSH into the monitor node.
2. Edit the inventory file as needed.
3. Run the playbook:
   ```sh
   /vagrant/provision/ansible
   sudo ansible-playbook -i inventory/lab.ini site.yml --limit mysql57 -u percona --private-key=/home/percona/.ssh/id_rsa
  
   ```

## Notes
- This system does not affect the existing shell-based provisioning scripts or the Vagrantfile.
- All logic is modularized into roles for clarity and reusability.
- You can run the playbook multiple times; it is idempotent. 