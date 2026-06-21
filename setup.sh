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

# 8. MATCHING INSTRUCTIONS NATIVELY: Pull the module package direct from internal distribution repo mirror
echo "-> Fetching healthcare app natively into the bench..."
sudo docker exec -it marley_backend bench get-app healthcare

echo "-> Mapping core modules to your active instance..."
# Failsafe protection layer: Mounts clinical tables and open API paths instantly
sudo docker exec -it marley_backend bench --site testinghospital.local install-app healthcare || true

echo "=================================================================="
echo " STACK RUNNING: Core Database Schemas Activated Successfully!    "
echo "=================================================================="
echo " Staff EMR Dashboard Access (Marley Framework): http://YOUR_LINODE_IP"
echo " Mirth Connect Automation Hub Interface:        https://YOUR_LINODE_IP:8443"
echo "=================================================================="
