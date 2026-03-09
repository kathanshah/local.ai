# Stocky AI -- Windows Client Setup
# Installs Claude Code CLI and configures it to use the local AI server (ai.local).
#
# Usage:
#   Double-click setup-windows.bat (recommended -- handles execution policy)
#   Or open PowerShell and run:
#     powershell -ExecutionPolicy Bypass -File setup-windows.ps1
#
# What this script does:
#   1. Checks prerequisites (winget, network connectivity to ai.local)
#   2. Installs Git, Node.js, Python if missing
#   3. Installs Claude Code CLI via npm
#   4. Installs all Python packages for file generation
#   5. Sets environment variables for ai.local connection
#   6. Downloads the system prompt file
#   7. Clears any existing claude.ai login
#   8. Creates a 'stocky' command in your PowerShell profile
#   9. Adds hosts file entry if mDNS fails (requires admin)
#  10. Verifies the full setup

$ErrorActionPreference = "Continue"

try {

# --- Helper functions ---

function Test-Command($cmd) {
    return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Write-Step($msg) {
    Write-Host ""
    Write-Host "[*] $msg" -ForegroundColor Yellow
}

function Write-OK($msg) {
    Write-Host "    OK: $msg" -ForegroundColor Green
}

function Write-Skip($msg) {
    Write-Host "    SKIP: $msg" -ForegroundColor DarkGray
}

function Write-Fail($msg) {
    Write-Host "    FAIL: $msg" -ForegroundColor Red
}

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# Test if 'python' is the real interpreter or the Windows Store stub
# The stub outputs nothing useful and exits with code 9009
function Test-RealPython {
    try {
        $output = & python --version 2>&1
        if ($LASTEXITCODE -ne 0) { return $false }
        if ($output -match "Python \d+\.\d+") { return $true }
        return $false
    } catch {
        return $false
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Stocky AI -- Windows Client Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- Check if running as admin ---

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "NOTE: Running without admin. Hosts file and some installs may need elevation." -ForegroundColor DarkYellow
    Write-Host "      Re-run as Administrator for full automation." -ForegroundColor DarkYellow
}

# --- Set execution policy so PowerShell profile can load ---

Write-Step "Checking PowerShell execution policy"
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -eq "Restricted" -or $currentPolicy -eq "AllSigned") {
    Write-Host "    Current policy: $currentPolicy (blocks profile scripts)" -ForegroundColor White
    Write-Host "    Setting to RemoteSigned for current user..." -ForegroundColor White
    try {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-OK "Execution policy set to RemoteSigned"
    } catch {
        Write-Fail "Could not set execution policy. Run this manually in PowerShell:"
        Write-Host "    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor White
    }
} else {
    Write-OK "Execution policy is $currentPolicy (OK)"
}

# --- 1. Check winget availability ---

Write-Step "Checking winget (Windows package manager)"
if (Test-Command "winget") {
    Write-OK "winget is available"
} else {
    Write-Fail "winget not found. Install 'App Installer' from the Microsoft Store."
    Write-Host "    https://apps.microsoft.com/detail/9nblggh4nns1" -ForegroundColor White
    Write-Host "    After installing winget, re-run this script." -ForegroundColor White
    Read-Host "`nPress Enter to close"
    return
}

# --- 2. Check network connectivity to ai.local ---

Write-Step "Checking network connectivity to ai.local"
$serverReachable = $false
$serverIP = $null

# Try ai.local first (mDNS)
try {
    $response = Invoke-WebRequest -Uri "http://ai.local:11434/api/version" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
    Write-OK "ai.local is reachable (Ollama API responding)"
    $serverReachable = $true
} catch {
    Write-Fail "Cannot reach ai.local:11434"

    # Try known IPs (static IP + common server names)
    Write-Host "    Scanning for Ollama server on the network..." -ForegroundColor DarkGray
    $tryIPs = @("192.168.29.100")

    # Also try resolving 'ai' hostname via DNS
    try {
        $dnsResult = [System.Net.Dns]::GetHostAddresses("ai") | Where-Object { $_.AddressFamily -eq "InterNetwork" } | Select-Object -First 1
        if ($dnsResult) { $tryIPs += $dnsResult.IPAddressToString }
    } catch {}

    # Scan common addresses on the client's own subnet
    $clientIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch "^(127\.|169\.254\.)" -and $_.PrefixOrigin -ne "WellKnown" } | Select-Object -First 1).IPAddress
    if ($clientIP) {
        $subnet = ($clientIP -replace '\.\d+$', '')
        # Try common server IPs on the same subnet
        foreach ($last in @(1, 100, 200, 201, 10, 50)) {
            $candidate = "$subnet.$last"
            if ($candidate -ne $clientIP -and $tryIPs -notcontains $candidate) {
                $tryIPs += $candidate
            }
        }
    }

    foreach ($ip in $tryIPs) {
        try {
            Invoke-WebRequest -Uri "http://${ip}:11434/api/version" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop | Out-Null
            $serverIP = $ip
            Write-OK "Found Ollama server at $ip"
            break
        } catch {}
    }

    if ($serverIP) {
        Write-Host "    Server found at $serverIP but 'ai.local' doesn't resolve." -ForegroundColor White
        Write-Host "    Attempting to fix via hosts file..." -ForegroundColor White

        $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
        $hostsEntry = "$serverIP  ai.local"

        if ($isAdmin) {
            $hostsContent = Get-Content $hostsPath -Raw -ErrorAction SilentlyContinue
            # Remove old ai.local entry if present (IP may have changed)
            if ($hostsContent -match "ai\.local") {
                $hostsContent = ($hostsContent -split "`n" | Where-Object { $_ -notmatch "ai\.local" }) -join "`n"
                Set-Content -Path $hostsPath -Value $hostsContent -NoNewline
            }
            Add-Content -Path $hostsPath -Value "`n$hostsEntry"
            Write-OK "Added '$hostsEntry' to hosts file"
            ipconfig /flushdns | Out-Null
            $serverReachable = $true
        } else {
            Write-Fail "Need admin privileges to edit hosts file."
            Write-Host "    Run this script as Administrator, or manually add to $hostsPath :" -ForegroundColor White
            Write-Host "    $hostsEntry" -ForegroundColor White
        }
    } else {
        Write-Host ""
        Write-Host "    Could not find Ollama server on the network." -ForegroundColor White
        Write-Host "    Make sure:" -ForegroundColor White
        Write-Host "    - You are on the same WiFi/LAN as the AI server" -ForegroundColor White
        Write-Host "    - The server is powered on and Ollama is running" -ForegroundColor White
        if ($clientIP) {
            Write-Host "    - Your IP is: $clientIP (subnet: $subnet.x)" -ForegroundColor DarkGray
        }
    }

    if (-not $serverReachable) {
        $continue = Read-Host "    Continue anyway? (y/N)"
        if ($continue -ne "y") { return }
    }
}

