#!/usr/bin/env python3
# Advanced API connection testing
import requests
import json
import ssl
import socket
from urllib.parse import urlparse

def diagnose_api_connection(api_url, headers=None, timeout=30):
    print(f"Diagnosing connection to: {api_url}")
    
    # Parse URL components
    parsed = urlparse(api_url)
    host = parsed.hostname
    port = parsed.port or (443 if parsed.scheme == 'https' else 80)
    
    # 1. DNS Resolution Test
    try:
        ip = socket.gethostbyname(host)
        print(f"✓ DNS Resolution: {host} -> {ip}")
    except socket.gaierror as e:
        print(f"✗ DNS Resolution failed: {e}")
        return False
    
    # 2. Port Connectivity Test
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(10)
        result = sock.connect_ex((host, port))
        sock.close()
        if result == 0:
            print(f"✓ Port {port} is accessible")
        else:
            print(f"✗ Port {port} is not accessible")
            return False
    except Exception as e:
        print(f"✗ Port test failed: {e}")
        return False
    
    # 3. SSL Certificate Test (for HTTPS)
    if parsed.scheme == 'https':
        try:
            context = ssl.create_default_context()
            with socket.create_connection((host, port), timeout=10) as sock:
                with context.wrap_socket(sock, server_hostname=host) as ssock:
                    cert = ssock.getpeercert()
                    print(f"✓ SSL Certificate valid until: {cert['notAfter']}")
        except ssl.SSLError as e:
            print(f"✗ SSL Certificate error: {e}")
            return False
        except Exception as e:
            print(f"✗ SSL test failed: {e}")
            return False
    
    # 4. HTTP Response Test
    try:
        response = requests.get(api_url, headers=headers, timeout=timeout, verify=True)
        print(f"✓ HTTP Response: {response.status_code}")
        print(f"  Response time: {response.elapsed.total_seconds():.2f}s")
        print(f"  Content length: {len(response.content)} bytes")
        return True
    except requests.exceptions.RequestException as e:
        print(f"✗ HTTP Request failed: {e}")
        return False

# Test your critical API endpoints
critical_apis = [
    "https://api.example.com/webhook",
    "https://your-payment-gateway.com/api",
    "https://your-crm-system.com/integration"
]

for api in critical_apis:
    print(f"\n{'='*50}")
    diagnose_api_connection(api)