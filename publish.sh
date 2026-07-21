#!/bin/bash
# publish.sh — Convert markdown article to HTML and push to GitHub Pages
# Usage: ./publish.sh <article-slug> <title> <meta-description> <category> <read-time>
# Example: ./publish.sh "best-vmware-alternatives-2026" "Best VMware Alternatives 2026" "Compare Proxmox, Nutanix..." "Broadcom Licensing" "12"

set -e

REPO_DIR="/home/rob/vmwaremadesimple"
TEMPLATE="$REPO_DIR/article-template.html"
SLUG="$1"
TITLE="$2"
META_DESC="$3"
CATEGORY="${4:-Broadcom Licensing}"
READ_TIME="${5:-10}"
DATE_ISO=$(date +%Y-%m-%d)
DATE_DISPLAY=$(date +"%B %-d, %Y")
KEYWORDS="${6:-vmware,broadcom,proxmox,migration,licensing}"

if [ -z "$SLUG" ] || [ -z "$TITLE" ]; then
    echo "Usage: $0 <slug> <title> <meta-description> [category] [read-time] [keywords]"
    exit 1
fi

OUTPUT="$REPO_DIR/articles/${SLUG}.html"

# Read the article body HTML from stdin
BODY=$(cat)

# Build the HTML from template
sed \
    -e "s|{{TITLE}}|${TITLE}|g" \
    -e "s|{{META_DESCRIPTION}}|${META_DESC}|g" \
    -e "s|{{SLUG}}|${SLUG}|g" \
    -e "s|{{BREADCRUMB_LABEL}}|${TITLE}|g" \
    -e "s|{{CATEGORY}}|${CATEGORY}|g" \
    -e "s|{{DATE_ISO}}|${DATE_ISO}|g" \
    -e "s|{{DATE_DISPLAY}}|${DATE_DISPLAY}|g" \
    -e "s|{{READ_TIME}}|${READ_TIME}|g" \
    -e "s|{{KEYWORDS_CSV}}|${KEYWORDS}|g" \
    "$TEMPLATE" > "$OUTPUT.tmp"

# Insert the body HTML before the newsletter CTA
BODY_FILE=$(mktemp)
printf '%s' "$BODY" > "$BODY_FILE"
python3 - "$OUTPUT.tmp" "$BODY_FILE" > "$OUTPUT" <<'PY'
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
body_path = Path(sys.argv[2])
template = template_path.read_text()
body = body_path.read_text()
marker = '<!-- Newsletter CTA -->'
if marker in template:
    result = template.replace(marker, body + '\n\n    ' + marker)
else:
    result = template.replace('</article>', body + '\n</article>')
print(result)
PY
rm -f "$BODY_FILE"

rm -f "$OUTPUT.tmp"

# Update sitemap
if ! grep -q "$SLUG" "$REPO_DIR/sitemap.xml"; then
    sed -i "/<\/urlset>/i\\  <url>\\n    <loc>https://vmwaremadesimple.com/articles/${SLUG}.html</loc>\\n    <lastmod>${DATE_ISO}</lastmod>\\n    <priority>0.8</priority>\\n  </url>" "$REPO_DIR/sitemap.xml"
fi

# Git commit and push
cd "$REPO_DIR"
git add "articles/${SLUG}.html" sitemap.xml
git commit -m "Add article: ${TITLE}"
git push origin master 2>&1

echo "✅ Published: https://vmwaremadesimple.com/articles/${SLUG}.html"
