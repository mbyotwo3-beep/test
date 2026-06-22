#!/bin/bash
set -e

echo "-> Deploying Custom Stack: mbyotwo3-beep/test"

# 1. Update system
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install -y docker.io docker-compose git

# 2. Clone YOUR repository
if [ -d "test-repo" ]; then rm -rf test-repo; fi
git clone https://github.com/mbyotwo3-beep/test.git test-repo
cd test-repo

# 3. Build image from your repo
# Assuming your repo has a Containerfile/Dockerfile at the root
sudo DOCKER_BUILDKIT=1 docker build \
  --tag=doc0clock-hms:v16 \
  . 

cd ..

# 4. Boot systems
sudo docker-compose down || true
sudo docker-compose up -d

# 5. Final Configuration
echo "-> Configuring Site..."
sudo docker exec -it hms_backend bench new-site testinghospital.local \
  --db-root-username root \
  --db-root-password hospital_secure_password_2026 \
  --admin-password admin_hospital_password \
  --no-mariadb-socket
