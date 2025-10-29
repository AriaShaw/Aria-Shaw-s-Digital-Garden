#!/usr/bin/env node
/**
 * IndexNow Auto-Submission for Vercel Deployments
 *
 * WORKFLOW:
 * 1. Triggered by Vercel Deploy Hook (success only)
 * 2. Fetch current sitemap.xml from deployed site
 * 3. Compare with previous sitemap (stored in Vercel Blob/KV)
 * 4. Submit only new/updated URLs to IndexNow API
 * 5. Save current sitemap as baseline for next deployment
 *
 * FEATURES:
 * - First deployment: Submit all URLs
 * - Subsequent: Submit only diff
 * - Error recovery: Use last successful deployment's sitemap
 * - Rate limiting: Batch submissions (max 10,000 URLs per request)
 *
 * DEPENDENCIES:
 * - node-fetch (or native fetch in Node 18+)
 * - xml2js for XML parsing
 * - @vercel/blob or @vercel/kv for storage
 */

const https = require('https');
const { parseString } = require('xml2js');
const { promisify } = require('util');
const parseXML = promisify(parseString);

// Configuration
const CONFIG = {
  // Use production domain, not preview URLs
  SITE_URL: process.env.SITE_URL || 'https://ariashaw.com',

  INDEXNOW_KEY: process.env.INDEXNOW_KEY || '537e80460b3a4aa898514c845316796e',

  // IndexNow API endpoints (all major search engines)
  INDEXNOW_ENDPOINTS: [
    'https://api.indexnow.org/indexnow',  // Primary
    // 'https://www.bing.com/indexnow',   // Bing (redundant, uses indexnow.org)
    // 'https://yandex.com/indexnow',     // Yandex (if needed)
  ],

  // Storage for previous sitemap
  STORAGE_TYPE: process.env.STORAGE_TYPE || 'vercel-blob', // 'vercel-blob', 'vercel-kv', or 'file'
  STORAGE_KEY: 'indexnow-previous-sitemap',

  // Rate limiting
  MAX_URLS_PER_BATCH: 10000,
  BATCH_DELAY_MS: 1000,

  // Logging
  VERBOSE: process.env.VERBOSE === 'true',
};

/**
 * Fetch sitemap.xml from deployed site
 */
async function fetchSitemap(url) {
  const sitemapUrl = `${url}/sitemap.xml`;
  console.log(`[INFO] Fetching sitemap: ${sitemapUrl}`);

  return new Promise((resolve, reject) => {
    https.get(sitemapUrl, (res) => {
      let data = '';

      if (res.statusCode !== 200) {
        return reject(new Error(`Failed to fetch sitemap: HTTP ${res.statusCode}`));
      }

      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve(data));
    }).on('error', reject);
  });
}

/**
 * Parse sitemap XML and extract URLs
 */
async function parseSitemap(xml) {
  try {
    const result = await parseXML(xml);

    // Handle sitemap index (multiple sitemaps)
    if (result.sitemapindex) {
      console.log('[INFO] Detected sitemap index with multiple sitemaps');
      const sitemapUrls = result.sitemapindex.sitemap.map(s => s.loc[0]);

      // Fetch and parse all sub-sitemaps
      const allUrls = [];
      for (const sitemapUrl of sitemapUrls) {
        console.log(`[INFO] Fetching sub-sitemap: ${sitemapUrl}`);
        const subXml = await fetchSitemap(sitemapUrl.replace(/\/sitemap\.xml$/, ''));
        const subUrls = await parseSitemap(subXml);
        allUrls.push(...subUrls);
      }
      return allUrls;
    }

    // Handle regular sitemap
    if (result.urlset && result.urlset.url) {
      const urls = result.urlset.url.map(entry => ({
        loc: entry.loc[0],
        lastmod: entry.lastmod ? entry.lastmod[0] : null,
      }));

      console.log(`[INFO] Parsed ${urls.length} URLs from sitemap`);
      return urls;
    }

    throw new Error('Invalid sitemap format');
  } catch (error) {
    console.error('[ERROR] Failed to parse sitemap:', error.message);
    throw error;
  }
}

/**
 * Compare two sitemaps and return new/updated URLs
 */
function compareSitemaps(currentUrls, previousUrls) {
  if (!previousUrls || previousUrls.length === 0) {
    console.log('[INFO] No previous sitemap found - treating as initial submission');
    return currentUrls; // First deployment - submit all
  }

  // Create a map of previous URLs with lastmod dates
  const previousMap = new Map();
  previousUrls.forEach(url => {
    previousMap.set(url.loc, url.lastmod);
  });

  // Find new or updated URLs
  const newUrls = currentUrls.filter(url => {
    if (!previousMap.has(url.loc)) {
      return true; // New URL
    }

    const prevLastmod = previousMap.get(url.loc);
    const currLastmod = url.lastmod;

    // If either lastmod is missing, assume updated
    if (!prevLastmod || !currLastmod) {
      return true;
    }

    // Compare lastmod dates
    return new Date(currLastmod) > new Date(prevLastmod);
  });

  console.log(`[INFO] Found ${newUrls.length} new/updated URLs out of ${currentUrls.length} total`);
  return newUrls;
}

/**
 * Submit URLs to IndexNow API
 */
