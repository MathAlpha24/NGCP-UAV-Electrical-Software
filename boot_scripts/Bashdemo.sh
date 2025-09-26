#!/usr/bin/env bash
# serve_shs.sh
# Serve shell scripts on 0.0.0.0:8080 and open Firefox to the listing.
set -euo pipefail

PORT=8080
BIND=0.0.0.0

# check dependencies
command -v python3 >/dev/null 2>&1 || { echo "python3 required. Abort."; exit 1; }
# firefox is preferred; if not found fallback to xdg-open which may use default browser
if command -v firefox >/dev/null 2>&1; then
  BROWSER_CMD="firefox"
else
  if command -v xdg-open >/dev/null 2>&1; then
    BROWSER_CMD="xdg-open"
  else
    echo "Neither firefox nor xdg-open found. Please open http://${BIND}:${PORT} manually."
    BROWSER_CMD=""
  fi
fi

# make a temporary directory to serve
TMPDIR="$(mktemp -d)"
echo "Creating temporary serve directory: ${TMPDIR}"

# gather files to show
pushd . >/dev/null
# Find: literal ____ .sh, any 4-char name ???? .sh, and all *.sh in current dir (non-recursive)
FILES=()
while IFS= read -r -d $'\0' f; do
  FILES+=("$f")
done < <(find . -maxdepth 1 -type f \( -name '____.sh' -o -name '????.sh' -o -name '*.sh' \) -print0 | sort -z)

# If no matches, create a sample file named ____ .sh to demonstrate
if [ ${#FILES[@]} -eq 0 ]; then
  echo "No matching .sh files found in $(pwd). Creating example file '____.sh' in the temp site."
  cat > "${TMPDIR}/____.sh" <<'EOF'
#!/bin/sh
# example script
echo "Hello from ____ .sh"
EOF
else
  # copy or symlink matched files into TMPDIR for serving
  for f in "${FILES[@]}"; do
    base=$(basename "$f")
    # prefer copying so files remain available even if original is moved
    cp -a "$f" "${TMPDIR}/${base}"
  done
fi
popd >/dev/null

# build an index.html listing the files (with readable links and highlighting)
INDEX="${TMPDIR}/index.html"
cat > "${INDEX}" <<HTML
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Shell scripts listing</title>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <style>
    body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Arial;margin:2rem}
    h1{font-size:1.6rem}
    .highlight{background:#fffbdd;padding:6px;border-radius:4px}
    ul{line-height:1.6}
    .meta{color:#666;font-size:0.9rem}
  </style>
</head>
<body>
  <h1>Shell scripts in this site</h1>
  <p class="meta">Served from directory created at: <code>${TMPDIR}</code></p>
  <p>Highlighted: files named <code>____.sh</code> (literal four underscores) and 4-character names like <code>abcd.sh</code>.</p>
  <ul>
HTML

# Append file entries present in TMPDIR
for f in "${TMPDIR}"/*.sh; do
  [ -e "$f" ] || continue
  fname=$(basename "$f")
  # mark literal '____.sh' specially
  if [ "$fname" = "____.sh" ]; then
    cat >> "${INDEX}" <<HTML
    <li><a class="highlight" href="./${fname}">${fname}</a> — <em>literal '____.sh'</em></li>
HTML
  elif [[ "$fname" =~ ^.{4}\.sh$ ]]; then
    # any 4-character name before .sh (e.g. abcd.sh)
    cat >> "${INDEX}" <<HTML
    <li><a href="./${fname}">${fname}</a> — <em>4-character name</em></li>
HTML
  else
    cat >> "${INDEX}" <<HTML
    <li><a href="./${fname}">${fname}</a></li>
HTML
  fi
done

cat >> "${INDEX}" <<HTML
  </ul>
  <hr>
  <p>To stop the server, return to the terminal and press <strong>ENTER</strong> or Ctrl+C.</p>
</body>
</html>
HTML

# start a simple HTTP server in the TMPDIR
echo "Starting HTTP server on ${BIND}:${PORT} serving ${TMPDIR}"
pushd "${TMPDIR}" >/dev/null

# Start server in background; redirect output to a logfile
LOGFILE="${TMPDIR}/http.log"
# Use python3's http.server
python3 -m http.server "${PORT}" --bind "${BIND}" > "${LOGFILE}" 2>&1 &

SERVER_PID=$!
echo "HTTP server PID: ${SERVER_PID} (logs: ${LOGFILE})"

# ensure we kill server and cleanup on exit
cleanup() {
  echo
  echo "Shutting down server (PID ${SERVER_PID})..."
  kill "${SERVER_PID}" >/dev/null 2>&1 || true
  wait "${SERVER_PID}" 2>/dev/null || true
  rm -rf "${TMPDIR}"
  echo "Cleaned up ${TMPDIR}."
}
trap cleanup EXIT

# open browser if available
URL="http://${BIND}:${PORT}/"
if [ -n "${BROWSER_CMD}" ]; then
  echo "Opening browser: ${BROWSER_CMD} ${URL}"
  if [ "${BROWSER_CMD}" = "firefox" ]; then
    # open without blocking: new window
    firefox "${URL}" >/dev/null 2>&1 || echo "Failed to start firefox; open ${URL} manually."
  else
    # xdg-open
    xdg-open "${URL}" >/dev/null 2>&1 || echo "Failed to open default browser; open ${URL} manually."
  fi
else
  echo "No browser command available. Open ${URL} manually."
fi

# keep the script running until user presses Enter (trap will clean up)
echo "Server running. Press ENTER to stop and clean up."
read -r _

# exit (trap will run cleanup)
exit 0
