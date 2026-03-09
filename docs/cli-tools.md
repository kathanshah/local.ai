# CLI Coding Assistants

Terminal-based AI agents that can read/write files, run commands, and generate documents. This page covers which tools work with our setup and how to use them.

---

## Recommendation

**Claude Code** is the best CLI for this server. It natively connects to the local Ollama instance (free, private, offline) and has the most reliable tool calling of any CLI tested. It also works from client machines on the network.

| Tool | Works with Ollama | Works offline | Tool calling | Cost (local) |
|------|-------------------|---------------|-------------|--------------|
| **Claude Code** | Yes (native Anthropic API compat) | Yes | Reliable | Free |
| OpenCode | Yes (but unreliable) | Yes | Frequently fails silently | Free |
| CodeBuff | No (cloud only) | No | N/A | Pay-per-use |

---

## Claude Code + Local Ollama (Recommended)

### On the server

Already installed (v2.1.71). No Anthropic account or login needed — the wrapper script handles all auth. Just run:
```bash
bash scripts/claude-local.sh
```

Or with a one-shot command:
```bash
bash scripts/claude-local.sh -p "create an Excel file at ~/report.xlsx with Q1 sales data"
```

The wrapper sets these environment variables and activates a Python venv:
```bash
export ANTHROPIC_BASE_URL="http://localhost:11434"
export ANTHROPIC_API_KEY="ollama"
unset ANTHROPIC_AUTH_TOKEN   # Prevent conflict with stored claude.ai login
unset CLAUDECODE             # Prevent nested-session detection
export PATH="/mnt/ai-models/claude-code-env/bin:$PATH"  # Python venv with all file generation packages
```

The wrapper also appends a system prompt (`--append-system-prompt`) that tells the model to use `python3` via the Bash tool directly instead of Jupyter notebooks, and lists all available packages. This gives Claude Code direct access to Python with 25+ packages for file generation (Excel, Word, PowerPoint, PDF, charts, images) without needing Jupyter or Docker. See the full package list in the client section below.

### On client machines (any computer on the network)

#### Automated setup (recommended)

Setup scripts handle everything — Git, Node.js, Python, Claude Code, 34 Python packages, environment variables, system prompt download, and the `stocky` shell command:

```powershell
# Windows — copy setup-windows.ps1 to the client, then run in PowerShell (as Admin recommended):
powershell -ExecutionPolicy Bypass -File setup-windows.ps1
```

```bash
# macOS — copy setup-mac.sh to the client, then run:
bash setup-mac.sh
```

Scripts are in `scripts/client/`. See [client README](../scripts/client/README.md) for requirements, what gets installed, manual steps (if any), and troubleshooting.

After setup, run `stocky` from any terminal. No Anthropic account or login needed. The AI thinks on the server GPU; file operations run on the client.

#### Manual setup (reference)

If you prefer to set things up manually or are on Linux, here's what the scripts do:

**Prerequisites:** Git, Node.js 18+, Python 3.10+

**Install Claude Code:**
```bash
npm install -g @anthropic-ai/claude-code
```

**Install Python packages (34 packages including Pillow):**
```bash
pip install Pillow pandas openpyxl xlsxwriter xlrd matplotlib seaborn plotly scipy python-docx python-pptx fpdf2 reportlab weasyprint pypdf pymupdf Jinja2 Markdown tabulate lxml xmltodict pyyaml requests httpx beautifulsoup4 chardet qrcode premailer cairosvg html2text markdownify trafilatura duckduckgo-search feedparser
```

**What each package does:**

