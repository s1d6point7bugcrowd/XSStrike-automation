#!/bin/bash
#
# XSS Testing Automation Script
# Features:
#   1. Domain-Gather Mode (via -D|--domain) + Single-URL Mode (via -u|--url)
#   2. Real-time XSStrike output (tee to multiple files)
#   3. Option to skip "contact" forms (case-insensitive) with --skip-contact

show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Script-Specific Options:"
  echo "  -D, --domain <DOMAIN>       : Gather potential XSS endpoints for <DOMAIN> using gau + gf xss"
  echo "  --skip-contact              : Skip any URL containing the substring 'contact' (case-insensitive)"
  echo ""
  echo "XSStrike Options (passed directly to XSStrike):"
  echo "  -u, --url <TARGET>          : Single URL to scan"
  echo "      --data <DATA>           : POST data"
  echo "  -e, --encode <ENCODE>       : Encode payloads"
  echo "      --fuzzer                : Fuzzer mode"
  echo "      --update                : Update XSStrike"
  echo "      --timeout <TIMEOUT>     : Timeout in seconds"
  echo "      --proxy                 : Use a proxy"
  echo "      --crawl                 : Crawl the target"
  echo "      --json                  : Treat POST data as JSON"
  echo "      --path                  : Inject payloads in the path"
  echo "      --seeds <FILE>          : Load crawling seeds from a file"
  echo "  -f, --file <FILE>           : Load payloads from a file"
  echo "  -l, --level <LEVEL>         : Level of crawling"
  echo "      --headers <HDRS>        : Add custom headers"
  echo "  -t, --threads <NUM>         : Number of concurrent threads"
  echo "  -d, --delay <SECONDS>       : Delay between requests"
  echo "      --skip                  : Don't ask to continue"
  echo "      --skip-dom              : Skip DOM checking"
  echo "      --blind                 : Inject blind XSS payload while crawling"
  echo "      --console-log-level <LVL> : Console logging level"
  echo "      --file-log-level <LVL>    : File logging level"
  echo "      --log-file <FILE>          : Log output to a file"
  echo ""
  echo "Examples:"
  echo "  $0 -D https://example.com --threads 3 --crawl"
  echo "  $0 --url https://example.com/somepage?x=1 --threads 3 --skip-dom --skip-contact"
  echo ""
  echo "Note: If neither -D|--domain nor -u|--url is specified, script prompts for a domain."
  exit 0
}

# -------------------------
# Default Variables
# -------------------------
DOMAIN=""
SINGLE_URL=""
SKIP_CONTACT=false
XSS_ARGS=()

# -------------------------
# Parse CLI Arguments
# -------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      ;;
    -D|--domain)
      DOMAIN="$2"
      shift; shift
      ;;
    --skip-contact)
      SKIP_CONTACT=true
      shift
      ;;
    -u|--url)
      SINGLE_URL="$2"
      XSS_ARGS+=("$1" "$2")
      shift; shift
      ;;
    # Pass recognized XSStrike flags to XSS_ARGS
    --data|-e|--encode|--fuzzer|--update|--timeout|--proxy|--crawl|--json|--path|--seeds|-f|--file|-l|--level|--headers|-t|--threads|-d|--delay|--skip|--skip-dom|--blind|--console-log-level|--file-log-level|--log-file)
      XSS_ARGS+=("$1")
      if [[ "$2" != -* && -n "$2" ]]; then
        XSS_ARGS+=("$2")
        shift
      fi
      shift
      ;;
    *)
      # Unrecognized argument → pass directly to XSStrike
      XSS_ARGS+=("$1")
      shift
      ;;
  esac
done

# If user did not provide domain or single URL, prompt for domain
if [[ -z "$DOMAIN" && -z "$SINGLE_URL" ]]; then
  echo "No domain (-D) or single URL (-u|--url) specified."
  read -p "Enter the domain to gather potential XSS URLs (e.g., https://example.com): " DOMAIN
fi

# -------------------------
# Log files
# -------------------------
MAIN_LOG="/home/kali/xsstrike_test_log.txt"
XSSTRIKE_OUTPUT="/home/kali/xsstrike_output.log"
echo "XSStrike Automation started at $(date)" > "$MAIN_LOG"
echo "" > "$XSSTRIKE_OUTPUT"