# --- 3. Install Git ---

Write-Step "Checking Git"
if (Test-Command "git") {
    Write-OK "Git is installed ($(git --version))"
} else {
    Write-Host "    Installing Git via winget..." -ForegroundColor White
    winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
    Refresh-Path
    if (Test-Command "git") {
        Write-OK "Git installed"
    } else {
        Write-Fail "Git install may need a terminal restart. Continuing..."
    }
}

# --- 4. Install Node.js (required for Claude Code) ---

Write-Step "Checking Node.js"
if (Test-Command "node") {
    Write-OK "Node.js is installed ($(node --version))"
} else {
    Write-Host "    Installing Node.js LTS via winget..." -ForegroundColor White
    winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements
    Refresh-Path
    if (Test-Command "node") {
        Write-OK "Node.js installed ($(node --version))"
    } else {
        Write-Fail "Node.js install may need a terminal restart. Continuing..."
    }
}

# --- 5. Install Python ---

Write-Step "Checking Python"
if (Test-RealPython) {
    $pyVersion = (python --version 2>&1)
    Write-OK "Python is installed ($pyVersion)"
} else {
    Write-Host "    Installing Python via winget..." -ForegroundColor White
    winget install --id Python.Python.3.12 -e --accept-package-agreements --accept-source-agreements
    Refresh-Path
    if (Test-RealPython) {
        Write-OK "Python installed ($(python --version 2>&1))"
    } else {
        Write-Fail "Python install may need a terminal restart. Continuing..."
    }
}

# --- 6. Install Claude Code CLI ---

Write-Step "Installing Claude Code CLI"
if (Test-Command "claude") {
    Write-OK "Claude Code is already installed ($(claude --version 2>&1))"
} else {
    if (Test-Command "npm") {
        Write-Host "    Installing via npm (this may take a minute)..." -ForegroundColor White
        npm install -g @anthropic-ai/claude-code 2>&1 | Select-Object -Last 3
        Refresh-Path
        if (Test-Command "claude") {
            Write-OK "Claude Code installed"
        } else {
            Write-Fail "npm install succeeded but 'claude' not in PATH. Restart terminal and re-run."
        }
    } else {
        Write-Fail "npm not found. Restart terminal (Node.js PATH needs refresh), then re-run."
    }
}

# --- 7. Install Python packages ---

Write-Step "Installing Python packages for file generation (34 packages)"
$pipAvailable = $false
if (Test-RealPython) {
    # Always use 'python -m pip' -- more reliable than bare 'pip' on Windows
    $pipAvailable = $true
}

