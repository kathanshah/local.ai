# Client Setup Scripts

Setup scripts for connecting Windows and macOS machines to the Stocky AI server. No accounts or server-side setup needed — any device on the local network can connect.

## How It Works

```
Client machine                         AI Server (ai.local)
┌─────────────────┐                    ┌─────────────────────┐
│ stocky command   │───── HTTP ────────▶│ Ollama API :11434   │
│ (Claude Code CLI)│                    │ Qwen3-32B on GPU    │
│                  │                    │                     │
│ Files created    │                    │ AI inference only   │
│ locally on client│                    │ No data stored      │
└─────────────────┘                    └─────────────────────┘
```

The AI model runs on the server GPU. Claude Code runs on the client and executes file operations (Excel, PDF, charts, etc.) locally.

---

## Windows

### Requirements

- Windows 10 or 11
- PowerShell 5.1+
- [winget](https://apps.microsoft.com/detail/9nblggh4nns1) (App Installer — pre-installed on Windows 11, install from Microsoft Store on Windows 10)

### Run

Copy the `client` folder (or at minimum `setup-windows.bat` + `setup-windows.ps1`) to the client machine, then:

**Option A — Double-click** `setup-windows.bat` (easiest, handles execution policy automatically)

**Option B — PowerShell manually:**
```powershell
powershell -ExecutionPolicy Bypass -File setup-windows.ps1
```

Run as **Administrator** for full automation (hosts file, global installs). Without admin, the script still works but may flag manual steps.

### What it installs

| Component | Method |
|-----------|--------|
| Git | winget |
| Node.js LTS | winget |
| Python 3.12 | winget |
| Claude Code CLI | npm |
| 34 Python packages | pip |

### Manual steps after script (only if flagged)

1. **Restart terminal** — PATH changes from installs need a new PowerShell window
2. **Hosts file** (if not admin and mDNS fails) — add `192.168.29.100  ai.local` to the hosts file (the script prints the exact path)
3. **GTK3 runtime** (optional) — needed only if `weasyprint` or `cairosvg` fails. Download from [GTK for Windows](https://github.com/tschoonj/GTK-for-Windows-Runtime-Environment-Installer/releases)

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

### Manual steps after script (only if flagged)

1. **Restart terminal** — PATH and alias changes need a new shell
2. **Hosts file** (rare — macOS resolves `.local` via Bonjour automatically) — `sudo sh -c 'echo "192.168.29.100  ai.local" >> /etc/hosts'`

---

## Usage

After setup, run `stocky` from any terminal:

```bash
# Interactive session
stocky

# One-shot command
stocky -p "create a report.xlsx with Q1 sales data"

# Pipe data in
cat data.csv | stocky -p "analyze this and find outliers"
```

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
| `ai.local` doesn't resolve | Add `192.168.29.100  ai.local` to hosts file |
| "Both a token and an API key are set" warning | Run `claude /logout` to clear old cloud login |
| `weasyprint`/`cairosvg` import errors | Windows: install GTK3 runtime. Mac: `brew install cairo pango gdk-pixbuf libffi` |
| pip fails with "externally-managed-environment" | Mac: re-run script (auto-detects and adds `--break-system-packages`) |
| `stocky` command not found | Restart terminal, or run `source ~/.zshrc` (Mac) / `. $PROFILE` (Windows) |
| Connection timeout | Check server is on, same network (192.168.29.x), Ollama running |
| Python detected but not real (Windows) | Disable the Windows Store "app execution aliases" for Python in Settings > Apps > Advanced app settings > App execution aliases |
