#!/bin/bash
#
# Vercel Deploy Success Hook
# Triggered automatically when Vercel deployment succeeds
#
# This script is executed in the Vercel build environment after successful deployment.
# It triggers the IndexNow submission to notify search engines of new/updated URLs.

set -e  # Exit on any error

echo "=================================================="
echo "Vercel Deployment Succeeded - Running Post-Deploy Hook"
echo "=================================================="
echo ""

# Environment info
echo "[INFO] Deployment URL: ${VERCEL_URL:-unknown}"
echo "[INFO] Git Commit: ${VERCEL_GIT_COMMIT_SHA:-unknown}"
echo "[INFO] Git Branch: ${VERCEL_GIT_COMMIT_REF:-unknown}"
echo ""

# Only run on production deployments (main branch)
if [ "$VERCEL_GIT_COMMIT_REF" != "main" ]; then
  echo "[SKIP] Not on main branch - skipping IndexNow submission"
  exit 0
fi

# Install dependencies if needed
if [ ! -d "node_modules/xml2js" ]; then
  echo "[INFO] Installing dependencies..."
  npm install xml2js --no-save
fi

# Run IndexNow submission
echo "[INFO] Triggering IndexNow submission..."
node .vercel/indexnow-submit.js

echo ""
echo "=================================================="
echo "Post-Deploy Hook Complete"
echo "=================================================="
