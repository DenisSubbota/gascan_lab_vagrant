#!/bin/bash
set -euo pipefail

# [INFO] Starting monitor provisioning

# TODO: Move hardcoded passwords to environment variables for better security

# Install only essential packages for user/ssh/ansible setup
sudo apt-get update
sudo apt-get install -y openssh-client openssh-server curl ansible sudo iputils-ping vim

# Create percona user with passwordless sudo if not exists
if ! id percona &>/dev/null; then
    sudo useradd -m -s /bin/bash percona
fi
sudo mkdir -p /etc/sudoers.d
sudo bash -c "echo 'percona ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/percona"
sudo chmod 0440 /etc/sudoers.d/percona

echo 'percona:percona' | sudo chpasswd

# Enable password authentication for SSH
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo mkdir -p /var/run/sshd
sudo service ssh restart

# Add user public key for SSH login
USER_PUB_KEY='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDXyGc0wmF3gKrN/8pgh86gFMLfPXHwAc10JlwOndo749jnLzwo8JAHTd1kgLs7nCTJsQijMAcPz8W6RQMS2iVeH4Q4RjQNhuvMBWzQOmPynME4ZoSFuH7c6xycjKePbC2X/xFkKAf+GzG6zeM31Jm+AQaHsoVPCQiSNMs7QlQjZpvjNKFplpW2PVuXAGNH4eE3MtTgVJTQSvAPB2qwZQijruBtD5u9+fyY1esM9yuqIWka+hYbzhZrwLR//uLlLNpOafv/JUNWLONXJhBQAKw3/1Q1OhYOMZDitqEQx9CpEuSeeUuJSLqGZy4YHg+AiJDaDxdqz1kwOLGLPQ8S3mDV3fOB+C+VhuPjCXkIxEV+bq2XlDuUdlfAOn7+mZPstYbTbd68Zmje/H3JdinKHbFVv/I65G9kIj1wO90vXY1zFbfwyDHzUha+4QihmefBITztNbl57PBfM+u2k/Ck5exld9O5tE6JfCqm0jjV5hJc5rLZGBusbw9uxWnTc4Rgys3/hpLdCf5vbJCbHuCzq6lDzwT3Ii+BUQydTnigIAg6p6UmZ4hBsj7fcsJSWA5nk6nd4MwUUySNnPMgP66EikSy2Eh+HQVmJqcE5E5TldpsYBbTszl5XCwwu+sqmxsognfTh8RYHr+hQabBxFAi2LXJYaQpp3E1vSCOvcGZWAGoSw== denissubbota@Deniss-MBP.netis'
sudo -u percona mkdir -p /home/percona/.ssh
if ! sudo grep -q "$USER_PUB_KEY" /home/percona/.ssh/authorized_keys 2>/dev/null; then
  echo "$USER_PUB_KEY" | sudo tee -a /home/percona/.ssh/authorized_keys
fi
sudo chown -R percona:percona /home/percona/.ssh
sudo chmod 700 /home/percona/.ssh
sudo chmod 600 /home/percona/.ssh/authorized_keys

echo "[INFO] Generating SSH key for percona if not exists..."
# Generate SSH key for percona if not exists
sudo -u percona bash -c '[ -f /home/percona/.ssh/id_rsa ] || ssh-keygen -t rsa -N "" -f /home/percona/.ssh/id_rsa'

# Copy public key to shared location for MySQL nodes to use
sudo cp /home/percona/.ssh/id_rsa.pub /vagrant/provision/monitor_id_rsa.pub
sudo chmod 644 /vagrant/provision/monitor_id_rsa.pub

echo "[INFO] Creating .my.cnf for percona user..."
# Create .my.cnf for percona user for easy mysql CLI access
sudo bash -c 'cat <<EOF > /home/percona/.my.cnf
[client]
user=percona
password=Percona1234
host=localhost
EOF'
sudo chown percona:percona /home/percona/.my.cnf
sudo chmod 600 /home/percona/.my.cnf

echo "[INFO] Sourcing .env file from /vagrant/config/.env if present..."
# Parse .env and convert to --extra-vars format
if [ -f /vagrant/config/.env ]; then
  ENV_VARS=$(grep -v '^#' /vagrant/config/.env | xargs)
else
  ENV_VARS=""
fi

echo "[INFO] Running Ansible playbook for monitor configuration..."
# Run the Ansible playbook for monitor configuration (idempotent)
export ANSIBLE_HOST_KEY_CHECKING=False
sudo ansible-playbook /vagrant/provision/playbook_monitor.yml -i localhost, --extra-vars "$ENV_VARS" || {
  echo "[ERROR] Ansible playbook failed"; exit 1;
}

echo "[INFO] Running gascan as percona user..."
# Run gascan as percona user with environment loaded
sudo -u percona -i bash -c 'source ~/.bashrc && /home/percona/bin/gascan'

echo "[INFO] Monitor provisioning complete."

# NOTE:
# Environment variables for the percona user are set in .bashrc by the Ansible playbook.
# For non-interactive commands, use:
#   sudo -u percona -i bash -c 'source ~/.bashrc && <your_command>'
# to ensure the environment is loaded. 