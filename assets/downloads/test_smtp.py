#!/usr/bin/env python3
import smtplib
import ssl
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import configparser

def test_smtp_config(config_file):
    config = configparser.ConfigParser()
    config.read(config_file)
    
    # Extract SMTP settings from Odoo config
    smtp_server = config.get('options', 'smtp_server', fallback='localhost')
    smtp_port = config.getint('options', 'smtp_port', fallback=25)
    smtp_user = config.get('options', 'smtp_user', fallback='')
    smtp_password = config.get('options', 'smtp_password', fallback='')
    smtp_ssl = config.getboolean('options', 'smtp_ssl', fallback=False)
    
    print(f"Testing SMTP configuration:")
    print(f"  Server: {smtp_server}")
    print(f"  Port: {smtp_port}")
    print(f"  SSL/TLS: {smtp_ssl}")
    print(f"  Authentication: {'Yes' if smtp_user else 'No'}")
    
    try:
        # Create SMTP connection
        if smtp_ssl:
            server = smtplib.SMTP_SSL(smtp_server, smtp_port)
        else:
            server = smtplib.SMTP(smtp_server, smtp_port)
            if smtp_port == 587:  # TLS on port 587
                server.starttls()
        
        print("✓ SMTP connection established")
        
        # Test authentication if configured
        if smtp_user and smtp_password:
            server.login(smtp_user, smtp_password)
            print("✓ SMTP authentication successful")
        
        # Test sending a message
        msg = MIMEText("Test message from Odoo migration verification")
        msg['Subject'] = "Odoo Migration Test Email"
        msg['From'] = smtp_user or "noreply@yourdomain.com"
        msg['To'] = "admin@yourdomain.com"
        
        server.send_message(msg)
        print("✓ Test email sent successfully")
        
        server.quit()
        return True
        
    except Exception as e:
        print(f"✗ SMTP test failed: {e}")
        return False

if __name__ == "__main__":
    import sys
    config_file = sys.argv[1] if len(sys.argv) > 1 else "/etc/odoo/odoo.conf"
    test_smtp_config(config_file)