| Category | Package | What it does |
|----------|---------|-------------|
| **Spreadsheets** | `pandas` | Read/write CSV, Excel, JSON, SQL; filter, group, pivot data |
| | `openpyxl` | Read/write `.xlsx` files (Excel 2010+) |
| | `xlsxwriter` | Create `.xlsx` with formatting, charts, formulas |
| | `xlrd` | Read old `.xls` files (pre-2007 Excel) |
| **Documents** | `python-docx` | Create/read Word `.docx` files |
| | `python-pptx` | Create/read PowerPoint `.pptx` presentations |
| | `Markdown` | Convert Markdown to HTML |
| **PDF** | `fpdf2` | Create simple PDFs (invoices, letters, reports) |
| | `reportlab` | Create complex PDF layouts (pixel-precise control) |
| | `weasyprint` | Convert HTML+CSS to PDF (best for styled reports) |
| | `pypdf` | Merge, split, encrypt, watermark existing PDFs |
| | `pymupdf` | Read/extract text from PDFs (fast, full-featured) |
| **Charts** | `matplotlib` | Static charts (bar, line, pie, scatter, etc.) |
| | `seaborn` | Statistical charts with better styling |
| | `plotly` | Interactive HTML charts and dashboards |
| **Data** | `scipy` | Statistical analysis, curve fitting |
| | `lxml` | Fast XML/HTML parsing |
| | `xmltodict` | XML ↔ Python dict conversion |
| | `pyyaml` | Read/write YAML files |
| | `chardet` | Detect file encoding (UTF-8, Latin-1, etc.) |
| **Web/HTML** | `requests` | Download files, call APIs |
| | `httpx` | Modern HTTP client (async, HTTP/2, faster) |
| | `beautifulsoup4` | Parse HTML/XML, scrape web tables |
| | `Jinja2` | HTML template engine (for report generation) |
| | `tabulate` | Pretty-print tables as HTML, Markdown, or text |
| | `premailer` | Inline CSS for HTML emails |
| | `html2text` | Convert HTML to clean Markdown |
| | `markdownify` | HTML to Markdown with fine-grained control |
| **Web research** | `trafilatura` | Extract article text from any URL (reader mode) |
| | `duckduckgo-search` | Search the web programmatically (no API key) |
| | `feedparser` | Parse RSS/Atom news feeds |
| **Images** | `Pillow` | Resize, crop, rotate, convert images |
| | `cairosvg` | Convert SVG to PNG/PDF |
| | `qrcode` | Generate QR code images |

**Set environment variables:**
```bash
# Linux / macOS — add to ~/.bashrc or ~/.zshrc
export ANTHROPIC_BASE_URL="http://ai.local:11434"
export ANTHROPIC_API_KEY="ollama"
```
```powershell
# Windows — run in PowerShell
[System.Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", "http://ai.local:11434", "User")
[System.Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", "ollama", "User")
```

**Download the system prompt:**
```bash
mkdir -p ~/.stocky
curl -o ~/.stocky/prompt.txt http://ai.local/stocky-prompt.txt
```

**Create the `stocky` alias:**
```bash
# Linux / macOS — add to ~/.bashrc or ~/.zshrc
alias stocky='ANTHROPIC_BASE_URL="http://ai.local:11434" ANTHROPIC_API_KEY="ollama" claude --model qwen3:32b --append-system-prompt "$(cat ~/.stocky/prompt.txt)"'
```
```powershell
# Windows PowerShell — add to $PROFILE
function stocky { $env:ANTHROPIC_BASE_URL="http://ai.local:11434"; $env:ANTHROPIC_API_KEY="ollama"; claude --model qwen3:32b --append-system-prompt (Get-Content ~/.stocky/prompt.txt -Raw) @args }
```

> **Note:** If you've previously logged into claude.ai on the same machine, you may see a warning about "Both a token and an API key are set." This is cosmetic — the local connection works correctly. To silence it, run `claude /logout` first.

#### What you can ask it to do

Once set up, clients can ask things like:

**Spreadsheets & Data:**
- "Read sales.xlsx and create a bar chart of revenue by quarter"
- "Create an Excel file with employee data — 50 rows, formatted with headers and totals"
- "Analyze this CSV and find outliers" (pipe data in)
- "Convert this JSON file to a formatted Excel spreadsheet"

**Documents:**
- "Create a Word document with our quarterly report — include charts and tables"
- "Build a 10-slide PowerPoint presentation on project status"
- "Generate a PDF invoice for client XYZ with line items and totals"

**Reports & Analysis:**
- "Read all .csv files in this folder and create a summary PDF report with charts"
- "Create an HTML dashboard from this data with interactive Plotly charts"
- "Merge these 5 PDFs into one and add page numbers"

**Web Research:**
- "Search the web for 'best CRM for small business 2026' and summarize the top 5"
- "Read this article URL and give me a summary with key points"
- "Check the latest news from this RSS feed and create a digest"
- "Download this PDF from the web and extract the key data into a spreadsheet"

