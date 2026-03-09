# Stocky AI

Your office AI assistant, running locally on a dedicated server. All processing stays on your network — nothing is sent to the cloud.

## Getting Started

Open your browser and go to:

**http://ai.local**

That's it. Type your question and Stocky will handle the rest.

## What Stocky Can Do

### Browser Chat (http://ai.local)

- **Write emails and content** — Professional emails, blog posts, social media, newsletters
- **Work with documents** — Summarize PDFs, review contracts, extract key points
- **Spreadsheet help** — Analyze data, suggest formulas, generate reports
- **Research** — Deep-dive into topics with structured output and pros/cons
- **Code and automation** — Generate scripts, debug code, automate repetitive tasks
- **Brainstorm** — Strategy sessions, business plans, marketing ideas
- **Translate** — Works across multiple languages
- **Upload files** — Drag and drop documents, spreadsheets, images into the chat
- **Web search** — Toggle "Search" to let Stocky search the internet via private SearXNG

### Terminal CLI (Claude Code + Stocky alias)

For power users who prefer the command line. The CLI can do everything the browser chat does, **plus**:

- **Create files directly** — Excel, Word, PowerPoint, PDF, CSV, images, charts
- **Read and analyze files** — Open any file on your computer, extract data, find patterns
- **Web research** — Search the web, read articles from URLs, parse RSS feeds, download files
- **Generate reports** — Combine data + charts + text into formatted PDF/HTML reports
- **Batch operations** — Process multiple files, merge PDFs, convert formats
- **Code execution** — Write and run Python scripts on the spot

| Task | Example command |
|------|----------------|
| Create an Excel file | `stocky -p "create ~/report.xlsx with sales data by quarter"` |
| Read and chart data | `stocky -p "read ~/data.csv, find top 10 products, save chart to ~/top10.png"` |
| Create a Word doc | `stocky -p "create ~/memo.docx — Q1 results with tables and summary"` |
| Generate a PDF | `stocky -p "create ~/invoice.pdf for client ABC, 3 line items"` |
| Web research | `stocky -p "search for 'best CRM 2026' and save a summary to ~/crm-research.md"` |
| Read a URL | `stocky -p "read https://example.com/article and give me key points"` |
| Create a presentation | `stocky -p "create ~/status.pptx — 8 slides on project progress"` |
| Merge PDFs | `stocky -p "merge all PDFs in ~/invoices/ into ~/combined.pdf"` |

**Setup:** Run the automated setup script for your platform — [Windows](scripts/client/setup-windows.ps1) or [Mac](scripts/client/setup-mac.sh). See [client README](scripts/client/README.md) for details, or [full CLI guide](docs/cli-tools.md) for manual setup.

## What Stocky Can't Do

- **Limited internet** — Stocky can search the web (browser: toggle "Search"; CLI: automatic via DuckDuckGo), but it doesn't browse freely. Its base knowledge comes from training data (up to early 2025)
- **No image generation** — It can analyze images you upload, but can't create new images (it can create charts and QR codes)
- **Not a database** — It can't query your company databases or CRM directly
- **May get facts wrong** — Like all AI, it can "hallucinate" — always verify important facts, numbers, and legal/financial advice
- **No memory between chats** — Each new chat starts fresh. Stocky doesn't remember previous conversations (unless you're continuing in the same chat thread)

## How Much Can It Handle?

| What | Limit | In Plain English |
|------|-------|-----------------|
| Input + output combined | ~32,000 tokens | About **50 pages** of text (~24,000 words) |
| Single file upload | 100 MB max | Most documents, spreadsheets, and PDFs are fine |
| Best sweet spot | Up to ~10 pages | Fastest and most accurate responses |
| Long documents | 10-40 pages | Works, but may miss details toward the edges |
| Beyond 50 pages | Split it up | Break into sections and ask about each part separately |

**Rule of thumb:** 1 page of text ~ 500 words ~ 650 tokens. A typical email is ~200 tokens. A 10-page bank statement or contract is ~6,500 tokens — fits easily.

## Response Speed

Stocky runs on a dedicated GPU and responds at about **60 tokens per second** — roughly the speed of fast human reading. Short answers (emails, summaries) come back in 1-3 seconds. Longer outputs (full reports, detailed analysis) may take 10-30 seconds.

One request is processed at a time. If someone else is using Stocky, yours queues and starts when theirs finishes — usually just a few seconds. (Admin can switch to 2-parallel mode for busy times with `bash scripts/toggle-parallel.sh`)

## Privacy

- Everything runs on a server in your office — no data leaves the building
- No conversation data is sent to any cloud service
- Your chats are stored locally and only visible to you (admins can access if needed)

## Access From Any Device

| What | How | Setup needed? |
|------|-----|---------------|
| **Browser chat** | http://ai.local | No — just open the URL |
| **Terminal CLI** | Run `stocky` in your terminal | Yes — run [setup script](scripts/client/README.md) |
| From Windows/Mac/Linux | Both methods work on all platforms | |
| From phone/tablet | Browser chat — works on mobile browsers | |

If `ai.local` doesn't load, use `http://192.168.29.100` instead.

## Tips for Best Results

- **Be specific** — "Write a formal email to the client about the Q1 budget delay, professional but apologetic tone" works much better than "write an email"
- **Give context** — Paste in the document or data you want analyzed. More context = better answers
- **Iterate** — Ask follow-up questions to refine the output. "Make it shorter" or "more formal tone" works great
- **Break up large tasks** — Instead of "analyze this 40-page report", try "summarize pages 1-10" then "summarize pages 11-20"
- **Ask for structure** — "Give me bullet points" or "format as a table" helps get organized output

## First Time Setup

1. Open http://ai.local
2. Ask your admin to create your account
3. Log in and start chatting with Stocky

## Need Help?

- Server not responding? Contact your IT admin
- For admin documentation, see [docs/](docs/index.md)
