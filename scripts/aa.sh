#!/bin/sh
# upload.sh - safe minimal uploader using wget/curl/awk/base64 (Alpine-friendly)

REPO="${REPO:-voalvu/voalvu}"
PATH_IN_REPO="${PATH_IN_REPO:-README.md}"
MSG="${MSG:-Update README (via curl)}"
TMP="/tmp/readme.md"

# Fetch and process data (single-line JSON safe)
wget -qO- 'https://api.monkeytype.com/users/MinaTou/profile' \
  | tr -d '\n' \
  | grep -o '"60":[^]]*' \
  | grep -o 'english_5k[^]}]*' > "$TMP" || { echo "failed to extract" >&2; exit 1; }

# Base64 encode content (portable)
if command -v base64 >/dev/null 2>&1; then
  CONTENT=$(base64 -w0 < "$TMP" 2>/dev/null || base64 < "$TMP")
else
  CONTENT=$(openssl base64 -A < "$TMP")
fi

# Fetch existing file metadata
RESP=$(wget -qO- --header="Authorization: Bearer $GITHUB_TOKEN" \
  --header="Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/contents/$PATH_IN_REPO")

# Extract SHA if present
SHA=$(printf '%s' "$RESP" | awk -F'"' '/"sha":/ {print $4; exit}')

# Build JSON payload
if [ -n "$SHA" ]; then
  JSON=$(printf '{"message":"%s","content":"%s","sha":"%s"}' "$MSG" "$CONTENT" "$SHA")
else
  JSON=$(printf '{"message":"%s","content":"%s"}' "$MSG" "$CONTENT")
fi

# Send PUT request with curl
curl -v -X PUT \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/json" \
  -d "$JSON" \
  "https://api.github.com/repos/$REPO/contents/$PATH_IN_REPO"
