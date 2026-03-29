#!/bin/bash
# quill-publish.sh — Autonomous publish wrapper for Quill
# Converts a polished .md article to HTML and publishes to vmwaremadesimple.com
#
# Usage: ./tools/quill-publish.sh <path-to-polished.md>
#
# The .md file should have a YAML frontmatter block:
#   ---
#   title: "Article Title Here"
#   slug: article-url-slug
#   description: "Meta description for SEO"
#   category: "Broadcom Licensing"
#   read_time: 10
#   keywords: "vmware,broadcom,vcf"
#   ---
#
# If frontmatter is missing, values are inferred from filename and content.

set -e

REPO_DIR="/home/rob/.openclaw/vmwaremadesimple"
INPUT_FILE="$1"

if [ -z "$INPUT_FILE" ] || [ ! -f "$INPUT_FILE" ]; then
    echo "Usage: $0 <path-to-polished-markdown.md>"
    echo "Example: $0 /home/rob/.openclaw/workspace-travel/content/drafts/2026-03-27-calculating-real-costs-broadcom-vmware-subscription-pricing-POLISHED.md"
    exit 1
fi

echo "📄 Processing: $INPUT_FILE"

# --- Extract frontmatter ---
TITLE=$(grep -m1 '^title:' "$INPUT_FILE" | sed 's/^title: *//;s/^"//;s/"$//' 2>/dev/null || echo "")
SLUG=$(grep -m1 '^slug:' "$INPUT_FILE" | sed 's/^slug: *//' 2>/dev/null || echo "")
META_DESC=$(grep -m1 '^description:' "$INPUT_FILE" | sed 's/^description: *//;s/^"//;s/"$//' 2>/dev/null || echo "")
CATEGORY=$(grep -m1 '^category:' "$INPUT_FILE" | sed 's/^category: *//;s/^"//;s/"$//' 2>/dev/null || echo "Broadcom Licensing")
READ_TIME=$(grep -m1 '^read_time:' "$INPUT_FILE" | sed 's/^read_time: *//' 2>/dev/null || echo "10")
KEYWORDS=$(grep -m1 '^keywords:' "$INPUT_FILE" | sed 's/^keywords: *//;s/^"//;s/"$//' 2>/dev/null || echo "vmware,broadcom,licensing")

