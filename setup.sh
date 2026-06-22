#!/bin/bash
set -e

# 1. Prepare environment
sudo apt-get update -y
sudo apt-get install -y docker.io docker-compose git

# 2. Clone custom repository
if [ -d "test-repo" ]; then rm -rf test-repo; fi
git clone https://github.com/mbyotwo3-beep/test.git test-repo
cd test-repo

# 3. Build the custom v16 image
# Ensure your repo has a Dockerfile in the root
sudo docker build -t doc0clock-hms:v16 .
cd ..

# 4. Spin up the infrastructure
sudo docker-compose down
sudo docker-compose up -d

# 5. Wait for Database
echo "Waiting for Database..."
until sudo docker exec testing_hospital_db mariadb-admin ping -u root -phospital_secure_password_2026 --silent; do
    sleep 4
done

# 6. Initialize Site
echo "Initializing Frappe Site..."
sudo docker exec -i hms_backend bench new-site testinghospital.local \
  --db-root-username root \
  --db-root-password hospital_secure_password_2026 \
  --admin-password admin_hospital_password \
  --no-mariadb-socket
