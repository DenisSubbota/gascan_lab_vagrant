#!/bin/bash
set -e
set -x

echo "[proxysql1] Starting ProxySQL provisioning..."

# Create percona user with passwordless sudo if not exists
echo "[proxysql1] Ensuring percona user exists..."
if ! id percona &>/dev/null; then
    sudo useradd -m -s /bin/bash percona
fi
sudo mkdir -p /etc/sudoers.d
sudo bash -c "echo 'percona ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/percona"
sudo chmod 0440 /etc/sudoers.d/percona
echo 'percona:percona' | sudo chpasswd

echo "[proxysql1] Setting up SSH for percona..."
if [ -f /vagrant/provision/monitor_id_rsa.pub ]; then
    sudo -u percona mkdir -p /home/percona/.ssh
    cat /vagrant/provision/monitor_id_rsa.pub | sudo tee -a /home/percona/.ssh/authorized_keys > /dev/null
    sudo chown -R percona:percona /home/percona/.ssh
    sudo chmod 700 /home/percona/.ssh
    sudo chmod 600 /home/percona/.ssh/authorized_keys
fi
sudo -u percona bash -c '[ -f /home/percona/.ssh/id_rsa ] || ssh-keygen -t rsa -N "" -f /home/percona/.ssh/id_rsa'

echo "[proxysql1] Copying vagrant profile to vagrant user..."
if [ -f /vagrant/provision/.vagrant_profile ]; then
    sudo cp /vagrant/provision/.vagrant_profile /home/vagrant/.profile
    sudo chown vagrant:vagrant /home/vagrant/.profile
fi
if [ -f /home/vagrant/.bashrc ]; then
    sudo cp /home/vagrant/.bashrc /home/percona/.bashrc
    sudo chown percona:percona /home/percona/.bashrc
fi

echo "[proxysql1] Updating apt cache..."
sudo apt-get update -qq > /dev/null 2>&1

echo "[proxysql1] Installing MySQL client (mysql-client-8.0)..."
sudo apt-get install -y mysql-client-8.0 > /dev/null 2>&1

echo "[proxysql1] Installing ProxySQL and dependencies..."
sudo apt-get install -y wget lsb-release gnupg2 > /dev/null 2>&1
wget -O- https://repo.proxysql.com/ProxySQL/repo_pub_key | sudo apt-key add - > /dev/null 2>&1

echo "deb https://repo.proxysql.com/ProxySQL/proxysql-3.0.x/$(lsb_release -sc)/ ./" | sudo tee /etc/apt/sources.list.d/proxysql.list > /dev/null
sudo apt-get update -qq > /dev/null 2>&1
sudo apt-get install -y proxysql > /dev/null 2>&1

echo "[proxysql1] ProxySQL installed."
echo "[proxysql1] Stopping ProxySQL if running..."
sudo systemctl stop proxysql || true

echo "[proxysql1] Copying ProxySQL config..."
sudo cp /vagrant/config/proxysql1.cnf /etc/proxysql.cnf
sudo chown proxysql:proxysql /etc/proxysql.cnf

echo "[proxysql1] Creating .my.cnf for percona user..."
cat <<EOF | sudo tee /home/percona/.my.cnf > /dev/null
[client]
user=percona_proxy
password=password
host=127.0.0.1
port=6032
prompt=proxysql1> 
EOF
sudo chown percona:percona /home/percona/.my.cnf
sudo chmod 600 /home/percona/.my.cnf

echo "[proxysql1] Starting ProxySQL with new config..."
sudo systemctl start proxysql
sleep 2

echo "[proxysql1] Loading ProxySQL config to runtime and saving to disk..."
sudo -u percona mysql -e "\
LOAD MYSQL SERVERS FROM CONFIG;\
LOAD PROXYSQL SERVERS FROM CONFIG;\
LOAD MYSQL SERVERS TO RUNTIME;\
LOAD PROXYSQL SERVERS TO RUNTIME;\
SAVE MYSQL SERVERS TO DISK;\
SAVE PROXYSQL SERVERS TO DISK;\
"

echo "[proxysql1] Provisioning complete."