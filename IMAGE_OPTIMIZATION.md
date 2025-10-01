# Image Optimization Guide

## Current Issue

PageSpeed Insights reports oversized images that waste 181.8 KB per page load.

### Problem Image

**File:** `Odoo Migration Risk Assessment.webp`
- **Actual dimensions:** 4486x1896 pixels (184 KB)
- **Display dimensions:** 366x155 pixels
- **Wasted data:** 181.8 KB (99% of file size)

## Solution

Images should be resized to match their display dimensions before upload.

### Recommended Dimensions

For blog post images displayed in content area (max-width: 650px):
- **Standard width:** 800px (supports 2x retina displays)
- **Maintain aspect ratio**

### Example Fix

```bash
# Using ImageMagick to resize
convert "Odoo Migration Risk Assessment.webp" \
  -resize 800x \
  -quality 85 \
  "Odoo Migration Risk Assessment-optimized.webp"

# Or using cwebp for WebP optimization
cwebp -q 85 -resize 800 0 \
  "Odoo Migration Risk Assessment.webp" \
  -o "Odoo Migration Risk Assessment-optimized.webp"
```

### Automated Optimization Script

```bash
#!/bin/bash
# optimize-images.sh

for img in assets/images/*.webp; do
  # Get image width
  width=$(identify -format "%w" "$img")

  # Resize if wider than 800px
  if [ "$width" -gt 800 ]; then
    echo "Optimizing: $img"
    convert "$img" -resize 800x -quality 85 "$img"
  fi
done

echo "Optimization complete!"
```

## Expected Impact

- **Before:** 184 KB per oversized image
- **After:** ~15-20 KB (90% reduction)
- **Performance gain:** ~150ms faster LCP per image
- **Total savings:** 182 KB × number of oversized images

## Implementation

1. Identify all oversized images using PageSpeed Insights
2. Resize images to appropriate dimensions (800px width for content images)
3. Re-upload optimized images
4. Clear GitHub Pages cache (wait 1-2 minutes for rebuild)

## Prevention

Before adding new images:
1. Check display context (content width, sidebar, etc.)
2. Resize to 2x display size (e.g., 366px display → 732px actual, round to 800px)
3. Use WebP format with quality 80-85
4. Test with `ls -lh` - content images should be <30 KB
