# 🔐 Noctis

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Shell](https://img.shields.io/badge/shell-bash-green)
![License](https://img.shields.io/badge/license-MIT-orange)
![Status](https://img.shields.io/badge/status-active-brightgreen)

> **⚠️ FOR AUTHORIZED ENGAGEMENTS ONLY.**
> Unauthorized use against systems you don't have explicit written permission to test is illegal under the CFAA and equivalent international laws. Authors accept no liability for misuse.

---

## What is Noctis?

**Noctis** is a modular, AI-powered shell-script framework designed to automate the core phases of a professional penetration test. From initial reconnaissance to generating a client-ready executive summary, Noctis handles the heavy lifting in a single command.

It orchestrates industry-standard tools like `nmap`, `nuclei`, `nikto`, and `subfinder` into an intelligent pipeline. With optional LLM integration, it analyzes findings in real-time, triages vulnerabilities, and suggests actionable attack playbooks.

```bash
./noctis.sh -t example.com -e "Client Corp Q1 2026" -s scope.txt

```

---

## Features

* **Modular Pipeline**: Run the full assessment or pick individual modules (recon, portscan, etc.).
* **5-Phase Nmap Scanning**: Ranges from fast discovery to deep service detection and NSE scripting.
* **Auto-Adaptive Intelligence**: Automatically detects services like HTTP, SMB, or SSH and triggers relevant follow-up scripts.
* **AI-Powered Analysis**: Connects to Ollama (local), OpenAI, or Claude to interpret raw scan data.
* **Smart Triage**: AI identifies potential false positives and writes executive summaries.
* **Scope Enforcement**: Validates all targets against an authorized `scope.txt` to prevent out-of-scope testing.

---

## Architecture

```
noctis/
├── noctis.sh               # Main orchestrator
├── setup-ai.sh             # AI provider configuration wizard
├── lib/
│   ├── common.sh           # Shared utilities, logging, and spinners
│   └── ai.sh               # AI brain — provider backends + analysis functions
├── modules/
│   ├── recon.sh            # Recon & OSINT
│   ├── portscan.sh         # Port scanning (multi-phase nmap)
│   ├── vulnscan.sh         # Vulnerability scanning (nuclei/nikto)
│   └── report.sh           # Report generation (Markdown + HTML)
├── wordlists/              # Custom wordlists
├── reports/                # Output directory (auto-created per run)
└── scope.txt.example       # Example scope file

```

---

## Installation

### 1. Clone the repository

```bash
git clone [https://github.com/yourusername/noctis.git](https://github.com/yourusername/noctis.git)
cd noctis
chmod +x noctis.sh setup-ai.sh

```

### 2. Install Required Tools

```bash
# Debian/Ubuntu
sudo apt update && sudo apt install nmap whois dnsutils curl openssl nikto jq

# macOS
brew install nmap whois bind curl openssl nikto jq

```

### 3. Install Optional Tools (Highly Recommended)

```bash
# subfinder + nuclei + gobuster (requires Go)
go install -v [github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest](https://github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest)
go install -v [github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest](https://github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest)
go install [github.com/OJ/gobuster/v3@latest](https://github.com/OJ/gobuster/v3@latest)
nuclei -update-templates

# theHarvester
pip3 install theHarvester

```

### 4. Configure AI (Optional)

```bash
./setup-ai.sh

```

---

## Usage

| Mode | Command |
| --- | --- |
| **Full Assessment** | `./noctis.sh -t example.com -e "Engagement Name" -s scope.txt` |
| **Quick Recon Only** | `./noctis.sh -t 10.0.0.1 -m recon --scan-type quick -y` |
| **Vulnerability Only** | `./noctis.sh -t 192.168.1.100 -m vulnscan -y` |
| **No AI Mode** | `./noctis.sh -t example.com --no-ai` |

---
