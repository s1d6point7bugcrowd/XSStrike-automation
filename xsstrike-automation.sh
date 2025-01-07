#!/bin/bash

show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Script-Specific Options:"
  echo "  -D, --domain <DOMAIN> : Domain to gather potential XSS endpoints"
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
  echo "      --path                  : Inject payloads in path"
  echo "      --seeds <FILE>          : File containing seeds for crawling"
  echo "  -f, --file <FILE>           : Load payloads from a file"
  echo "  -l, --level <LEVEL>         : Level of crawling"
  echo "      --headers <HDRS>        : Add custom headers"
  echo "  -t, --threads <NUM>         : Number of concurrent threads"
  echo "  -d, --delay <SECONDS>       : Delay between requests"
  echo "      --skip                  : Don't ask to continue"
  echo "      --skip-dom              : Skip DOM checking"
  echo "      --blind                 : Blind XSS injection"
  echo "      --console-log-level <LVL> : Console logging level"
  echo "      --file-log-level <LVL>    : File logging level"
  echo "      --log-file <FILE>          : Log output to a file"
  echo ""
  echo "Examples:"
  echo "  $0 -D https://example.com --threads 3 --crawl"
  echo "  $0 --url https://www.teramind.co --threads 3 --skip-dom"
  exit 0
}

## Variables
DOMAIN=""
SINGLE_URL=""
XSS_ARGS=()

## Parse CLI arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      ;;
    -D|--domain)
      DOMAIN="$2"
      shift; shift
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
      XSS_ARGS+=("$1")
      shift
      ;;
  esac
done

# If neither domain nor single URL, prompt
if [[ -z "$DOMAIN" && -z "$SINGLE_URL" ]]; then
  echo "No domain (-D) or URL (--url) specified."
  read -p "Enter domain to gather potential XSS URLs: " DOMAIN
fi

MAIN_LOG="/home/kali/xsstrike_test_log.txt"
XSSTRIKE_OUTPUT="/home/kali/xsstrike_output.log"

echo "XSStrike Automation started at $(date)" > "$MAIN_LOG"
echo "" > "$XSSTRIKE_OUTPUT"

# ----------- Domain-Gather Mode -----------
if [[ -n "$DOMAIN" ]]; then
  echo "[*] Gathering potential XSS endpoints for: $DOMAIN"
  gau "$DOMAIN" | gf xss | sort -u > /home/kali/Possible_xss.txt

  if [ ! -s /home/kali/Possible_xss.txt ]; then
    echo "[!] No potential XSS URLs found. Exiting."
    exit 1
  fi

  cat /home/kali/Possible_xss.txt | grep -F "$DOMAIN" | grep -v '^javascript:' | grep -v '^mailto:' | sort -u > /home/kali/cleaned_xss_candidates.txt
  if [ ! -s /home/kali/cleaned_xss_candidates.txt ]; then
    echo "[!] No valid URLs found after cleaning. Exiting."
    exit 1
  fi

  while IFS= read -r url; do
    echo "[*] Testing URL: $url"
    echo "$(date) - Testing URL: $url" >> "$MAIN_LOG"

    # KEY CHANGE: Use tee with multiple files so user sees XSStrike output live
    python3 /home/kali/XSStrike/xsstrike.py \
      --url "$url" \
      --headers "X-Custom-Header: REDACTED" \
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

# ----------- Single-URL Mode -----------
if [[ -n "$SINGLE_URL" ]]; then
  echo "[*] Single-URL Mode: $SINGLE_URL"
  echo "$(date) - Testing URL: $SINGLE_URL" >> "$MAIN_LOG"

  python3 /home/kali/XSStrike/xsstrike.py \
    --url "$SINGLE_URL" \
    --headers "X-Custom-Header: REDACTED" \
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
