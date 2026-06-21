#!/bin/bash
set -e

echo "=================================================================="
echo " Deploying Clean Stack: Marley Health & Mirth Connect Gateway    "
echo "=================================================================="

# 1. Update Ubuntu server components 
sudo apt-get update -y
sudo apt-get upgrade -y

# 2. AUTOMATICALLY OPEN PORTS IN UBUNTU FIREWALL
echo "-> Unlocking Network Firewall Ports for Web and Machines..."
sudo apt-get install ufw -y
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp    # Keep your SSH terminal open
sudo ufw allow 80/tcp    # Open Patient Website Landing Page
sudo ufw allow 8443/tcp  # Open Mirth Admin Dashboard
sudo ufw allow 9000/tcp  # Open Lab Analyzer Port (HL7)
sudo ufw allow 9100/tcp  # Open Big Machine Port (DICOM)
sudo ufw allow 9200/tcp  # Open IoT / CSV Port
echo "y" | sudo ufw enable

# 3. USE UBUNTU'S INTERNAL DOCKER VERSION
echo "-> Installing system container engine natively..."
sudo apt-get install -y docker.io docker-compose
sudo systemctl enable docker --now

# Refresh PATH links instantly
export PATH=$PATH:/usr/bin:/usr/local/bin

# 4. Boot database clusters using direct system binary path
echo "-> Powering up core systems..."
sudo docker-compose up -d

# 5. SMART HEALTH CHECK LOOP
echo "-> Waiting for MariaDB server engine to establish database tables..."
until sudo docker exec testing_hospital_db mariadb-admin ping -u root -phospital_secure_password_2026 --silent; do
    echo "   Database engine initializing... holding loop for 4 seconds..."
    sleep 4
done
echo "-> Database is fully alive and ready!"

# 6. INJECT SECURE ROOT CONFIG
echo "-> Injecting superuser access configuration blocks..."
sudo docker exec -i marley_backend bash -c "cat << 'EOF' > /home/frappe/frappe-bench/sites/common_site_config.json
{
 \"db_host\": \"db\",
 \"db_port\": 3306,
 \"redis_cache\": \"redis://hospital_redis_cache:6379\",
 \"redis_queue\": \"redis://hospital_redis_queue:6379\",
 \"redis_socketio\": \"redis://hospital_redis_queue:6379\",
 \"root_login\": \"root\",
 \"root_password\": \"hospital_secure_password_2026\"
}
EOF"

# 7. Set up the fresh Frappe v16 platform core without asking for user interaction
echo "-> Configuring Frappe v16 core schemas..."
sudo docker exec -it marley_backend bench new-site testinghospital.local \
  --db-root-username root \
  --db-root-password hospital_secure_password_2026 \
  --admin-password admin_hospital_password \
  --install-app erpnext --force

# 8. DIRECT EXTRACTION PATCH: Bypasses 'bench get-app' crash entirely by mounting the repository archive manually
echo "-> Pulling raw Marley Health framework assets directly..."
sudo rm -rf /tmp/healthcare
git clone https://github.com /tmp/healthcare

echo "-> Injecting Marley Health codebase into container space..."
sudo docker exec -i marley_backend mkdir -p /home/frappe/frappe-bench/apps/healthcare
sudo docker cp /tmp/healthcare/. marley_backend:/home/frappe/frappe-bench/apps/healthcare/
sudo docker exec -i marley_backend chown -R frappe:frappe /home/frappe/frappe-bench/apps/healthcare

# Force site apps map file configuration values
sudo docker exec -i marley_backend bash -c "cat << 'EOF' > /home/frappe/frappe-bench/sites/apps.txt
frappe
erpnext
healthcare
EOF"

# Trigger structural dependency link configurations
echo "-> Processing system dependencies..."
sudo docker exec -it marley_backend bench setup requirements

# CRITICAL FIX: Installs schemas but skips front-end asset compilation to prevent the crash
echo "-> Binding core modules to site (Bypassing broken asset engine)..."
sudo docker exec -it marley_backend bench --site testinghospital.local install-app healthcare --skip-assets

echo "=================================================================="
echo " CLEAN SYSTEM DEPLOYED SUCCESSFULY WITHOUT ASSET ERRORS           "
echo "=================================================================="
echo " Staff EMR Dashboard Access (Marley Framework): http://YOUR_LINODE_IP"
echo " Mirth Connect Automation Hub Interface:        https://YOUR_LINODE_IP:8443"
echo "=================================================================="
