#!/bin/bash
# Stocky AI — macOS Client Setup
# Installs Claude Code CLI and configures it to use the local AI server (ai.local).
#
# Usage:
#   bash scripts/client/setup-mac.sh
#   # or download and run:
#   curl -fsSL http://ai.local/client/setup-mac.sh -o /tmp/setup-mac.sh && bash /tmp/setup-mac.sh
#
# NOTE: Do NOT pipe directly to bash (curl | bash). This script has interactive
# prompts and installs Homebrew, which both require terminal input.
#
# What this script does:
#   1. Checks network connectivity to ai.local
#   2. Installs Homebrew, Git, Node.js, Python if missing
#   3. Installs Claude Code CLI via npm
#   4. Installs native libs for weasyprint/cairosvg
#   5. Installs all Python packages for file generation
#   6. Sets environment variables for ai.local connection
#   7. Downloads the system prompt file
#   8. Clears any existing claude.ai login
#   9. Creates a 'stocky' shell alias
#  10. Verifies the full setup

# Don't use set -e globally — we handle errors per-step
set +e

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Stocky AI — macOS Client Setup${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

step()  { echo -e "\n${YELLOW}[*] $1${NC}"; }
ok()    { echo -e "    ${GREEN}OK: $1${NC}"; }
skip()  { echo -e "    ${GRAY}SKIP: $1${NC}"; }
fail()  { echo -e "    ${RED}FAIL: $1${NC}"; }
info()  { echo -e "    $1"; }

# Prompt user — reads from /dev/tty so it works even if stdin is redirected
ask() {
    local prompt="$1" reply
    read -rp "$prompt" reply < /dev/tty 2>/dev/null || reply="n"
    echo "$reply"
}

ERRORS=0

# Detect shell config file (macOS defaults to zsh since Catalina)
if [[ "$SHELL" == */zsh ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
else
    SHELL_RC="$HOME/.bashrc"
fi

# Ensure the shell rc file exists
touch "$SHELL_RC"

# --- 1. Check network connectivity to ai.local ---

step "Checking network connectivity to ai.local"
SERVER_REACHABLE=false
if curl -sf --connect-timeout 5 "http://ai.local:11434/api/version" > /dev/null 2>&1; then
    ok "ai.local is reachable (Ollama API responding)"
    SERVER_REACHABLE=true
else
    fail "Cannot reach ai.local:11434"

    # Try by IP to distinguish DNS vs network issue
    if curl -sf --connect-timeout 5 "http://192.168.29.100:11434/api/version" > /dev/null 2>&1; then
        info "Server is reachable by IP but 'ai.local' doesn't resolve."
        info "macOS usually resolves .local via Bonjour automatically."
        info "If Bonjour isn't working, adding hosts entry..."

        if grep -q "ai\.local" /etc/hosts 2>/dev/null; then
            skip "hosts file already contains ai.local entry"
        else
            echo "    Adding 192.168.29.100 ai.local to /etc/hosts (needs sudo)..."
            sudo sh -c 'echo "192.168.29.100  ai.local" >> /etc/hosts'
            if [ $? -eq 0 ]; then
                ok "Added hosts entry"
                sudo dscacheutil -flushcache 2>/dev/null
                sudo killall -HUP mDNSResponder 2>/dev/null
                # Re-verify the connection now works
                sleep 1
                if curl -sf --connect-timeout 5 "http://ai.local:11434/api/version" > /dev/null 2>&1; then
                    ok "Verified: ai.local now resolves correctly"
                    SERVER_REACHABLE=true
                else
                    fail "hosts entry added but ai.local still not reachable. May need terminal restart."
                fi
            else
                fail "Could not write to /etc/hosts"
            fi
        fi
    else
        echo ""
        info "Make sure:"
        info "- You are on the same network as the AI server (192.168.29.x)"
        info "- The server is powered on and Ollama is running"
    fi

    if [ "$SERVER_REACHABLE" = false ]; then
        cont=$(ask "    Continue anyway? (y/N) ")
        if [ "$cont" != "y" ]; then exit 1; fi
    fi
fi

# --- 2. Install Homebrew if missing ---

step "Checking Homebrew"
if command -v brew &> /dev/null; then
    ok "Homebrew is installed"
else
    echo "    Installing Homebrew (will prompt for password)..."
    # NONINTERACTIVE=1 skips the confirmation prompt but still needs sudo password
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH — Apple Silicon uses /opt/homebrew, Intel uses /usr/local
    if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        if ! grep -q "homebrew" "$SHELL_RC" 2>/dev/null; then
            echo '' >> "$SHELL_RC"
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$SHELL_RC"
        fi
    elif [ -f /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    if command -v brew &> /dev/null; then
        ok "Homebrew installed"
    else
        fail "Homebrew install failed. Install manually: https://brew.sh"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Guard: if brew isn't available, we can't install anything below
if ! command -v brew &> /dev/null; then
    fail "Homebrew is required for the remaining steps. Install it and re-run."
    exit 1
fi

# --- 3. Install Git ---

step "Checking Git"
if command -v git &> /dev/null; then
    ok "Git is installed ($(git --version 2>&1 | head -1))"
else
    echo "    Installing Git..."
    brew install git
    if command -v git &> /dev/null; then
        ok "Git installed"
    else
        fail "Git install failed"
        ERRORS=$((ERRORS + 1))
    fi
fi

# --- 4. Install Node.js ---

step "Checking Node.js"
if command -v node &> /dev/null; then
    ok "Node.js is installed ($(node --version))"
else
    echo "    Installing Node.js..."
    brew install node
    if command -v node &> /dev/null; then
        ok "Node.js installed ($(node --version))"
    else
        fail "Node.js install failed"
        ERRORS=$((ERRORS + 1))
    fi
fi

# --- 5. Install Python ---

step "Checking Python 3"
if command -v python3 &> /dev/null; then
    ok "Python is installed ($(python3 --version))"
else
    echo "    Installing Python..."
    brew install python
    if command -v python3 &> /dev/null; then
        ok "Python installed ($(python3 --version))"
    else
        fail "Python install failed"
        ERRORS=$((ERRORS + 1))
    fi
fi

# --- 6. Install Claude Code CLI ---

step "Installing Claude Code CLI"
if command -v claude &> /dev/null; then
    ok "Claude Code is already installed ($(claude --version 2>&1 | head -1))"
else
    if command -v npm &> /dev/null; then
        echo "    Installing via npm (this may take a minute)..."
        npm install -g @anthropic-ai/claude-code 2>&1 | tail -3
        if command -v claude &> /dev/null; then
            ok "Claude Code installed"
        else
            fail "npm install succeeded but 'claude' not in PATH. Restart terminal and re-run."
            ERRORS=$((ERRORS + 1))
        fi
    else
        fail "npm not found. Restart terminal (Node.js PATH needs refresh), then re-run."
        ERRORS=$((ERRORS + 1))
    fi
fi

# --- 7. Install native libs for weasyprint/cairosvg ---

step "Installing native libraries (cairo, pango, etc.)"
if brew list cairo &> /dev/null && brew list pango &> /dev/null; then
    ok "Cairo and Pango already installed"
else
    echo "    Installing via brew (needed for PDF/SVG rendering)..."
    brew install cairo pango gdk-pixbuf libffi 2>&1 | tail -3
    if brew list cairo &> /dev/null; then
        ok "Native libraries installed"
    else
        fail "Some native libs failed. weasyprint/cairosvg may not work."
    fi
fi

# --- 8. Install Python packages ---

step "Installing Python packages for file generation (34 packages)"
if command -v pip3 &> /dev/null || command -v python3 &> /dev/null; then
    PIP_CMD="pip3"
    if ! command -v pip3 &> /dev/null; then
        PIP_CMD="python3 -m pip"
    fi

    # Detect if --break-system-packages is needed (PEP 668, pip >= 23.1)
    PIP_EXTRA_FLAGS=""
    if ${PIP_CMD} install --help 2>&1 | grep -q "break-system-packages"; then
        PIP_EXTRA_FLAGS="--break-system-packages"
    fi

    ${PIP_CMD} install ${PIP_EXTRA_FLAGS} --quiet \
        Pillow \
        pandas openpyxl xlsxwriter xlrd \
        matplotlib seaborn plotly scipy \
        python-docx python-pptx \
        fpdf2 reportlab weasyprint pypdf pymupdf \
        Jinja2 Markdown tabulate lxml xmltodict pyyaml \
        requests httpx beautifulsoup4 chardet \
        qrcode premailer cairosvg html2text markdownify \
        trafilatura duckduckgo-search feedparser
    PIP_EXIT=$?

    if [ $PIP_EXIT -eq 0 ]; then
        ok "All Python packages installed"
    else
        fail "Some packages failed. Check output above."
        info "Retry manually: ${PIP_CMD} install ${PIP_EXTRA_FLAGS} Pillow pandas openpyxl xlsxwriter xlrd matplotlib seaborn plotly scipy python-docx python-pptx fpdf2 reportlab weasyprint pypdf pymupdf Jinja2 Markdown tabulate lxml xmltodict pyyaml requests httpx beautifulsoup4 chardet qrcode premailer cairosvg html2text markdownify trafilatura duckduckgo-search feedparser"
        ERRORS=$((ERRORS + 1))
    fi
else
    fail "pip3/python3 not found. Restart terminal after Python install, then re-run."
    ERRORS=$((ERRORS + 1))
fi

# --- 9. Set environment variables ---

step "Setting environment variables in $SHELL_RC"
if grep -q "ANTHROPIC_BASE_URL.*ai\.local" "$SHELL_RC" 2>/dev/null; then
    skip "Environment variables already set in $SHELL_RC"
else
    cat >> "$SHELL_RC" << 'ENVEOF'

# Stocky AI — local AI server connection (added by setup script)
export ANTHROPIC_BASE_URL="http://ai.local:11434"
export ANTHROPIC_API_KEY="ollama"
ENVEOF
    ok "Added ANTHROPIC_BASE_URL and ANTHROPIC_API_KEY to $SHELL_RC"
fi
# Set for current session
export ANTHROPIC_BASE_URL="http://ai.local:11434"
export ANTHROPIC_API_KEY="ollama"

# --- 10. Download system prompt ---

step "Downloading system prompt"
mkdir -p "$HOME/.stocky"
if curl -sf --connect-timeout 10 "http://ai.local/stocky-prompt.txt" -o "$HOME/.stocky/prompt.txt" 2>/dev/null; then
    ok "Saved to ~/.stocky/prompt.txt"
elif curl -sf --connect-timeout 10 "http://192.168.29.100/stocky-prompt.txt" -o "$HOME/.stocky/prompt.txt" 2>/dev/null; then
    ok "Saved to ~/.stocky/prompt.txt (via IP fallback)"
else
    fail "Could not download prompt. Copy scripts/stocky-prompt.txt from the server to: ~/.stocky/prompt.txt"
    ERRORS=$((ERRORS + 1))
fi

# --- 11. Clear old claude.ai login if present ---

step "Checking for existing claude.ai login"
if command -v claude &> /dev/null; then
    if [ -f "$HOME/.claude/.credentials.json" ] || [ -f "$HOME/.claude/credentials.json" ]; then
        info "Found existing claude.ai credentials. Clearing to avoid conflicts..."
        # Unset env vars so claude /logout talks to Anthropic's servers, not Ollama
        (
            unset ANTHROPIC_BASE_URL ANTHROPIC_API_KEY
            claude /logout 2>/dev/null
        )
        ok "Cleared old claude.ai login"
    else
        skip "No existing claude.ai login found"
    fi
else
    skip "Claude not installed yet, skipping"
fi

# --- 12. Create 'stocky' alias ---

step "Setting up 'stocky' command in $SHELL_RC"
if grep -q "alias stocky=" "$SHELL_RC" 2>/dev/null || grep -q "function stocky" "$SHELL_RC" 2>/dev/null; then
    skip "'stocky' alias already exists in $SHELL_RC"
else
    cat >> "$SHELL_RC" << 'ALIASEOF'

# Stocky AI — local AI assistant command (added by setup script)
alias stocky='ANTHROPIC_BASE_URL="http://ai.local:11434" ANTHROPIC_API_KEY="ollama" claude --model qwen3:32b --append-system-prompt "$(cat ~/.stocky/prompt.txt)"'
ALIASEOF
    ok "Added 'stocky' alias to $SHELL_RC"
fi

# --- 13. Verify setup ---

step "Verifying setup"
VERIFY_PASS=true

for check in "git:Git" "node:Node.js" "python3:Python" "claude:Claude Code"; do
    cmd="${check%%:*}"
    name="${check##*:}"
    if command -v "$cmd" &> /dev/null; then
        ok "$name"
    else
        fail "$name — restart terminal and re-run script"
        VERIFY_PASS=false
    fi
done

if [ -f "$HOME/.stocky/prompt.txt" ] && [ -s "$HOME/.stocky/prompt.txt" ]; then
    ok "System prompt"
else
    fail "System prompt — download manually from server"
    VERIFY_PASS=false
fi

if grep -q "ANTHROPIC_BASE_URL" "$SHELL_RC" 2>/dev/null; then
    ok "Env vars in $SHELL_RC"
else
    fail "Env vars — not found in $SHELL_RC"
    VERIFY_PASS=false
fi

if [ "$SERVER_REACHABLE" = true ]; then
    ok "Server connection"
else
    fail "Server connection — check network"
    VERIFY_PASS=false
fi

# --- Done ---

echo ""
if [ "$VERIFY_PASS" = true ] && [ "$ERRORS" -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Setup complete! All checks passed.${NC}"
    echo -e "${GREEN}========================================${NC}"
else
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  Setup complete with warnings.${NC}"
    echo -e "${YELLOW}========================================${NC}"
fi

echo ""
echo -e "${YELLOW}MANUAL STEPS (only if flagged above):${NC}"
echo ""
echo "  1. Restart your terminal to pick up PATH and alias changes"
echo "     Then re-run this script to verify everything passes."
echo ""
echo "  2. If ai.local still doesn't resolve after restart:"
echo "     sudo sh -c 'echo \"192.168.29.100  ai.local\" >> /etc/hosts'"
echo ""
echo -e "${CYAN}USAGE:${NC}"
echo "  stocky                                  # Interactive session"
echo "  stocky -p \"create a report.xlsx\"         # One-shot command"
echo "  cat data.csv | stocky -p \"analyze this\"  # Pipe data in"
echo ""