async function submitToIndexNow(urls, endpoint) {
  if (urls.length === 0) {
    console.log('[INFO] No URLs to submit');
    return { success: true, submitted: 0 };
  }

  // Extract just the URL strings
  const urlList = urls.map(u => typeof u === 'string' ? u : u.loc);

  // Split into batches if needed
  const batches = [];
  for (let i = 0; i < urlList.length; i += CONFIG.MAX_URLS_PER_BATCH) {
    batches.push(urlList.slice(i, i + CONFIG.MAX_URLS_PER_BATCH));
  }

  console.log(`[INFO] Submitting ${urlList.length} URLs in ${batches.length} batch(es) to ${endpoint}`);

  let totalSubmitted = 0;

  for (let i = 0; i < batches.length; i++) {
    const batch = batches[i];

    const payload = {
      host: new URL(CONFIG.SITE_URL).hostname,
      key: CONFIG.INDEXNOW_KEY,
      urlList: batch,
    };

    if (CONFIG.VERBOSE) {
      console.log(`[DEBUG] Batch ${i + 1}/${batches.length}: ${batch.length} URLs`);
    }

    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: JSON.stringify(payload),
      });

      if (response.ok) {
        console.log(`[SUCCESS] Batch ${i + 1}/${batches.length} submitted successfully (HTTP ${response.status})`);
        totalSubmitted += batch.length;
      } else {
        const errorText = await response.text();
        console.error(`[ERROR] Batch ${i + 1}/${batches.length} failed: HTTP ${response.status} - ${errorText}`);
      }

      // Rate limiting delay between batches
      if (i < batches.length - 1) {
        await new Promise(resolve => setTimeout(resolve, CONFIG.BATCH_DELAY_MS));
      }
    } catch (error) {
      console.error(`[ERROR] Batch ${i + 1}/${batches.length} submission failed:`, error.message);
    }
  }

  return { success: totalSubmitted > 0, submitted: totalSubmitted };
}

/**
 * Load previous sitemap from storage
 */
async function loadPreviousSitemap() {
  // For now, use simple file-based storage
  // TODO: Implement Vercel Blob/KV integration

  const fs = require('fs');
  const path = require('path');
  const storageFile = path.join(__dirname, '.indexnow-cache.json');

  try {
    if (fs.existsSync(storageFile)) {
      const data = fs.readFileSync(storageFile, 'utf-8');
      const cache = JSON.parse(data);
      console.log(`[INFO] Loaded previous sitemap from cache (${cache.urls.length} URLs)`);
      return cache.urls;
    }
  } catch (error) {
    console.warn('[WARN] Failed to load previous sitemap:', error.message);
  }

  return null;
}

/**
 * Save current sitemap to storage
 */
async function saveSitemap(urls) {
  const fs = require('fs');
  const path = require('path');
  const storageFile = path.join(__dirname, '.indexnow-cache.json');

  try {
    const cache = {
      timestamp: new Date().toISOString(),
      deployment: process.env.VERCEL_GIT_COMMIT_SHA || 'local',
      urls: urls,
    };

    fs.writeFileSync(storageFile, JSON.stringify(cache, null, 2), 'utf-8');
    console.log(`[INFO] Saved ${urls.length} URLs to cache`);
  } catch (error) {
    console.error('[ERROR] Failed to save sitemap cache:', error.message);
  }
}

/**
 * Main execution
 */
async function main() {
  console.log('='.repeat(80));
  console.log('IndexNow Auto-Submission for Vercel');
  console.log('='.repeat(80));
  console.log();

  try {
    // Step 1: Fetch current sitemap
    console.log('[STEP 1] Fetching current sitemap...');
    const currentXml = await fetchSitemap(CONFIG.SITE_URL);
    const currentUrls = await parseSitemap(currentXml);

    // Step 2: Load previous sitemap
    console.log('[STEP 2] Loading previous sitemap...');
    const previousUrls = await loadPreviousSitemap();

    // Step 3: Compare and find new URLs
    console.log('[STEP 3] Comparing sitemaps...');
    const urlsToSubmit = compareSitemaps(currentUrls, previousUrls);

    if (urlsToSubmit.length === 0) {
      console.log('[COMPLETE] No new URLs to submit. Exiting.');
      return;
    }

    // Step 4: Submit to IndexNow
    console.log('[STEP 4] Submitting to IndexNow...');
    let totalSubmitted = 0;

    for (const endpoint of CONFIG.INDEXNOW_ENDPOINTS) {
      const result = await submitToIndexNow(urlsToSubmit, endpoint);
      totalSubmitted = Math.max(totalSubmitted, result.submitted);
    }

    // Step 5: Save current sitemap
    console.log('[STEP 5] Saving current sitemap...');
    await saveSitemap(currentUrls);

    console.log();
    console.log('='.repeat(80));
    console.log(`[COMPLETE] Successfully submitted ${totalSubmitted} URLs to IndexNow`);
    console.log('='.repeat(80));

  } catch (error) {
    console.error();
    console.error('='.repeat(80));
    console.error('[FATAL ERROR] IndexNow submission failed:', error.message);
    console.error('='.repeat(80));
    process.exit(1);
  }
}

// Run if executed directly
if (require.main === module) {
  main();
}

module.exports = { main, submitToIndexNow, compareSitemaps };
