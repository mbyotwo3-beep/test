#!/bin/bash
set -e

echo "=================================================================="
echo " Deploying Production Stack: Marley Health & Mirth Connect "
echo "=================================================================="

# 1. Update Ubuntu server components 
sudo apt-get update -y
sudo apt-get upgrade -y

# 2. AUTOMATICALLY OPEN PORTS IN UBUNTU FIREWALL
echo "-> Unlocking Network Firewall Ports for Web and Machines..."
sudo apt-get install ufw -y
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp    
sudo ufw allow 80/tcp    
sudo ufw allow 8443/tcp  
sudo ufw allow 9000/tcp  
sudo ufw allow 9100/tcp  
sudo ufw allow 9200/tcp  
echo "y" | sudo ufw enable

# 3. USE UBUNTU'S INTERNAL DOCKER VERSION
echo "-> Installing system container engine natively..."
sudo apt-get install -y docker.io docker-compose git
sudo systemctl enable docker --now

# Refresh PATH links instantly
export PATH=$PATH:/usr/bin:/usr/local/bin

# 4. COMPILE CUSTOM DOCKER IMAGE
echo "-> Compiling production frontend image (This will take 5-10 minutes)..."
if [ ! -d "frappe_docker" ]; then
    git clone https://github.com/frappe/frappe_docker.git
fi
cd frappe_docker
echo '[
  {"url": "https://github.com/frappe/erpnext", "branch": "version-15"},
  {"url": "https://github.com/frappe/healthcare", "branch": "version-15"}
]' > apps.json
sudo docker build \
  --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
  --build-arg=FRAPPE_BRANCH=version-15 \
  --build-arg=APPS_JSON_BASE64=$(base64 -w 0 apps.json) \
  --tag=doc0clock-hms:v15 \
  --file=images/layered/Containerfile .
cd ..

# 5. BOOT CORE SYSTEMS
echo "-> Powering up core systems..."
sudo docker-compose down || true
sudo docker-compose up -d

# 6. SMART HEALTH CHECK LOOP
echo "-> Waiting for MariaDB server engine to establish database tables..."
until sudo docker exec testing_hospital_db mariadb-admin ping -u root -phospital_secure_password_2026 --silent; do
    echo "   Database engine initializing... holding loop for 4 seconds..."
    sleep 4
done
echo "-> Database is fully alive and ready!"

# 7. INJECT SECURE ROOT CONFIG
echo "-> Injecting superuser access configuration blocks..."
sudo docker exec -i hms_backend bash -c "cat << 'EOF' > /home/frappe/frappe-bench/sites/common_site_config.json
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

# 8. CONFIGURE FRAPPE & MARLEY HEALTHCARE
echo "-> Configuring Frappe v15 core schemas..."
sudo docker exec -it hms_backend bench new-site testinghospital.local \
  --db-root-username root \
  --db-root-password hospital_secure_password_2026 \
  --admin-password admin_hospital_password \
  --install-app erpnext --force

echo "-> Mapping core healthcare modules to your active instance..."
sudo docker exec -it hms_backend bench --site testinghospital.local install-app healthcare

echo "=================================================================="
echo " STABLE ECOSYSTEM DEPLOYED SUCCESSFULLY                           "
echo "=================================================================="
