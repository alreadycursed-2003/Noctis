## What is Noctis?

**Noctis** is a modular, AI-powered shell-script framework designed to automate the core phases of a professional penetration test. [cite_start]From initial reconnaissance to generating a client-ready executive summary, Noctis handles the heavy lifting in a single command. 

It orchestrates industry-standard tools like `nmap`, `nuclei`, `nikto`, and `subfinder` into an intelligent pipeline. [cite_start]With optional LLM integration, it analyzes findings in real-time, triages vulnerabilities, and suggests actionable attack playbooks. 

```bash
./noctis.sh -t example.com -e "Client Corp Q1 2026" -s scope.txt
FeaturesModular Pipeline: Run the full assessment or pick individual modules (recon, portscan, etc.). 5-Phase Nmap Scanning: Ranges from fast discovery to deep service detection and NSE scripting. Auto-Adaptive Intelligence: Automatically detects services like HTTP, SMB, or SSH and triggers relevant follow-up scripts. AI-Powered Analysis: Connects to Ollama (local), OpenAI, or Claude to interpret raw scan data. Smart Triage: AI identifies potential false positives and writes executive summaries. Scope Enforcement: Validates all targets against an authorized scope.txt to prevent out-of-scope testing. Architecturenoctis/
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
Installation1. Clone the repositoryBashgit clone [https://github.com/yourusername/noctis.git](https://github.com/yourusername/noctis.git)
cd noctis
chmod +x noctis.sh setup-ai.sh
2. Install Required ToolsBash# Debian/Ubuntu
sudo apt update && sudo apt install nmap whois dnsutils curl openssl nikto jq

# macOS
brew install nmap whois bind curl openssl nikto jq
3. Install Optional Tools (Highly Recommended)Bash# subfinder + nuclei + gobuster (requires Go)
go install -v [github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest](https://github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest)
go install -v [github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest](https://github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest)
go install [github.com/OJ/gobuster/v3@latest](https://github.com/OJ/gobuster/v3@latest)
nuclei -update-templates

# theHarvester
pip3 install theHarvester
4. Configure AI (Optional)Bash./setup-ai.sh
UsageModeCommandFull Assessment./noctis.sh -t example.com -e "Engagement Name" -s scope.txtQuick Recon Only./noctis.sh -t 10.0.0.1 -m recon --scan-type quick -yVulnerability Only./noctis.sh -t 192.168.1.100 -m vulnscan -yNo AI Mode./noctis.sh -t example.com --no-aiAI IntegrationPhaseAI FunctionalityPost-ReconFlags interesting subdomains and infers the technology stack. Post-PortscanRisk-rates services and generates prioritized attack playbooks. Post-VulnscanFilters false positives and suggests Proof-of-Concept steps. Final ReportWrites a C-suite executive summary with a remediation timeline. Legal & EthicsAlways obtain explicit written authorization before testing any system. Validate targets using the -s scope.txt flag to ensure legal compliance. Handle all findings according to your client's data handling and privacy policies. LicenseMIT — see LICENSE Built for professional penetration testers. Use responsibly.