**Web & Files:**
- "Scrape the table from this HTML file and save as CSV"
- "Generate a QR code for this URL"
- "Convert this SVG logo to PNG at 300 DPI"

### Using Anthropic's cloud instead

To use Anthropic's cloud models (paid, more capable), just run `claude` without the env vars. It authenticates via browser on first run.

```bash
# Cloud mode (default, requires Anthropic account)
claude

# Switch models
claude --model opus     # Most capable
claude --model sonnet   # Default for most plans
claude --model haiku    # Fastest / cheapest
```

### Context requirements

Claude Code needs **32K+ context** for reliable agentic work (tool calls, file edits). Keep the server in **1x32K mode** when using Claude Code:
```bash
# Check current mode
grep OLLAMA_NUM_PARALLEL /etc/systemd/system/ollama.service.d/override.conf

# If it shows 2 (parallel mode), switch to single:
bash scripts/toggle-parallel.sh
```

2x16K parallel mode will cause Claude Code to truncate context and miss tool calls.

### Common commands

```bash
# Interactive session
bash scripts/claude-local.sh

# One-shot (print mode) — runs and exits
bash scripts/claude-local.sh -p "summarize all .md files in docs/"

# Pipe input
cat data.csv | bash scripts/claude-local.sh -p "analyze this CSV and find outliers"

# Continue most recent conversation
bash scripts/claude-local.sh --continue

# Resume a specific session
bash scripts/claude-local.sh --resume <session-id>
```

### File generation examples

```bash
# Excel spreadsheet
bash scripts/claude-local.sh -p "create ~/report.xlsx with employee data: Name, Department, Salary, Start Date. Add 20 sample rows."

# Word document
bash scripts/claude-local.sh -p "create ~/memo.docx — a professional memo about Q1 results with a summary table"

# PDF report
bash scripts/claude-local.sh -p "read ~/data.csv and create ~/report.pdf with charts and a summary table"

# PowerPoint
bash scripts/claude-local.sh -p "create ~/presentation.pptx — 8 slides on project status with bullet points and a chart"

# CSV from existing data
cat raw-data.txt | bash scripts/claude-local.sh -p "parse this into a clean CSV at ~/output.csv"

# Analyze and chart
bash scripts/claude-local.sh -p "read ~/sales.xlsx, find the top 5 products, and save a bar chart as ~/top5.png"

# Merge PDFs
bash scripts/claude-local.sh -p "merge all PDFs in ~/invoices/ into ~/combined.pdf"

# Web research
bash scripts/claude-local.sh -p "search the web for 'RTX 5090 benchmarks' and summarize the top results"

# Read a URL
bash scripts/claude-local.sh -p "read https://example.com/article and create a one-page PDF summary"

# Extract text from a PDF
bash scripts/claude-local.sh -p "read ~/contract.pdf and list all dates and dollar amounts mentioned"
```

---

## Why Not the Others?

### OpenCode (not recommended for this server)

OpenCode (https://github.com/anomalyco/opencode, 118K stars) supports Ollama but has **known issues with tool calling on local models**. The maintainer stated: "local LLMs are not yet ready for this kind of workload." Qwen3 specifically was tested and required workarounds (`num_ctx` fix), with tool calls still failing silently in many cases.

If you want to try it anyway:
```bash
curl -fsSL https://opencode.ai/install | bash
```

Config at `~/.config/opencode/opencode.json`:
```json
{
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "options": { "baseURL": "http://localhost:11434/v1" },
      "models": { "qwen3:32b": { "name": "Qwen3 32B" } }
    }
  }
}
```

### CodeBuff (incompatible)

CodeBuff (https://github.com/CodebuffAI/codebuff) cannot connect to local Ollama. It routes all requests through its own cloud backend via OpenRouter. Not usable in our setup.

---

## Links

| Tool | Docs | GitHub |
|------|------|--------|
| Claude Code | https://code.claude.com/docs/en/ | https://github.com/anthropics/claude-code |
| OpenCode | https://opencode.ai/docs/ | https://github.com/anomalyco/opencode |
| CodeBuff | https://www.codebuff.com/docs | https://github.com/CodebuffAI/codebuff |