if ($pipAvailable) {
    $packages = @(
        "Pillow",
        "pandas", "openpyxl", "xlsxwriter", "xlrd",
        "matplotlib", "seaborn", "plotly", "scipy",
        "python-docx", "python-pptx",
        "fpdf2", "reportlab", "weasyprint", "pypdf", "pymupdf",
        "Jinja2", "Markdown", "tabulate", "lxml", "xmltodict", "pyyaml",
        "requests", "httpx", "beautifulsoup4", "chardet",
        "qrcode", "premailer", "cairosvg", "html2text", "markdownify",
        "trafilatura", "duckduckgo-search", "feedparser"
    )
    Write-Host "    This may take a few minutes..." -ForegroundColor DarkGray
    & python -m pip install --quiet $packages 2>&1 | ForEach-Object { $_ }
    if ($LASTEXITCODE -eq 0) {
        Write-OK "All Python packages installed"
    } else {
        Write-Fail "Some packages failed to install."
        Write-Host "    Retry manually: python -m pip install $($packages -join ' ')" -ForegroundColor White
    }
} else {
    Write-Fail "Python not found. Restart terminal after Python install, then re-run."
}

# --- 8. Set environment variables ---

# Determine the base URL -- use ai.local if it works, otherwise use discovered IP
$ollamaHost = "ai.local"
if (-not $serverReachable -and $serverIP) {
    $ollamaHost = $serverIP
}
$baseURL = "http://${ollamaHost}:11434"