# --- Infer from filename if frontmatter missing ---
BASENAME=$(basename "$INPUT_FILE" .md)
BASENAME_CLEAN=$(echo "$BASENAME" | sed 's/-POLISHED$//' | sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-//')

if [ -z "$SLUG" ]; then
    SLUG="$BASENAME_CLEAN"
    echo "  ℹ️  Inferred slug from filename: $SLUG"
fi

if [ -z "$TITLE" ]; then
    # Try to get first H1 from markdown
    TITLE=$(grep -m1 '^# ' "$INPUT_FILE" | sed 's/^# //' 2>/dev/null || echo "")
    if [ -z "$TITLE" ]; then
        # Convert slug to title
        TITLE=$(echo "$SLUG" | tr '-' ' ' | sed 's/\b\(.\)/\u\1/g')
    fi
    echo "  ℹ️  Inferred title: $TITLE"
fi

if [ -z "$META_DESC" ]; then
    # Use first non-empty paragraph after frontmatter/H1
    META_DESC=$(awk '/^[^#\-\*]/ && length > 80 {print; exit}' "$INPUT_FILE" | cut -c1-160)
    echo "  ℹ️  Inferred description from content"
fi

echo "  📌 Slug: $SLUG"
echo "  📌 Title: $TITLE"
echo "  📌 Category: $CATEGORY"
echo "  📌 Read time: ${READ_TIME} min"

# --- Check if already published ---
if [ -f "$REPO_DIR/articles/${SLUG}.html" ]; then
    echo "  ⚠️  Already published: articles/${SLUG}.html"
    echo "  Use --force to overwrite, or choose a different slug."
    if [ "$2" != "--force" ]; then
        exit 0
    fi
    echo "  🔄 Force mode — overwriting..."
fi

# --- Convert markdown body to HTML ---
# Strip YAML frontmatter (between --- markers)
BODY_MD=$(awk '/^---/{if(in_fm){in_fm=0;next}else{in_fm=1;next}} !in_fm{print}' "$INPUT_FILE")

# Convert markdown to HTML using python3
BODY_HTML=$(python3 - <<'PYEOF'
import sys, re

def md_to_html(md):
    lines = md.split('\n')
    html = []
    in_ul = False
    in_ol = False
    in_code = False
    in_table = False
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Fenced code blocks
        if line.strip().startswith('```'):
            if in_code:
                html.append('</code></pre>')
                in_code = False
            else:
                lang = line.strip()[3:].strip()
                lang_class = f' class="language-{lang}"' if lang else ''
                html.append(f'<pre><code{lang_class}>')
                in_code = True
            i += 1
            continue
        
        if in_code:
            # Escape HTML in code blocks
            line = line.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
            html.append(line)
            i += 1
            continue
        
        # Close lists if needed
        if in_ul and not line.startswith('- ') and not line.startswith('* '):
            html.append('</ul>')
            in_ul = False
        if in_ol and not re.match(r'^\d+\.', line):
            html.append('</ol>')
            in_ol = False
        
        # Empty line
        if not line.strip():
            html.append('')
            i += 1
            continue
        
        # Headings
        if line.startswith('#### '):
            html.append(f'<h4>{inline(line[5:])}</h4>')
        elif line.startswith('### '):
            html.append(f'<h3>{inline(line[4:])}</h3>')
        elif line.startswith('## '):
            html.append(f'<h2>{inline(line[3:])}</h2>')
        elif line.startswith('# '):
            html.append(f'<h2>{inline(line[2:])}</h2>')  # H1 → H2 (page already has H1)
        # Unordered list
        elif line.startswith('- ') or line.startswith('* '):
            if not in_ul:
                html.append('<ul>')
                in_ul = True
            html.append(f'<li>{inline(line[2:])}</li>')
        # Ordered list
        elif re.match(r'^\d+\.', line):
            if not in_ol:
                html.append('<ol>')
                in_ol = True
            html.append(f'<li>{inline(re.sub(r"^\d+\.\s*", "", line))}</li>')
        # Blockquote
        elif line.startswith('> '):
            html.append(f'<blockquote>{inline(line[2:])}</blockquote>')
        # Horizontal rule
        elif line.strip() in ('---', '***', '___'):
            html.append('<hr>')
        # Regular paragraph
        else:
            html.append(f'<p>{inline(line)}</p>')
        
        i += 1
    
    # Close open blocks
    if in_ul: html.append('</ul>')
    if in_ol: html.append('</ol>')
    if in_code: html.append('</code></pre>')
    
    return '\n'.join(html)

def inline(text):
    # Bold+italic
    text = re.sub(r'\*\*\*(.*?)\*\*\*', r'<strong><em>\1</em></strong>', text)
    # Bold
    text = re.sub(r'\*\*(.*?)\*\*', r'<strong>\1</strong>', text)
    text = re.sub(r'__(.*?)__', r'<strong>\1</strong>', text)
    # Italic
    text = re.sub(r'\*(.*?)\*', r'<em>\1</em>', text)
    text = re.sub(r'_(.*?)_', r'<em>\1</em>', text)
    # Inline code
    text = re.sub(r'`([^`]+)`', r'<code>\1</code>', text)
    # Links
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', text)
    return text

md = sys.stdin.read()
print(md_to_html(md))
PYEOF
)

echo "$BODY_MD" | python3 - <<'PYEOF' > /tmp/quill-body-$$.html
import sys, re

def md_to_html(md):
    lines = md.split('\n')
    html = []
    in_ul = False
    in_ol = False
    in_code = False
    i = 0
    
    while i < len(lines):
        line = lines[i]
        if line.strip().startswith('```'):
            if in_code:
                html.append('</code></pre>')
                in_code = False
            else:
                lang = line.strip()[3:].strip()
                lang_class = f' class="language-{lang}"' if lang else ''
                html.append(f'<pre><code{lang_class}>')
                in_code = True
            i += 1
            continue
        if in_code:
            line = line.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
            html.append(line)
            i += 1
            continue
        if in_ul and not (line.startswith('- ') or line.startswith('* ')):
            html.append('</ul>')
            in_ul = False
        if in_ol and not re.match(r'^\d+\.', line):
            html.append('</ol>')
            in_ol = False
        if not line.strip():
            html.append('')
            i += 1
            continue
        if line.startswith('#### '): html.append(f'<h4>{inline(line[5:])}</h4>')
        elif line.startswith('### '): html.append(f'<h3>{inline(line[4:])}</h3>')
        elif line.startswith('## '): html.append(f'<h2>{inline(line[3:])}</h2>')
        elif line.startswith('# '): html.append(f'<h2>{inline(line[2:])}</h2>')
        elif line.startswith('- ') or line.startswith('* '):
            if not in_ul: html.append('<ul>'); in_ul = True
            html.append(f'<li>{inline(line[2:])}</li>')
        elif re.match(r'^\d+\.', line):
            if not in_ol: html.append('<ol>'); in_ol = True
            html.append(f'<li>{inline(re.sub(r"^\d+\.\s*", "", line))}</li>')
        elif line.startswith('> '): html.append(f'<blockquote>{inline(line[2:])}</blockquote>')
        elif line.strip() in ('---', '***', '___'): html.append('<hr>')
        else: html.append(f'<p>{inline(line)}</p>')
        i += 1
    if in_ul: html.append('</ul>')
    if in_ol: html.append('</ol>')
    if in_code: html.append('</code></pre>')
    return '\n'.join(html)

def inline(text):
    text = re.sub(r'\*\*\*(.*?)\*\*\*', r'<strong><em>\1</em></strong>', text)
    text = re.sub(r'\*\*(.*?)\*\*', r'<strong>\1</strong>', text)
    text = re.sub(r'__(.*?)__', r'<strong>\1</strong>', text)
    text = re.sub(r'\*(.*?)\*', r'<em>\1</em>', text)
    text = re.sub(r'_(.*?)_', r'<em>\1</em>', text)
    text = re.sub(r'`([^`]+)`', r'<code>\1</code>', text)
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', text)
    return text

md = sys.stdin.read()
print(md_to_html(md))
PYEOF

# --- Call publish.sh with the HTML body ---
echo "  🚀 Publishing..."
cat /tmp/quill-body-$$.html | bash "$REPO_DIR/publish.sh" \
    "$SLUG" \
    "$TITLE" \
    "$META_DESC" \
    "$CATEGORY" \
    "$READ_TIME" \
    "$KEYWORDS"

# Cleanup
rm -f /tmp/quill-body-$$.html

echo ""
echo "✅ Done! Article live at: https://vmwaremadesimple.com/articles/${SLUG}.html"
echo "   📌 Don't forget to add a card for this article to index.html"
