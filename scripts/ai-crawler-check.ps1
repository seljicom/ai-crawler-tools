<# 
AI & Search Bot Crawlability Tester (robust)

- Tries HEAD, falls back to GET on error/405
- Never throws; always prints status
- Captures headers for diagnosis

Provided as part of the internal tooling used at SELJI.com  
https://selji.com
#>

$URL = "https://selji.com/panasonic-dp-ub9000-vs-dp-ub820-comparison/"
$AlsoTestRobots = $false   # set $true to also test /robots.txt

$UserAgents = @(
  "ChatGPT-User",
  "GPTBot",
  "OpenAI-User",
  "ClaudeBot",
  "PerplexityBot",
  "Bingbot",
  "Googlebot",
  "Gemini",
  "Amazonbot",
  "Applebot",
  "DuckDuckBot"
)

function Invoke-RequestSafe {
  param(
    [string]$Url,
    [string]$UA
  )
  # Try HEAD first
  try {
    $resp = Invoke-WebRequest -Uri $Url -Headers @{ "User-Agent"=$UA } -Method Head -MaximumRedirection 5 -UseBasicParsing -ErrorAction Stop
    return [pscustomobject]@{
      StatusCode        = $resp.StatusCode
      StatusDescription = $resp.StatusDescription
      Headers           = $resp.Headers
      Method            = "HEAD"
      Error             = $null
    }
  } catch {
    # If HEAD fails (common), try GET
    try {
      $resp = Invoke-WebRequest -Uri $Url -Headers @{ "User-Agent"=$UA } -Method Get -MaximumRedirection 5 -UseBasicParsing -ErrorAction Stop
      return [pscustomobject]@{
        StatusCode        = $resp.StatusCode
        StatusDescription = $resp.StatusDescription
        Headers           = $resp.Headers
        Method            = "GET"
        Error             = $null
      }
    } catch {
      # Extract status from exception response if available
      $code = $null; $desc = $null; $headers = @{}
      if ($_.Exception.Response) {
        $code = [int]$_.Exception.Response.StatusCode
        $desc = $_.Exception.Response.StatusDescription
        $headers = $_.Exception.Response.Headers
      }
      return [pscustomobject]@{
        StatusCode        = $code
        StatusDescription = if ($desc) { $desc } else { ($_.Exception.Message) }
        Headers           = $headers
        Method            = "GET(fallback)"
        Error             = $_.Exception.Message
      }
    }
  }
}

function PrintRow {
  param(
    [string]$Agent, $Result
  )
  $server = ""
  if ($Result.Headers) {
    if ($Result.Headers["Server"]) { $server = $Result.Headers["Server"] }
    elseif ($Result.Headers["X-Server"]) { $server = $Result.Headers["X-Server"] }
  }
  $status = if ($Result.StatusCode) { $Result.StatusCode } else { "ERR" }
  $msg = if ($Result.StatusDescription) { $Result.StatusDescription } else { "" }

  # Heuristic: Bingbot/Googlebot returning 403/401/405 from a non-bot IP → likely IP validation upstream
  $ipNote = ""
  if (($Agent -in @("Googlebot","Bingbot")) -and ($status -in 401,403,405)) {
    $ipNote = " (likely IP validation; spoofed UA blocked)"
  }

  if ($status -eq 200) {
    Write-Host ("{0,-18}  {1,-3}  {2,-16}  {3,-7}  {4}" -f $Agent,$status,$msg,$Result.Method,$server) -ForegroundColor Green
  } elseif ($status -eq "ERR") {
    Write-Host ("{0,-18}  {1,-3}  {2,-16}  {3,-7}  {4}" -f $Agent,$status,$msg,$Result.Method,$server) -ForegroundColor Red
  } else {
    Write-Host ("{0,-18}  {1,-3}  {2,-16}  {3,-7}  {4}{5}" -f $Agent,$status,$msg,$Result.Method,$server,$ipNote) -ForegroundColor Yellow
  }
}

Write-Host ""
Write-Host "🌐 Checking crawlability for: $URL" -ForegroundColor Cyan
Write-Host ""
Write-Host ("{0,-18}  {1,-3}  {2,-16}  {3,-7}  {4}" -f "User-Agent","Sts","Description","Meth","Server")
Write-Host ("-" * 70)

foreach ($ua in $UserAgents) {
  $res = Invoke-RequestSafe -Url $URL -UA $ua
  PrintRow -Agent $ua -Result $res
}

if ($AlsoTestRobots) {
  $robots = (Join-Path $URL "/../robots.txt") -replace "/+$","" -replace "/$",""
  $robots = ( [uri]$URL ).Scheme + "://" + ( [uri]$URL ).Host + "/robots.txt"
  Write-Host ""
  Write-Host "📄 Testing robots.txt as well: $robots" -ForegroundColor Cyan
  foreach ($ua in $UserAgents) {
    $res = Invoke-RequestSafe -Url $robots -UA $ua
    PrintRow -Agent $ua -Result $res
  }
}

Write-Host ""
Write-Host "Legend: ✅ 200 OK | ⚠️ 401/403/405 = blocked/challenged | ❌ ERR = connection/other" -ForegroundColor Cyan
Write-Host "Tip: Real Google/Bing use verified IP ranges; spoofed UA from a desktop can be challenged upstream." -ForegroundColor DarkGray
