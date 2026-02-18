# 🔐 PentestAutomator

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Shell](https://img.shields.io/badge/shell-bash-green)
![License](https://img.shields.io/badge/license-MIT-orange)
![Status](https://img.shields.io/badge/status-active-brightgreen)

> **⚠️ FOR AUTHORIZED ENGAGEMENTS ONLY.**
> Unauthorized use against systems you don't have explicit written permission to test is illegal under the CFAA and equivalent international laws. Authors accept no liability for misuse.

---

## What is PentestAutomator?

A modular, AI-powered shell-script framework that automates the core phases of a professional penetration test — from initial recon through to a client-ready report — in a single command.

It wraps industry-standard tools (nmap, nuclei, nikto, subfinder, gobuster, theHarvester) into an intelligent pipeline, with optional LLM integration that analyzes findings in real time, generates adaptive attack playbooks, triages vulnerabilities, and writes an executive summary.

```bash
./pentest.sh -t example.com -e "Client Corp Q1 2025" -s scope.txt
```

---

## Features

- **Modular pipeline** — run all phases or pick individual modules
- **5-phase nmap scanning** — fast discovery → full port scan → service detection → UDP → NSE scripts
- **Auto-adaptive** — detects HTTP/SMB/SSH and runs the right follow-up scripts automatically
- **AI-powered analysis** — connects to Ollama, OpenAI, Claude, or any OpenAI-compatible API
- **Smart triage** — AI flags false positives, suggests PoC steps, writes attack playbooks
- **Dual reports** — Markdown + styled HTML report generated automatically
- **Scope enforcement** — validates targets against an authorized scope file before scanning
- **Authorization gate** — requires explicit confirmation before any scan runs

---

## Architecture

```
pentest-automator/
├── pentest.sh              # Main orchestrator
├── setup-ai.sh             # AI provider configuration wizard
├── lib/
│   ├── common.sh           # Shared utilities, logging, colors, spinners
│   └── ai.sh               # AI brain — all provider backends + analysis functions
├── modules/
│   ├── recon.sh            # Recon & OSINT
│   ├── portscan.sh         # Port scanning (nmap multi-phase)
│   ├── vulnscan.sh         # Vulnerability scanning
│   └── report.sh           # Report generation (Markdown + HTML)
├── wordlists/              # Custom wordlists (add your own)
├── reports/                # Output directory (auto-created per engagement)
└── scope.txt.example       # Example scope file
```

---

## Installation

### 1. Clone the repo

```bash
git clone https://github.com/yourusername/pentest-automator.git
cd pentest-automator
chmod +x pentest.sh setup-ai.sh
```

### 2. Install required tools

```bash
# Debian/Ubuntu
sudo apt update && sudo apt install nmap whois dnsutils curl openssl nikto jq

# macOS
brew install nmap whois bind curl openssl nikto jq
```

### 3. Install optional tools (recommended)

```bash
# subfinder + nuclei + gobuster (requires Go)
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install github.com/OJ/gobuster/v3@latest
nuclei -update-templates

# theHarvester
pip3 install theHarvester
```

### 4. Configure AI (optional but recommended)

```bash
./setup-ai.sh
```

| Provider | Notes |
|---|---|
| **Ollama** | Free, local, fully private — recommended |
| **OpenAI** | GPT-4o, GPT-4-turbo |
| **Anthropic** | Claude Opus, Sonnet |
| **OpenAI-compatible** | LM Studio, Groq, Mistral, Together AI |

---

## Usage

```bash
# Full assessment
./pentest.sh -t example.com -e "Client Corp Q1 2025" -s scope.txt --tester "Jane Smith"

# Quick recon only
./pentest.sh -t 10.0.0.1 -m recon --scan-type quick -y

# Port scan + vuln scan only
./pentest.sh -t 192.168.1.100 -m portscan,vulnscan -y

# Disable AI for this run
./pentest.sh -t example.com --no-ai
```

### All options

```
  -t, --target <host/IP>      Target hostname or IP (required)
  -e, --engagement <name>     Engagement name
  -s, --scope-file <file>     Authorized scope file
  -m, --modules <list>        all | recon | portscan | vulnscan | report
  --scan-type <type>          quick | full (default: full)
  -o, --output <dir>          Output directory (default: ./reports/)
  --tester <name>             Tester name for report
  --ai-config <file>          AI config file path (default: .ai_config)
  --no-ai                     Disable AI for this run
  -y, --yes                   Skip confirmation prompt
```

---

## Output

```
reports/20250219_143200_example_com/
├── pentest.log
├── report.md
├── report.html
├── ai_executive_summary.md
├── ai_vuln_triage.md
├── ai_port_analysis.md
├── ai_recon_analysis.md
├── recon/
├── portscan/
└── vulnscan/
```

---

## AI Integration

| Phase | What AI does |
|-------|-------------|
| After recon | Flags interesting subdomains, infers tech stack, suggests next steps |
| After port scan | Risk-rates services, generates prioritized attack playbook |
| After vuln scan | Triages findings, filters false positives, suggests PoC steps |
| End of run | Writes C-suite executive summary with remediation timeline |

---

## Legal & Ethics

- Always obtain **explicit written authorization** before testing
- Validate targets using `-s scope.txt`
- Handle findings per your client's data handling policy
- The authorization gate is a reminder, not a substitute for proper engagement agreements

---

## Roadmap

- [ ] PDF report generation
- [ ] Slack/webhook notifications on critical findings
- [ ] Delta diffing between runs
- [ ] Metasploit integration hooks
- [ ] AI-driven adaptive branching

---

## License

MIT — see [LICENSE](LICENSE)

*Built for professional penetration testers. Use responsibly.*