# -------------------------
# Domain-Gather Mode
# -------------------------
if [[ -n "$DOMAIN" ]]; then
  echo "[*] Gathering potential XSS endpoints for: $DOMAIN"
  gau "$DOMAIN" | gf xss | sort -u > /home/kali/Possible_xss.txt

  if [ ! -s /home/kali/Possible_xss.txt ]; then
    echo "[!] No potential XSS URLs found for $DOMAIN. Exiting."
    exit 1
  fi

  # Clean the results (remove lines without domain, mailto:, javascript:, etc.)
  cat /home/kali/Possible_xss.txt \
    | grep -F "$DOMAIN" \
    | sed '/^$/d' \
    | grep -v '^javascript:' \
    | grep -v '^mailto:' \
    | sort -u \
    > /home/kali/cleaned_xss_candidates.txt

  if [ ! -s /home/kali/cleaned_xss_candidates.txt ]; then
    echo "[!] No valid URLs found after cleaning. Exiting."
    exit 1
  fi

  echo "[*] Cleaned URLs in /home/kali/cleaned_xss_candidates.txt:"
  cat /home/kali/cleaned_xss_candidates.txt

  while IFS= read -r url; do
    # ------------------------
    # Skip contact forms if requested
    # ------------------------
    if $SKIP_CONTACT; then
      # Check if "contact" is in the URL (case-insensitive)
      if [[ "$url" =~ [Cc][Oo][Nn][Tt][Aa][Cc][Tt] ]]; then
        echo "[*] Skipping out-of-scope contact URL: $url"
        continue
      fi
    fi

    echo "[*] Testing URL: $url"
    echo "$(date) - Testing URL: $url" >> "$MAIN_LOG"

    python3 /home/kali/XSStrike/xsstrike.py \
      --url "$url" \
      --headers "X-Custom-Header: s1d6p01nt7@bugcrowdninja.com" \
      "${XSS_ARGS[@]}" \
      2>&1 | tee -a "$XSSTRIKE_OUTPUT" "$MAIN_LOG"

    if [ $? -eq 0 ]; then
      echo "[+] Finished testing URL: $url"
      echo "$(date) - Finished testing URL: $url" >> "$MAIN_LOG"
    else
      echo "[!] Error testing URL: $url" >> "$MAIN_LOG"
    fi

    echo "---------------------------------------------------------" >> "$MAIN_LOG"
  done < /home/kali/cleaned_xss_candidates.txt
fi

# -------------------------
# Single-URL Mode
# -------------------------
if [[ -n "$SINGLE_URL" ]]; then
  # Possibly skip if "contact" is in single URL (when skip-contact is set)
  if $SKIP_CONTACT; then
    if [[ "$SINGLE_URL" =~ [Cc][Oo][Nn][Tt][Aa][Cc][Tt] ]]; then
      echo "[*] Skipping single URL (contact form): $SINGLE_URL"
      exit 0
    fi
  fi

  echo "[*] Single-URL Mode: $SINGLE_URL"
  echo "$(date) - Testing URL: $SINGLE_URL" >> "$MAIN_LOG"

  python3 /home/kali/XSStrike/xsstrike.py \
    --url "$SINGLE_URL" \
    --headers "X-Custom-Header: your-unique-identifier" \
    "${XSS_ARGS[@]}" \
    2>&1 | tee -a "$XSSTRIKE_OUTPUT" "$MAIN_LOG"

  if [ $? -eq 0 ]; then
    echo "[+] Finished testing single URL: $SINGLE_URL"
    echo "$(date) - Finished testing single URL: $SINGLE_URL" >> "$MAIN_LOG"
  else
    echo "[!] Error testing single URL: $SINGLE_URL" >> "$MAIN_LOG"
  fi

  echo "---------------------------------------------------------" >> "$MAIN_LOG"
fi

echo "[*] XSStrike Automation completed at $(date)" >> "$MAIN_LOG"
echo "[*] Test log saved to $MAIN_LOG"
echo "[*] XSStrike detailed output saved to $XSSTRIKE_OUTPUT"
