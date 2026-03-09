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

The AI model runs on the server GPU. Claude Code runs on the client and executes file operations (Excel, PDF, charts, etc.) locally.

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
| `stocky` command | PowerShell profile |

### After setup

1. **Fix execution policy** (required once) -- run this in PowerShell:
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
   ```
   Without this, Windows blocks all local scripts (including the `stocky` profile function). You only need to do this once per user account.

2. **Close the setup window**
3. **Open a new PowerShell window**
4. Type `stocky` and press Enter
5. Start chatting with your local AI!

> **Important:** If you skip step 1, you will see an error like: `File Microsoft.PowerShell_profile.ps1 cannot be loaded because running scripts is disabled on this system.` Just run the command above and reopen PowerShell.

### Manual steps (only if flagged by the script)

1. **Restart PowerShell** -- close and reopen to pick up PATH and profile changes. Then re-run the setup script to verify everything passes.

2. **Execution policy error** -- if `stocky` gives "loading scripts is disabled" or "cannot be loaded because running scripts is disabled", run this in PowerShell:
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
   ```
   Then close and reopen PowerShell.

3. **Hosts file** (if not admin and `ai.local` doesn't resolve) -- the script auto-detects the server IP on your subnet. If it can't find it, manually add to `C:\Windows\System32\drivers\etc\hosts`:
   ```
   192.168.29.100  ai.local
   ```
   (Replace with the actual server IP if on a different subnet)

4. **"unknown option '-36px'" error** -- if `stocky` gives `error: unknown option '-36px'` (or similar), the PowerShell profile has an older stocky function that doesn't pass the system prompt correctly. Fix it:
   1. Open PowerShell and run: `notepad $PROFILE`
   2. Find the `function stocky {` block and replace it with:
      ```powershell
      function stocky {
          $env:ANTHROPIC_BASE_URL = "http://ai.local:11434"
          $env:ANTHROPIC_API_KEY = "ollama"
          $promptPath = Join-Path $env:USERPROFILE ".stocky\prompt.txt"
          if (Test-Path $promptPath) {
              $env:_STOCKY_PROMPT = (Get-Content $promptPath -Raw) -replace '[\r\n]+', ' ' -replace '"', ''
              if ($args.Count -gt 0) {
                  $env:_STOCKY_UARGS = ($args | ForEach-Object { if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ } }) -join ' '
                  claude --% --model qwen3:32b --append-system-prompt "%_STOCKY_PROMPT%" %_STOCKY_UARGS%
              } else {
                  claude --% --model qwen3:32b --append-system-prompt "%_STOCKY_PROMPT%"
              }
          } else {
              Write-Host "Warning: System prompt not found at $promptPath. Running without it." -ForegroundColor Yellow
              claude --model qwen3:32b @args
          }
      }
      ```
      (Replace `http://ai.local:11434` with your server's actual address if different)
   3. Save, close notepad, close and reopen PowerShell
   4. Run `stocky` again

   Alternatively, re-run the setup script -- it will detect and update the old function automatically.

5. **GTK3 runtime** (optional) -- needed only if `weasyprint` (HTML-to-PDF) or `cairosvg` (SVG conversion) fails. Download from [GTK for Windows](https://github.com/tschoonj/GTK-for-Windows-Runtime-Environment-Installer/releases)

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

### Manual steps (only if flagged by the script)

1. **Restart terminal** -- close and reopen to pick up PATH and alias changes. Then re-run the setup script to verify everything passes.

2. **Hosts file** (rare -- macOS resolves `.local` via Bonjour automatically) -- the script auto-detects the server IP and updates `/etc/hosts` if needed. If it can't find the server:
   ```bash
   sudo sh -c 'echo "192.168.29.100  ai.local" >> /etc/hosts'
   ```

---

## Usage

After setup, open a **new terminal** (PowerShell on Windows, Terminal on Mac) and run:

```
stocky                                  # Interactive session
stocky -p "create a report.xlsx"        # One-shot command
cat data.csv | stocky -p "analyze this" # Pipe data in
```

> **Windows note:** `stocky` only works in PowerShell, not cmd.exe.

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
| `ai.local` doesn't resolve | Re-run setup script -- it auto-detects the server IP. Or manually add to hosts file |
| "loading scripts is disabled" (Windows) | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| `stocky` not found | Close and reopen terminal. Windows: `. $PROFILE` / Mac: `source ~/.zshrc` |
| "Both a token and an API key are set" | Run `claude /logout` to clear old cloud login |
| `weasyprint`/`cairosvg` errors | Windows: install GTK3 runtime. Mac: `brew install cairo pango gdk-pixbuf libffi` |
| pip "externally-managed-environment" | Mac: re-run script (auto-detects `--break-system-packages`) |
| Connection timeout | Check server is on, same network, Ollama running |
| Python detected but not real (Windows) | Disable Windows Store Python aliases in Settings > Apps > Advanced app settings > App execution aliases |
| Server IP changed (moved networks) | Re-run the setup script -- it scans for the server and updates everything |