Write-Step "Setting environment variables (persistent + current session)"
Write-Host "    Using server address: $ollamaHost" -ForegroundColor DarkGray
$currentBase = [System.Environment]::GetEnvironmentVariable("ANTHROPIC_BASE_URL", "User")
if ($currentBase -eq $baseURL) {
    Write-Skip "Environment variables already set"
} else {
    [System.Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", $baseURL, "User")
    [System.Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", "ollama", "User")
    Write-OK "Set ANTHROPIC_BASE_URL = $baseURL"
    Write-OK "Set ANTHROPIC_API_KEY = ollama"
}
# Set for current session regardless
$env:ANTHROPIC_BASE_URL = $baseURL
$env:ANTHROPIC_API_KEY = "ollama"

# --- 9. Download system prompt ---

Write-Step "Downloading system prompt"
$promptDir = Join-Path $env:USERPROFILE ".stocky"
if (-not (Test-Path $promptDir)) { New-Item -ItemType Directory -Path $promptDir | Out-Null }
$promptFile = Join-Path $promptDir "prompt.txt"
# Try ai.local first, then discovered IP, then hardcoded IP
$promptURLs = @("http://ai.local/stocky-prompt.txt")
if ($serverIP) { $promptURLs += "http://$serverIP/stocky-prompt.txt" }
$promptURLs += "http://192.168.29.100/stocky-prompt.txt"

$promptDownloaded = $false
foreach ($url in $promptURLs) {
    try {
        Invoke-WebRequest -Uri $url -OutFile $promptFile -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        Write-OK "Saved to $promptFile"
        $promptDownloaded = $true
        break
    } catch {}
}
if (-not $promptDownloaded) {
    Write-Fail "Could not download prompt. Copy scripts/stocky-prompt.txt from the server to: $promptFile"
}

# --- 10. Clear old claude.ai login if present ---

Write-Step "Checking for existing claude.ai login"
if (Test-Command "claude") {
    $claudeDir = Join-Path $env:USERPROFILE ".claude"
    $hasToken = $false
    if (Test-Path (Join-Path $claudeDir ".credentials.json")) { $hasToken = $true }
    if (Test-Path (Join-Path $claudeDir "credentials.json")) { $hasToken = $true }

    if ($hasToken) {
        Write-Host "    Found existing claude.ai credentials. Clearing to avoid conflicts..." -ForegroundColor White
        # Temporarily clear env vars so claude /logout talks to Anthropic, not Ollama
        $savedBase = $env:ANTHROPIC_BASE_URL
        $savedKey = $env:ANTHROPIC_API_KEY
        Remove-Item Env:ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
        Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
        claude /logout 2>&1 | Out-Null
        $env:ANTHROPIC_BASE_URL = $savedBase
        $env:ANTHROPIC_API_KEY = $savedKey
        Write-OK "Cleared old claude.ai login"
    } else {
        Write-Skip "No existing claude.ai login found"
    }
} else {
    Write-Skip "Claude not installed yet, skipping"
}

# --- 11. Create 'stocky' command in PowerShell profile ---

Write-Step "Setting up 'stocky' command in PowerShell profile"
$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }

# Build the stocky function with the correct server address baked in
$stockyFunction = @"

# Stocky AI -- local AI assistant (added by setup script)
function stocky {
    `$env:ANTHROPIC_BASE_URL = "$baseURL"
    `$env:ANTHROPIC_API_KEY = "ollama"
    `$promptPath = Join-Path `$env:USERPROFILE ".stocky\prompt.txt"
    if (Test-Path `$promptPath) {
        `$prompt = Get-Content `$promptPath -Raw
        `$claudeArgs = @('--model', 'qwen3:32b', '--append-system-prompt', `$prompt) + `$args
        & claude @claudeArgs
    } else {
        Write-Host "Warning: System prompt not found at `$promptPath. Running without it." -ForegroundColor Yellow
        claude --model qwen3:32b @args
    }
}
"@

$profileContent = ""
if (Test-Path $PROFILE) { $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue }
if ($profileContent -and $profileContent -match "function stocky") {
    # Remove old stocky function block and replace with updated version
    $cleaned = $profileContent -replace '(?ms)\r?\n?# Stocky AI -- local AI assistant[^\n]*\r?\nfunction stocky \{.*?\n\}', ''
    # Also handle case where comment line is missing
    if ($cleaned -match "function stocky") {
        $cleaned = $cleaned -replace '(?ms)\r?\n?function stocky \{.*?\n\}', ''
    }
    Set-Content -Path $PROFILE -Value $cleaned.TrimEnd() -NoNewline
    Add-Content -Path $PROFILE -Value $stockyFunction
    Write-OK "Updated 'stocky' function in $PROFILE"
} else {
    Add-Content -Path $PROFILE -Value $stockyFunction
    Write-OK "Added 'stocky' function to $PROFILE"
}

# --- 12. Verify setup ---

Write-Step "Verifying setup"
$allGood = $true

# Check each component
$checks = @(
    @{ Name = "Git";           Test = { Test-Command "git" } },
    @{ Name = "Node.js";       Test = { Test-Command "node" } },
    @{ Name = "Python";        Test = { Test-RealPython } },
    @{ Name = "Claude Code";   Test = { Test-Command "claude" } },
    @{ Name = "System prompt"; Test = { $p = Join-Path $env:USERPROFILE ".stocky\prompt.txt"; (Test-Path $p) -and ((Get-Item $p -ErrorAction SilentlyContinue).Length -gt 0) } },
    @{ Name = "Env vars";      Test = { $env:ANTHROPIC_BASE_URL -eq $baseURL } }
)

foreach ($check in $checks) {
    if (& $check.Test) {
        Write-OK $check.Name
    } else {
        Write-Fail "$($check.Name) -- needs terminal restart or manual install"
        $allGood = $false
    }
}

# Test server connection
if ($serverReachable) {
    Write-OK "Server connection"
} else {
    Write-Fail "Server connection -- see manual steps below"
    $allGood = $false
}

# --- Done ---

Write-Host ""
if ($allGood) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Setup complete! All checks passed." -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
} else {
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  Setup complete with warnings." -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "MANUAL STEPS (only if flagged above):" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Close and reopen PowerShell to pick up PATH and profile changes." -ForegroundColor White
Write-Host "     Then re-run this script to verify everything passes." -ForegroundColor DarkGray
Write-Host ""
Write-Host "  2. If 'stocky' gives a script loading error, run this in PowerShell:" -ForegroundColor White
Write-Host "     Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor White
Write-Host ""
Write-Host "  3. If ai.local doesn't resolve, run as Administrator:" -ForegroundColor White
Write-Host "     Add-Content $env:SystemRoot\System32\drivers\etc\hosts '192.168.29.100  ai.local'" -ForegroundColor White
Write-Host ""
Write-Host "  4. If 'weasyprint' fails (HTML-to-PDF) or 'cairosvg' fails (SVG):" -ForegroundColor White
Write-Host "     Install GTK3 runtime from:" -ForegroundColor White
Write-Host "     https://github.com/tschoonj/GTK-for-Windows-Runtime-Environment-Installer/releases" -ForegroundColor White
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Cyan
Write-Host "  1. Close this window and open a new PowerShell" -ForegroundColor White
Write-Host "  2. Type: stocky" -ForegroundColor White
Write-Host "  3. Start chatting with your local AI!" -ForegroundColor White
Write-Host ""
Write-Host "EXAMPLES:" -ForegroundColor Cyan
Write-Host "  stocky                                  # Interactive session" -ForegroundColor White
Write-Host "  stocky -p `"create a report.xlsx`"        # One-shot command" -ForegroundColor White
Write-Host "  cat data.csv | stocky -p `"analyze this`" # Pipe data in" -ForegroundColor White
Write-Host ""

} catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "If this keeps happening, open PowerShell manually and run:" -ForegroundColor White
    Write-Host "  powershell -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -ForegroundColor White
    Write-Host ""
} finally {
    # Always pause -- keeps the window open so the user can read output
    Write-Host ""
    Read-Host "Press Enter to close"
}
