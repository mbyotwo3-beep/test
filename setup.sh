#!/bin/bash
set -e

echo "=================================================================="
echo " Initiating Auto-Deployment: Testing Hospital v16 Architecture    "
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

# 6. INJECT SECURE ROOT CONFIG (Bypasses terminal password prompts completely)
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
echo "-> Configuring Frappe v16 with Healthcare schemas..."
sudo docker exec -it marley_backend bench new-site testinghospital.local \
  --db-root-username root \
  --db-root-password hospital_secure_password_2026 \
  --admin-password admin_hospital_password \
  --install-app erpnext --force

# DEFINITIVE SOLUTION: Runs the standard native package installation steps directly inside the container
echo "-> Pulling Marley Health application package natively into v16 bench..."
sudo docker exec -it marley_backend bench get-app healthcare

echo "-> Linking healthcare modules directly to the Testing Hospital instance..."
sudo docker exec -it marley_backend bench --site testinghospital.local install-app healthcare

# 8. Injecting SEO Landing Hub and Booking Systems into Frappe Site router
echo "-> Building Hospital Web Front-End Page..."
sudo docker exec -it marley_backend python3 -c "
import frappe
frappe.init(site='testinghospital.local')
frappe.connect()

if not frappe.db.exists('Web Page', 'index'):
    doc = frappe.get_doc({
        'doctype': 'Web Page',
        'title': 'Testing Hospital - Advanced Clinical Booking & Diagnosis',
        'route': 'index',
        'published': 1,
        'meta_title': 'Testing Hospital | Secure Web Bookings & Live Medical Results',
        'meta_description': 'Schedule an appointment at Testing Hospital. Modern clinical diagnostics natively linked with medical device results data engines.',
        'main_section': '''
        <div style=\"font-family:sans-serif; text-align:center; padding: 90px 20px; background:linear-gradient(to right, #1a2a6c, #b21f1f, #fdbb2d); color:white;\">
            <h1 style=\"font-size:3.5rem; margin-bottom:10px;\">Testing Hospital</h1>
            <p style=\"font-size:1.3rem; margin-bottom:35px;\">Frappe v16 High-Performance Framework with Live Universal Machine Interfacing.</p>
            <a href=\"#booking-form\" style=\"background:#fff; color:#b21f1f; padding:15px 35px; text-decoration:none; font-weight:bold; border-radius:5px; box-shadow: 0 4px 10px rgba(0,0,0,0.2);\">Schedule An Appointment</a>
        </div>
        <div id=\"booking-form\" style=\"max-width:600px; margin: 60px auto; padding: 35px; border:1px solid #ddd; border-radius:10px; font-family:sans-serif; background:#fafafa;\">
            <h2 style=\"text-align:center; color:#1a2a6c; margin-bottom:25px;\">Secure Patient Intake Registry</h2>
            <form action=\"/api/method/healthcare.healthcare.doctype.patient_appointment.patient_appointment.make_appointment\" method=\"POST\">
                <label style=\"display:block; margin:15px 0 5px; font-weight:bold;\">Patient Legal Name</label>
                <input type=\"text\" name=\"patient_name\" required style=\"width:100%; padding:12px; border:1px solid #ccc; border-radius:4px;\">
                <label style=\"display:block; margin:15px 0 5px; font-weight:bold;\">Appointment Target Date</label>
                <input type=\"date\" name=\"appointment_date\" required style=\"width:100%; padding:12px; border:1px solid #ccc; border-radius:4px;\">
                <label style=\"display:block; margin:15px 0 5px; font-weight:bold;\">Clinical Target Division</label>
                <select name=\"department\" style=\"width:100%; padding:12px; border:1px solid #ccc; border-radius:4px; background:white;\">
                    <option>General Family Medicine</option>
                    <option>Core Diagnostic Laboratory (HL7 automated)</option>
                    <option>High-Field Imaging Facility (MRI/CT Scans)</option>
                </select>
                <button type=\"submit\" style=\"width:100%; background:#1a2a6c; color:white; border:none; padding:15px; margin-top:25px; border-radius:4px; font-weight:bold; font-size:1.1rem; cursor:pointer;\">Finalize Appointment</button>
            </form>
        </div>
        '''
    })
    doc.insert()
    frappe.db.commit()
print('SEO Front-end layer loaded into Frappe 16 successfully.')
"

echo "=================================================================="
echo " SYSTEM READY: Earthians Marley Health Is Successfully Installed! "
echo "=================================================================="
echo " Hospital Website Home (SEO Landing & Booking): http://YOUR_LINODE_IP"
echo " Staff Dashboard Access (Marley Framework):     http://YOUR_LINODE_IP/app"
echo " Mirth Connect Automation Hub Interface:        https://YOUR_LINODE_IP:8443"
echo "=================================================================="
