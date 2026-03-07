# Stocky AI

Your office AI assistant, running locally on a dedicated server. All processing stays on your network — nothing is sent to the cloud.

## Getting Started

Open your browser and go to:

**http://ai.local**

That's it. Type your question and Stocky will handle the rest.

## What Stocky Can Do

- **Write emails and content** — Professional emails, blog posts, social media, newsletters
- **Work with documents** — Summarize PDFs, review contracts, extract key points
- **Spreadsheet help** — Analyze data, suggest formulas, generate reports
- **Research** — Deep-dive into topics with structured output and pros/cons
- **Code and automation** — Generate scripts, debug code, automate repetitive tasks
- **Brainstorm** — Strategy sessions, business plans, marketing ideas
- **Translate** — Works across multiple languages
- **Upload files** — Drag and drop documents, spreadsheets, images into the chat

## What Stocky Can't Do

- **No internet access** — Stocky doesn't browse the web or pull live data. Its knowledge comes from training data (up to early 2025)
- **No image generation** — It can analyze images you upload, but can't create new images
- **Not a database** — It can't query your company databases or CRM directly
- **May get facts wrong** — Like all AI, it can "hallucinate" — always verify important facts, numbers, and legal/financial advice
- **No memory between chats** — Each new chat starts fresh. Stocky doesn't remember previous conversations (unless you're continuing in the same chat thread)

## How Much Can It Handle?

| What | Limit | In Plain English |
|------|-------|-----------------|
| Input + output combined | ~16,000 tokens | About **25 pages** of text (~12,000 words) |
| Single file upload | 100 MB max | Most documents, spreadsheets, and PDFs are fine |
| Best sweet spot | Up to ~10 pages | Fastest and most accurate responses |
| Long documents | 10-25 pages | Works, but may miss details toward the end |
| Beyond 25 pages | Split it up | Break into sections and ask about each part separately |

**Rule of thumb:** 1 page of text ~ 500 words ~ 650 tokens. A typical email is ~200 tokens. A 10-page bank statement or contract is ~6,500 tokens — fits easily.

## Response Speed

Stocky runs on a dedicated GPU and responds at about **60 tokens per second** — roughly the speed of fast human reading. Short answers (emails, summaries) come back in 1-3 seconds. Longer outputs (full reports, detailed analysis) may take 10-30 seconds.

Two people can use Stocky at the same time. If a third person sends a request, it queues and starts when one of the first two finishes — usually just a few seconds.

## Privacy

- Everything runs on a server in your office — no data leaves the building
- No conversation data is sent to any cloud service
- Your chats are stored locally and only visible to you (admins can access if needed)

## Access From Any Device

| What | How |
|------|-----|
| Chat interface | http://ai.local |
| From Windows/Mac/Linux | Just open the URL in any browser |
| From phone/tablet | Same URL — works on mobile browsers too |

No installation needed on your computer. If `ai.local` doesn't load, use `http://192.168.29.100` instead.

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
