#!/usr/bin/env bash

# -------------------------------------------------------------
# AI & Search Bot Crawlability Tester (robust version)
#
# Tries HEAD first, falls back to GET if blocked or unsupported.
# Captures real HTTP code, server header, and method used.
#
# Part of the internal tooling approach used at SELJI.com
# https://selji.com
# -------------------------------------------------------------


URL="https://selji.com/panasonic-dp-ub9000-vs-dp-ub820-comparison/"

BOTS=(
  "ChatGPT-User"
  "GPTBot"
  "OpenAI-User"
  "ClaudeBot"
  "PerplexityBot"
  "Bingbot"
  "Googlebot"
  "Gemini"
  "Amazonbot"
  "Applebot"
  "DuckDuckBot"
)

printf "\n🌐 Checking crawlability for: %s\n\n" "$URL"
printf "%-18s | %-5s | %-15s | %-7s | %-20s\n" "User-Agent" "Code" "Description" "Method" "Server"
printf -- "-------------------------------------------------------------------------------\n"

for BOT in "${BOTS[@]}"; do
  # Try HEAD request first
  RESPONSE=$(curl -s -I -A "$BOT" -w "%{http_code}" -o /tmp/curl_headers.txt "$URL" || echo "ERR")
  CODE=$(tail -n1 <<< "$RESPONSE")
  SERVER=$(grep -i "^Server:" /tmp/curl_headers.txt | cut -d' ' -f2- | tr -d '\r')
  DESC=$(head -n 1 /tmp/curl_headers.txt | cut -d' ' -f3-)
  METHOD="HEAD"

  # If HEAD failed or returned weird code, try GET
  if [[ "$CODE" == "000" || "$CODE" == "ERR" || "$CODE" == "405" || -z "$CODE" ]]; then
    RESPONSE=$(curl -s -A "$BOT" -w "%{http_code}" -o /tmp/curl_headers.txt "$URL" || echo "ERR")
    CODE=$(tail -n1 <<< "$RESPONSE")
    SERVER=$(grep -i "^Server:" /tmp/curl_headers.txt | cut -d' ' -f2- | tr -d '\r')
    DESC="(GET fallback)"
    METHOD="GET"
  fi

  # Color logic
  if [[ "$CODE" == "200" ]]; then
    COLOR="\033[1;32m"  # green
  elif [[ "$CODE" == "403" || "$CODE" == "401" || "$CODE" == "405" ]]; then
    COLOR="\033[1;33m"  # yellow
  else
    COLOR="\033[1;31m"  # red
  fi

  # IP validation warning for Googlebot/Bingbot
  IPNOTE=""
  if [[ ("$BOT" == "Googlebot" || "$BOT" == "Bingbot") && ("$CODE" == "403" || "$CODE" == "401" || "$CODE" == "405") ]]; then
    IPNOTE=" (likely IP validation; spoofed UA blocked)"
  fi

  printf "${COLOR}%-18s | %-5s | %-15s | %-7s | %-20s%s\033[0m\n" "$BOT" "$CODE" "$DESC" "$METHOD" "$SERVER" "$IPNOTE"
done

printf "\n✅ 200 = Reachable | ⚠️ 401/403/405 = challenged | ❌ ERR = blocked or failed\n"
printf "Tip: Googlebot/Bingbot often verify official IPs, not just UA strings.\n\n"
