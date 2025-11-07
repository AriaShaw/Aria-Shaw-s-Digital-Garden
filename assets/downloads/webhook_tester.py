#!/usr/bin/env python3
"""
Webhook Testing & Debugging Tool
Tests webhook endpoints with payload simulation, validates responses, and logs traffic.
"""

import requests
import json
import time
import hashlib
import hmac
from datetime import datetime
import argparse

def generate_signature(payload, secret):
    """Generate HMAC-SHA256 signature for webhook validation"""
    return hmac.new(
        secret.encode(),
        payload.encode(),
        hashlib.sha256
    ).hexdigest()

def test_webhook(url, payload, secret=None, headers=None, timeout=30):
    """
    Test webhook endpoint with custom payload

    Args:
        url: Webhook endpoint URL
        payload: JSON payload to send
        secret: Optional secret for signature generation
        headers: Optional custom headers
        timeout: Request timeout in seconds
    """
    print(f"\n[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Testing webhook: {url}")
    print("-" * 80)

    # Prepare headers
    default_headers = {
        'Content-Type': 'application/json',
        'User-Agent': 'Odoo-Webhook-Tester/1.0'
    }
    if headers:
        default_headers.update(headers)

    # Generate signature if secret provided
    payload_str = json.dumps(payload)
    if secret:
        signature = generate_signature(payload_str, secret)
        default_headers['X-Webhook-Signature'] = f"sha256={signature}"
        print(f"Generated signature: sha256={signature}")

    # Send request
    try:
        start_time = time.time()
        response = requests.post(
            url,
            data=payload_str,
            headers=default_headers,
            timeout=timeout
        )
        elapsed = time.time() - start_time

        # Log results
        print(f"\nStatus Code: {response.status_code}")
        print(f"Response Time: {elapsed:.3f}s")
        print(f"Response Headers: {dict(response.headers)}")

        if response.text:
            try:
                print(f"Response Body: {json.dumps(response.json(), indent=2)}")
            except:
                print(f"Response Body (raw): {response.text[:500]}")

        # Validation
        if 200 <= response.status_code < 300:
            print("\n✓ Webhook test PASSED")
            return True
        else:
            print(f"\n✗ Webhook test FAILED (HTTP {response.status_code})")
            return False

    except requests.exceptions.Timeout:
        print(f"\n✗ Request timed out after {timeout}s")
        return False
    except requests.exceptions.ConnectionError as e:
        print(f"\n✗ Connection failed: {e}")
        return False
    except Exception as e:
        print(f"\n✗ Unexpected error: {e}")
        return False

# Sample payload templates
SAMPLE_PAYLOADS = {
    'order_created': {
        'event': 'order.created',
        'order_id': 'SO12345',
        'customer': 'John Doe',
        'total': 1250.00,
        'currency': 'USD',
        'timestamp': datetime.now().isoformat()
    },
    'customer_updated': {
        'event': 'customer.updated',
        'customer_id': 'C67890',
        'name': 'Acme Corp',
        'email': 'contact@acme.com',
        'timestamp': datetime.now().isoformat()
    },
    'payment_received': {
        'event': 'payment.received',
        'payment_id': 'PAY99999',
        'amount': 500.00,
        'method': 'credit_card',
        'status': 'completed',
        'timestamp': datetime.now().isoformat()
    }
}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Test webhook endpoints')
    parser.add_argument('url', help='Webhook endpoint URL')
    parser.add_argument('--payload-type', choices=list(SAMPLE_PAYLOADS.keys()),
                        default='order_created', help='Payload template to use')
    parser.add_argument('--secret', help='Webhook secret for signature generation')
    parser.add_argument('--timeout', type=int, default=30, help='Request timeout (seconds)')

    args = parser.parse_args()

    payload = SAMPLE_PAYLOADS[args.payload_type]
    print(f"Using payload template: {args.payload_type}")
    print(json.dumps(payload, indent=2))

    success = test_webhook(args.url, payload, secret=args.secret, timeout=args.timeout)
    exit(0 if success else 1)
