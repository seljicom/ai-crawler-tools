#!/usr/bin/env bash
# -------------------------------------------------------------
# AI & Search Bot Crawlability Tester
# Checks if your site is reachable by major AI crawlers
# Created for SELJI.com
# -------------------------------------------------------------

URL="https://selji.com/best-home-office-essentials-that-boost-productivity-2025-guide"
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
printf "%-20s | %-10s | %-40s\n" "User-Agent" "Status" "Response"
printf -- "--------------------------------------------------------------------------\n"

for BOT in "${BOTS[@]}"; do
  STATUS=$(curl -A "$BOT" -s -o /dev/null -w "%{http_code}" -I "$URL")
  RESPONSE=$(curl -A "$BOT" -s -I "$URL" | grep -i "Server:" | head -1)
  if [[ "$STATUS" == "200" ]]; then
    printf "%-20s | \033[1;32m%-10s\033[0m | %s\n" "$BOT" "$STATUS" "$RESPONSE"
  else
    printf "%-20s | \033[1;31m%-10s\033[0m | %s\n" "$BOT" "$RESPONSE"
  fi
done

printf "\n✅ 200 = Reachable | ❌ 403/404 = Blocked or not found | ⚙️ Adjust .htaccess if needed.\n\n"
