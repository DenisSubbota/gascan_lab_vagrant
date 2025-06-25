# MySQL Replication & ProxySQL Cluster Lab (Vagrant)

## What is this?
A Vagrant-based lab for MySQL replication (5.7 → 8.0 → 8.4 → 8.4backup) and a 2-node ProxySQL cluster, with a monitor node for orchestration. All provisioning is automated.

## VMs & IPs
| Name           | IP              | Role                    |
|----------------|-----------------|-------------------------|
| monitor        | 192.168.56.100  | Orchestration, Ansible, SSH mgmt |
| proxysql1      | 192.168.56.101  | ProxySQL cluster node 1          |
| proxysql2      | 192.168.56.102  | ProxySQL cluster node 2          |
| mysql57        | 192.168.56.157  | MySQL 5.7 (Source)              |
| mysql8         | 192.168.56.180  | MySQL 8.0 (Intermediate)        |
| mysql84        | 192.168.56.184  | MySQL 8.4 (Target)              |
| mysql84backup  | 192.168.56.255  | MySQL 8.4 (Backup)              |

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
   for vm in monitor proxysql1 proxysql2 mysql57 mysql8 mysql84 mysql84backup; do vagrant up $vm; done
   ```
5. **SSH into any VM:**
   ```sh
   vagrant ssh monitor   # or any other node
   ```

## Replication Chain
```
mysql57 (Source) → mysql8 (Intermediate) → mysql84 (Target) → mysql84backup (Backup)
```

## ProxySQL Usage
- Admin interface: `mysql` (as `percona` user, auto-switched on login)
- Config files: `/vagrant/config/proxysql1.cnf`, `/vagrant/config/proxysql2.cnf`
- Cluster is pre-configured; MySQL backends are auto-registered
- All MySQL nodes (including mysql84backup) are configured as readers in hostgroup 11

## MySQL Usage
- `mysql` as `percona` user (auto-switched on login)
- Each node has a `.my.cnf` with a prompt showing the node name
- mysql84backup replicates from mysql84 for disaster recovery

## .env Example (`config/.env`)
```env
USER_PUB_KEY='ssh-rsa ...yourkey...'
API_KEY=your_api_key_here
CLIENT_IDENTIFIER=your_client_identifier_here
GASCAN_VERSION=v1.30.0
SSH_MS_NAME=lab_name-gascan
CUSTMER_ENV=lab_name_SN-gascan
```
- Required for monitor node provisioning and SSH key setup

## Stopping & Cleanup
```sh
vagrant halt      # Stop all VMs
vagrant destroy   # Destroy all VMs
```

## Troubleshooting
- Check Vagrant output for provisioning errors
- Check `/var/log/mysql/` or `/var/log/proxysql/` inside VMs
- If a VM fails to start, check for duplicate IPs/hostnames in `Vagrantfile`
- If you can't SSH, check your `.env` public key and Vagrant status

## Directory Structure
- `Vagrantfile` — VM definitions
- `provision/` — All provisioning scripts
- `config/` — MySQL & ProxySQL config files
- `High_level_plan.md` — Advanced scenarios

## Customization
- Add/modify VMs in `Vagrantfile`
- Edit provisioning scripts in `provision/`
- Change passwords/secrets in `.env` (never commit real secrets)

---