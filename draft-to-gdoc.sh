#!/bin/bash
# draft-to-gdoc.sh — Push a markdown article draft to Google Docs for review
# Usage: bash draft-to-gdoc.sh <markdown-file> [title]
# Returns: Google Doc URL
set -e

export PATH="$HOME/.openclaw/bin:$PATH"

MD_FILE="$1"
TITLE="${2:-Article Draft}"

if [ -z "$MD_FILE" ] || [ ! -f "$MD_FILE" ]; then
    echo "Usage: bash $0 <markdown-file> [title]"
    exit 1
fi

# Convert markdown to clean text for Google Docs, save to temp file
TMPFILE=$(mktemp /tmp/gdoc-content-XXXXX.txt)
python3 -c "
import re, sys

with open(sys.argv[1], 'r') as f:
    text = f.read()

# Remove HTML tags
text = re.sub(r'<[^>]+>', '', text)

# Convert markdown headers to plain text with spacing  
text = re.sub(r'^#{1,2}\s+(.+)$', r'\n\1\n', text, flags=re.MULTILINE)
text = re.sub(r'^#{3,6}\s+(.+)$', r'\n\1', text, flags=re.MULTILINE)

# Convert bold/italic
text = re.sub(r'\*\*\*(.+?)\*\*\*', r'\1', text)
text = re.sub(r'\*\*(.+?)\*\*', r'\1', text)
text = re.sub(r'\*(.+?)\*', r'\1', text)

# Convert links to text (url)
text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'\1 (\2)', text)

# Clean up excessive newlines
text = re.sub(r'\n{4,}', '\n\n\n', text)

with open(sys.argv[2], 'w') as f:
    f.write(text)
" "$MD_FILE" "$TMPFILE"

# Create the Google Doc
DOC_ID=$(gws docs documents create --json "{\"title\":\"[DRAFT] ${TITLE}\"}" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['documentId'])")

if [ -z "$DOC_ID" ]; then
    rm -f "$TMPFILE"
    echo "ERROR: Failed to create Google Doc"
    exit 1
fi

# Build JSON payload for insert, escaping content properly
python3 -c "
import json, sys

with open(sys.argv[1], 'r') as f:
    content = f.read()

payload = {
    'requests': [{
        'insertText': {
            'location': {'index': 1},
            'text': content
        }
    }]
}

with open(sys.argv[1] + '.json', 'w') as f:
    json.dump(payload, f)
" "$TMPFILE"

gws docs documents batchUpdate --params "{\"documentId\":\"${DOC_ID}\"}" --json-file "${TMPFILE}.json" >/dev/null 2>&1 || \
gws docs documents batchUpdate --params "{\"documentId\":\"${DOC_ID}\"}" --json "$(cat ${TMPFILE}.json)" >/dev/null 2>&1

rm -f "$TMPFILE" "${TMPFILE}.json"

echo "https://docs.google.com/document/d/${DOC_ID}/edit"
