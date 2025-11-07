#!/usr/bin/env python3
"""
OAuth 2.0 Flow Validator
Validates OAuth authentication flows, tests token refresh, verifies scopes.
"""

import requests
import json
import base64
import time
from urllib.parse import urlencode, parse_qs, urlparse
from datetime import datetime, timedelta
import argparse

class OAuth2Validator:
    def __init__(self, client_id, client_secret, auth_url, token_url, redirect_uri='http://localhost:8080/callback'):
        self.client_id = client_id
        self.client_secret = client_secret
        self.auth_url = auth_url
        self.token_url = token_url
        self.redirect_uri = redirect_uri

    def generate_authorization_url(self, scope='', state='test_state'):
        """Generate OAuth 2.0 authorization URL"""
        params = {
            'client_id': self.client_id,
            'redirect_uri': self.redirect_uri,
            'response_type': 'code',
            'scope': scope,
            'state': state
        }
        url = f"{self.auth_url}?{urlencode(params)}"
        print(f"\n[AUTH URL] Visit this URL to authorize:")
        print(url)
        return url

    def exchange_code_for_token(self, code):
        """Exchange authorization code for access token"""
        print(f"\n[TOKEN EXCHANGE] Exchanging authorization code...")

        data = {
            'grant_type': 'authorization_code',
            'code': code,
            'redirect_uri': self.redirect_uri,
            'client_id': self.client_id,
            'client_secret': self.client_secret
        }

        try:
            response = requests.post(self.token_url, data=data)
            response.raise_for_status()

            token_data = response.json()
            print(f"✓ Token obtained successfully")
            print(f"  Access Token: {token_data.get('access_token', '')[:20]}...")
            print(f"  Token Type: {token_data.get('token_type')}")
            print(f"  Expires In: {token_data.get('expires_in')}s")
            print(f"  Scope: {token_data.get('scope')}")

            if 'refresh_token' in token_data:
                print(f"  Refresh Token: {token_data['refresh_token'][:20]}...")

            return token_data

        except requests.exceptions.HTTPError as e:
            print(f"✗ Token exchange failed: {e}")
            print(f"  Response: {e.response.text}")
            return None

    def refresh_access_token(self, refresh_token):
        """Test token refresh flow"""
        print(f"\n[TOKEN REFRESH] Testing refresh token...")

        data = {
            'grant_type': 'refresh_token',
            'refresh_token': refresh_token,
            'client_id': self.client_id,
            'client_secret': self.client_secret
        }

        try:
            response = requests.post(self.token_url, data=data)
            response.raise_for_status()

            new_token = response.json()
            print(f"✓ Token refreshed successfully")
            print(f"  New Access Token: {new_token.get('access_token', '')[:20]}...")
            print(f"  Expires In: {new_token.get('expires_in')}s")

            return new_token

        except requests.exceptions.HTTPError as e:
            print(f"✗ Token refresh failed: {e}")
            print(f"  Response: {e.response.text}")
            return None

    def validate_token(self, access_token, api_endpoint):
        """Validate access token by calling protected API endpoint"""
        print(f"\n[TOKEN VALIDATION] Testing access token against API...")

        headers = {
            'Authorization': f'Bearer {access_token}',
            'Accept': 'application/json'
        }

        try:
            response = requests.get(api_endpoint, headers=headers)
            response.raise_for_status()

            print(f"✓ Token is valid - API call successful")
            print(f"  HTTP Status: {response.status_code}")
            print(f"  Response: {response.text[:200]}...")

            return True

        except requests.exceptions.HTTPError as e:
            print(f"✗ Token validation failed: {e}")
            print(f"  HTTP Status: {e.response.status_code}")
            return False

    def check_token_expiration(self, token_data):
        """Check if token is expired or about to expire"""
        if 'expires_in' not in token_data:
            print("\n[EXPIRATION] No expiration info available")
            return

        expires_in = token_data['expires_in']
        expiry_time = datetime.now() + timedelta(seconds=expires_in)

        print(f"\n[EXPIRATION] Token expires in {expires_in}s")
        print(f"  Expiry Time: {expiry_time.strftime('%Y-%m-%d %H:%M:%S')}")

        if expires_in < 300:  # Less than 5 minutes
            print(f"  ⚠ WARNING: Token expires soon! Consider refreshing.")
        else:
            print(f"  ✓ Token has sufficient validity")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Validate OAuth 2.0 authentication')
    parser.add_argument('--client-id', required=True, help='OAuth client ID')
    parser.add_argument('--client-secret', required=True, help='OAuth client secret')
    parser.add_argument('--auth-url', required=True, help='Authorization endpoint URL')
    parser.add_argument('--token-url', required=True, help='Token endpoint URL')
    parser.add_argument('--code', help='Authorization code (from callback)')
    parser.add_argument('--refresh-token', help='Refresh token to test')
    parser.add_argument('--api-endpoint', help='API endpoint to validate token')
    parser.add_argument('--scope', default='', help='OAuth scopes (space-separated)')

    args = parser.parse_args()

    validator = OAuth2Validator(
        args.client_id,
        args.client_secret,
        args.auth_url,
        args.token_url
    )

    # Step 1: Generate authorization URL
    validator.generate_authorization_url(scope=args.scope)

    # Step 2: Exchange code for token (if provided)
    if args.code:
        token_data = validator.exchange_code_for_token(args.code)
        if token_data:
            validator.check_token_expiration(token_data)

            # Step 3: Validate token (if API endpoint provided)
            if args.api_endpoint:
                validator.validate_token(token_data['access_token'], args.api_endpoint)

            # Step 4: Test refresh (if refresh token available)
            if 'refresh_token' in token_data:
                validator.refresh_access_token(token_data['refresh_token'])

    # Test refresh token directly (if provided)
    elif args.refresh_token:
        validator.refresh_access_token(args.refresh_token)

    print("\n" + "="*80)
    print("OAuth 2.0 validation complete")
    print("="*80)
