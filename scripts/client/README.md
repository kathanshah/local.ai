# Client Setup Scripts

Setup scripts for connecting Windows and macOS machines to the Stocky AI server. No accounts or server-side setup needed -- any device on the local network can connect.

## How It Works

```
Client machine                         AI Server (ai.local)
+------------------+                   +----------------------+
| stocky command   |------ HTTP ------>| Ollama API :11434    |
| (Claude Code CLI)|                   | Qwen3-32B on GPU     |
|                  |                   |                      |
| Files created    |                   | AI inference only    |
| locally on client|                   | No data stored       |
+------------------+                   +----------------------+
```

The AI model runs on the server GPU. Claude Code runs on the client and executes file operations (Excel, PDF, charts, etc.) locally. No Ollama install needed on the client -- only the server runs Ollama.

---

## Windows

### Requirements

- Windows 10 or 11
- PowerShell 5.1+
- [winget](https://apps.microsoft.com/detail/9nblggh4nns1) (App Installer -- pre-installed on Windows 11, install from Microsoft Store on Windows 10)

### Run

Copy the `client` folder (or at minimum `setup-windows.bat` + `setup-windows.ps1`) to the client machine, then:

**Option A -- Double-click** `setup-windows.bat` (easiest, handles execution policy automatically)

**Option B -- PowerShell manually:**
```powershell
powershell -ExecutionPolicy Bypass -File setup-windows.ps1
```

Run as **Administrator** for full automation (hosts file, execution policy, global installs). Without admin, the script still works but may flag manual steps.

### What it installs

| Component | Method |
|-----------|--------|
| Execution policy (RemoteSigned) | PowerShell |
| Git | winget |
| Node.js LTS | winget |
| Python 3.12 | winget |
| Claude Code CLI | npm |
| 34 Python packages | pip |
| `stocky` command | batch file (`~/.stocky/stocky.cmd`) added to PATH |

### After setup

1. **Close the setup window**
2. **Open a new terminal** (PowerShell or cmd.exe -- both work)
3. Type `stocky` and press Enter
4. Start chatting with your local AI!

### First run -- login screen fix

If claude shows a login screen (asking for "Claude account", "Anthropic account", etc.), it needs a credentials file to skip the auth flow. Create it manually:

**cmd.exe:**
```cmd
mkdir "%USERPROFILE%\.claude" 2>nul
echo {"apiKey":"ollama"} > "%USERPROFILE%\.claude\.credentials.json"
set ANTHROPIC_BASE_URL=http://ai.local:11434
set ANTHROPIC_API_KEY=ollama
set ANTHROPIC_AUTH_TOKEN=
claude --model qwen3:32b
```

**PowerShell:**
```powershell
New-Item -ItemType Directory -Path "$env:USERPROFILE\.claude" -Force | Out-Null
'{"apiKey":"ollama"}' | Set-Content "$env:USERPROFILE\.claude\.credentials.json"
$env:ANTHROPIC_BASE_URL = "http://ai.local:11434"
$env:ANTHROPIC_API_KEY = "ollama"
$env:ANTHROPIC_AUTH_TOKEN = ""
claude --model qwen3:32b
```

The credentials file tells Claude Code that auth is handled (the actual connection uses the env vars to reach your local Ollama server). You only need to do this once -- the setup script does it automatically.

### Running manually (without the stocky command)

The setup script sets env vars permanently. After a terminal restart, you can just run:

```
claude --model qwen3:32b
```

Or set env vars explicitly in any terminal:

```cmd
set ANTHROPIC_BASE_URL=http://ai.local:11434
set ANTHROPIC_API_KEY=ollama
set ANTHROPIC_AUTH_TOKEN=
claude --model qwen3:32b
```

### Manual steps (only if flagged by the script)

1. **Restart terminal** -- close and reopen to pick up PATH changes. Then re-run the setup script to verify everything passes.

2. **Hosts file** (if not admin and `ai.local` doesn't resolve) -- the script auto-detects the server IP on your subnet. If it can't find it, manually add to `C:\Windows\System32\drivers\etc\hosts`:
   ```
   192.168.29.100  ai.local
   ```
   (Replace with the actual server IP if on a different subnet)

3. **GTK3 runtime** (optional) -- needed only if `weasyprint` (HTML-to-PDF) or `cairosvg` (SVG conversion) fails. Download from [GTK for Windows](https://github.com/tschoonj/GTK-for-Windows-Runtime-Environment-Installer/releases)

---

## macOS

### Requirements

- macOS (with Terminal access)
- Xcode Command Line Tools get installed automatically by Homebrew if missing

### Run

Copy `setup-mac.sh` to the client machine, then run:

```bash
bash setup-mac.sh
```

Or from within the repo:

```bash
bash scripts/client/setup-mac.sh
```

> **Do not** pipe directly to bash (`curl | bash`). The script has interactive prompts (sudo password, continue-on-error) that need terminal input.

### What it installs

| Component | Method |
|-----------|--------|
| Homebrew | official installer |
| Git | brew |
| Node.js | brew |
| Python 3 | brew |
| Claude Code CLI | npm |
| Cairo, Pango, etc. | brew (for PDF/SVG rendering) |
| 34 Python packages | pip3 |
| `stocky` command | shell alias in ~/.zshrc |

### After setup

1. **Close Terminal and open a new one**
2. Type `stocky` and press Enter
3. Start chatting with your local AI!

### First run -- login screen fix

If claude shows a login screen, create a credentials file to skip it:

```bash
mkdir -p ~/.claude
echo '{"apiKey":"ollama"}' > ~/.claude/.credentials.json
export ANTHROPIC_BASE_URL="http://ai.local:11434"
export ANTHROPIC_API_KEY="ollama"
export ANTHROPIC_AUTH_TOKEN=""
claude --model qwen3:32b
```

You only need to do this once -- the setup script does it automatically.

### Manual steps (only if flagged by the script)

1. **Restart terminal** -- close and reopen to pick up PATH and alias changes. Then re-run the setup script to verify everything passes.

2. **Hosts file** (rare -- macOS resolves `.local` via Bonjour automatically) -- the script auto-detects the server IP and updates `/etc/hosts` if needed. If it can't find the server:
   ```bash
   sudo sh -c 'echo "192.168.29.100  ai.local" >> /etc/hosts'
   ```

---

## Usage

After setup, open a **new terminal** and run:

```
stocky                                  # Interactive session
stocky -p "create a report.xlsx"        # One-shot command
cat data.csv | stocky -p "analyze this" # Pipe data in
```

> **Windows note:** `stocky` works in both PowerShell and cmd.exe.

## What clients can do

- Create Excel, Word, PowerPoint, PDF files
- Read and analyze CSV/Excel data with charts
- Search the web and summarize results
- Scrape web pages and extract data
- Generate QR codes, convert SVG to PNG
- Merge/split PDFs, convert between formats

All file operations run locally on the client. The server only provides AI inference.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Claude asks for login | Create credentials file: `echo {"apiKey":"ollama"} > ~/.claude/.credentials.json` (see "First run" above) |
| `ai.local` doesn't resolve | Re-run setup script -- it auto-detects the server IP. Or manually add to hosts file |
| `stocky` not found | Close and reopen terminal to pick up PATH changes |
| `weasyprint`/`cairosvg` errors | Windows: install GTK3 runtime. Mac: `brew install cairo pango gdk-pixbuf libffi` |
| pip "externally-managed-environment" | Mac: re-run script (auto-detects `--break-system-packages`) |
| Connection timeout | Check server is on, same network, Ollama running |
| Python detected but not real (Windows) | Disable Windows Store Python aliases in Settings > Apps > Advanced app settings > App execution aliases |
| Server IP changed (moved networks) | Re-run the setup script -- it scans for the server and updates everything |
