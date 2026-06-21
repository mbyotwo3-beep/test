#!/bin/bash
set -e

echo "=================================================================="
echo " Deploying Testing Hospital SEO Hub & Universal Machine Gateway "
echo "=================================================================="

# 1. Update and provision Ubuntu packages
sudo apt-get update -y
sudo apt-get upgrade -y

# 2. Automatically install Docker infrastructure
echo "-> Mounting Docker engine layers..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo systemctl enable docker --now

# 3. Boot container systems
echo "-> Starting live containers..."
sudo docker compose up -d
sleep 20 # Allow database systems to provision completely

# 4. Create Frappe 16 / Marley Health Application Node
echo "-> Compiling Frappe v16 Environment & Marley Health modules..."
sudo docker exec -it marley_backend bench new-site testinghospital.local \
  --db-root-password hospital_secure_password_2026 \
  --admin-password admin_hospital_password \
  --install-app erpnext --force

# Fetch Marley Health module framework matching v16 schemas
sudo docker exec -it marley_backend bench get-app marley --branch v16
sudo docker exec -it marley_backend bench --site testinghospital.local install-app marley

# 5. Injecting SEO Landing Page directly into Frappe 16 routing core
echo "-> Provisioning Testing Hospital Front-End Landing Page..."
sudo docker exec -it marley_backend python3 -c "
import frappe
frappe.init(site='testinghospital.local')
frappe.connect()

if not frappe.db.exists('Web Page', 'index'):
    doc = frappe.get_doc({
        'doctype': 'Web Page',
        'title': 'Testing Hospital - Live Diagnostics & Clinical Care',
        'route': 'index',
        'published': 1,
        'meta_title': 'Testing Hospital | State of the Art Care & Real-time Diagnostics',
        'meta_description': 'Book clinical appointments online at Testing Hospital. Integrated with live automated laboratory and imaging pipelines.',
        'main_section': '''
        <div style=\"font-family:sans-serif; text-align:center; padding: 80px 20px; background:linear-gradient(to right, #0F2027, #203A43, #2C5364); color:white;\">
            <h1 style=\"font-size:3rem; margin-bottom:10px;\">Testing Hospital</h1>
            <p style=\"font-size:1.2rem; margin-bottom:30px;\">Frappe 16 Connected Engine — Seamless Multi-Machine Diagnostic Mapping.</p>
            <a href=\"#booking-form\" style=\"background:#00F260; color:#0575E6; padding:15px 30px; text-decoration:none; font-weight:bold; border-radius:5px;\">Schedule Appointment Now</a>
        </div>
        <div id=\"booking-form\" style=\"max-width:600px; margin: 50px auto; padding: 30px; border:1px solid #ddd; border-radius:8px; font-family:sans-serif;\">
            <h2 style=\"text-align:center; color:#2C5364;\">Book Consultation</h2>
            <form action=\"/api/method/marley.healthcare.doctype.patient_appointment.patient_appointment.make_appointment\" method=\"POST\">
                <label style=\"display:block; margin:15px 0 5px;\">Patient Full Name</label>
                <input type=\"text\" name=\"patient_name\" required style=\"width:100%; padding:10px; border:1px solid #ccc; border-radius:4px;\">
                <label style=\"display:block; margin:15px 0 5px;\">Appointment Date</label>
                <input type=\"date\" name=\"appointment_date\" required style=\"width:100%; padding:10px; border:1px solid #ccc; border-radius:4px;\">
                <label style=\"display:block; margin:15px 0 5px;\">Clinical Department</label>
                <select name=\"department\" style=\"width:100%; padding:10px; border:1px solid #ccc; border-radius:4px;\">
                    <option>General Medicine Clinic</option>
                    <option>Diagnostic Laboratory</option>
                    <option>High-Field Imaging Center (MRI/CT)</option>
                </select>
                <button type=\"submit\" style=\"width:100%; background:#2C5364; color:white; border:none; padding:12px; margin-top:20px; border-radius:4px; font-weight:bold; cursor:pointer;\">Confirm Booking</button>
            </form>
        </div>
        '''
    })
    doc.insert()
    frappe.db.commit()
print('Frappe 16 Hospital Landing Hub successfully written.')
"

echo "=================================================================="
echo " SERVERS COMPLETE: Everything is synced and running smoothly!    "
echo "=================================================================="
echo " Testing Hospital Home (Booking/SEO):  http://YOUR_LINODE_IP"
echo " Clinical EMR Desk Login (Marley 16):  http://YOUR_LINODE_IP/app"
echo " Central Machine Routing Core (Mirth): https://YOUR_LINODE_IP:8443"
echo "=================================================================="
