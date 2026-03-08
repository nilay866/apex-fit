#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: QA_EMAIL=... QA_PASSWORD=... $0 <integration_test target> <output png>" >&2
  exit 1
fi

if [[ -z "${QA_EMAIL:-}" || -z "${QA_PASSWORD:-}" ]]; then
  echo "QA_EMAIL and QA_PASSWORD must be set." >&2
  exit 1
fi

target="$1"
output="$2"
chromedriver_url="${CHROMEDRIVER_URL:-http://127.0.0.1:4444}"
log_file="$(mktemp)"

cleanup() {
  if [[ -n "${drive_pid:-}" ]]; then
    kill "$drive_pid" 2>/dev/null || true
    wait "$drive_pid" 2>/dev/null || true
  fi
  rm -f "$log_file"
}

trap cleanup EXIT

curl -fsS "${chromedriver_url}/status" >/dev/null

pkill -f 'flutter_tools_chrome_device' >/dev/null 2>&1 || true

for session_id in $(curl -fsS "${chromedriver_url}/sessions" | jq -r '.value[].id'); do
  curl -fsS -X DELETE "${chromedriver_url}/session/${session_id}" >/dev/null || true
done

mkdir -p "$(dirname "$output")"

flutter drive \
  -d chrome \
  --browser-name=chrome \
  --browser-dimension=390x844@3 \
  --headless \
  --driver=test_driver/integration_test.dart \
  --target="$target" \
  --dart-define="QA_EMAIL=${QA_EMAIL}" \
  --dart-define="QA_PASSWORD=${QA_PASSWORD}" \
  >"$log_file" 2>&1 &
drive_pid=$!

timeout_s=180
until grep -q 'screenshot start' "$log_file"; do
  if ! kill -0 "$drive_pid" 2>/dev/null; then
    cat "$log_file" >&2
    echo "flutter drive exited before screenshot start" >&2
    exit 1
  fi
  sleep 2
  timeout_s=$((timeout_s - 2))
  if (( timeout_s <= 0 )); then
    cat "$log_file" >&2
    echo "Timed out waiting for screenshot start log." >&2
    exit 1
  fi
done

port="$(ps -ax -o command= | grep 'flutter_tools_chrome_device' | grep -oE -- '--remote-debugging-port=[0-9]+' | tail -n1 | cut -d= -f2)"

if [[ -z "${port}" ]]; then
  cat "$log_file" >&2
  echo "Could not determine app Chrome remote debugging port." >&2
  exit 1
fi

(
  cd qa
  node - "$port" "../$output" <<'NODE'
const { chromium } = require('playwright');

const port = process.argv[2];
const output = process.argv[3];

(async () => {
  const browser = await chromium.connectOverCDP(`http://127.0.0.1:${port}`);
  const context = browser.contexts()[0];
  const page = context.pages()[0];
  await page.setViewportSize({ width: 390, height: 844 });
  await page.screenshot({ path: output });
  await browser.close();
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
NODE
)

file "$output"
