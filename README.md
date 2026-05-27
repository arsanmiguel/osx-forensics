# macOS Performance Forensic Tools

<a id="overview"></a>
## Overview

A comprehensive Bash-based diagnostic tool for macOS that automatically detects performance bottlenecks and can create AWS Support cases with detailed forensic data. Originally created for AWS DMS migration troubleshooting; run on your SOURCE DATABASE SERVER. If you are still using this for that purpose, be absolutely certain you run it on your source database server (the host where the database under migration actually runs)—not on a jump box, bastion, or the DMS replication instance alone. Now useful for any macOS performance troubleshooting; run on the machine you want to diagnose and optionally open an AWS Support case with full details attached.

Key Features:

- Performance forensics: CPU, memory, disk, network, database (vm_stat, iostat, top, etc.)
- Storage profiling (partition schemes, boot config, APFS/CoreStorage, SSD/HDD/Fusion, SMART health)
- AWS DMS source database diagnostics (binary logging, replication lag, connection analysis)
- Automated bottleneck detection
- Graceful degradation when tools unavailable
- Database forensics: DBA-level query analysis and DMS readiness checks
- Automatic AWS Support case creation with diagnostic data
- Works on macOS 10.15 (Catalina) through macOS 15 (Sequoia)
- Automatic Homebrew installation if not present; automatic utility installation via Homebrew when needed
- Enhanced profiling tools: htop, btop, glances (auto-installed via Homebrew)

TL;DR - Run it now
```bash
git clone https://github.com/arsanmiguel/osx-forensics.git && cd osx-forensics
chmod +x invoke-macos-forensics.sh
sudo ./invoke-macos-forensics.sh
```
Then read on for AWS Support or troubleshooting.

Quick links: [Install](#installation) · [Usage](#available-tool) · [Troubleshooting](#troubleshooting)

Contents
- [Overview](#overview)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Examples](#examples)
- [Use Cases](#use-cases)
- [What Bottlenecks Can Be Found](#what-bottlenecks-can-be-found)
- [Troubleshooting](#troubleshooting)
- [Configuration (AWS Support)](#configuration)
- [Support](#support)
- [Important Notes & Performance](#important-notes-and-performance)
- [Profiling Tools](#profiling-tools)
- [Version History](#version-history)

---

<a id="quick-start"></a>
## Quick Start

### Prerequisites
- macOS 10.15 (Catalina) through macOS 15 (Sequoia)
- sudo privileges
- Homebrew (optional, will be installed automatically if needed)
- AWS CLI (optional, will be installed automatically for support case creation)

### Supported macOS Versions

Tested on:
- macOS 15 (Sequoia)
- macOS 14 (Sonoma)
- macOS 13 (Ventura)
- macOS 12 (Monterey)
- macOS 11 (Big Sur)
- macOS 10.15 (Catalina)

Note: The script automatically installs Homebrew if not present and uses it to install any missing utilities.

<a id="installation"></a>
### Installation

1. Clone the repository:
```bash
git clone https://github.com/arsanmiguel/osx-forensics.git
cd osx-forensics
```

2. Make executable:
```bash
chmod +x invoke-macos-forensics.sh
```

3. Run diagnostics:
```bash
sudo ./invoke-macos-forensics.sh
```

---

<a id="available-tool"></a>
The script runs system diagnostics and writes a report to a timestamped file; optional AWS Support case creation when issues are found. Usage: `sudo ./invoke-macos-forensics.sh [-m mode] [-s] [-v severity] [-o dir]`.

---

<a id="examples"></a>
## Examples

Run all script commands with sudo.

<details>
<summary><strong>Example 1: Quick Health Check</strong></summary>

```bash
sudo ./invoke-macos-forensics.sh -m quick
```
Output: Fast assessment of CPU, memory, and disk usage with automatic bottleneck detection

Use case: Daily health checks, quick troubleshooting

</details>

<details>
<summary><strong>Example 2: Production Issue with Auto-Ticket</strong></summary>

```bash
sudo ./invoke-macos-forensics.sh -m deep -s -v urgent
```
Output: Comprehensive diagnostics + AWS Support case with all data attached

Use case: Critical production issues requiring AWS Support assistance

</details>

<details>
<summary><strong>Example 3: CPU Performance Analysis</strong></summary>

```bash
sudo ./invoke-macos-forensics.sh -m cpu
```
Output: Detailed CPU analysis with load averages and top consumers

Use case: Investigating high CPU usage or slow application performance

</details>

<details>
<summary><strong>Example 4: Memory Investigation</strong></summary>

```bash
sudo ./invoke-macos-forensics.sh -m memory
```
Output: Memory pressure analysis, swap usage, and top memory consumers

Use case: Investigating memory leaks or out-of-memory issues

</details>

<details>
<summary><strong>Example 5: Database Performance</strong></summary>

```bash
sudo ./invoke-macos-forensics.sh -m standard
```
Output: Full system diagnostics including database query analysis

Use case: Diagnosing slow database queries or connection issues

</details>

### Use Cases

<a id="use-cases"></a>
<details>
<summary><strong>Use Cases</strong> (DMS, DB perf, EC2 Mac, development, right-sizing)</summary>

<details>
<summary><strong>AWS DMS Migrations</strong></summary>

This tool is designed to run on your SOURCE DATABASE SERVER, not on the DMS replication instance (which is AWS-managed).

If you are migrating with DMS, run these diagnostics on the **same macOS host where the source database process lives** (your SOURCE DATABASE SERVER). Running elsewhere yields misleading or empty results.

What it checks for DMS by database type:

<details>
<summary><strong>MySQL/MariaDB</strong></summary>

- Binary logging enabled (log_bin=ON, required for CDC)
- Binlog format set to ROW (required for DMS)
- Binary log retention configured (expire_logs_days >= 1)
- Replication lag (if source is a replica)

</details>

<details>
<summary><strong>PostgreSQL</strong></summary>

- WAL level set to 'logical' (required for CDC)
- Replication slots configured (max_replication_slots >= 1)
- Replication lag (if standby server)

</details>

<details>
<summary><strong>Oracle</strong></summary>

- ARCHIVELOG mode enabled (required for CDC)
- Supplemental logging enabled (required for DMS)
- Data Guard apply lag (if standby)

</details>

<details>
<summary><strong>SQL Server</strong></summary>

- SQL Server Agent running (required for CDC)
- Database recovery model set to FULL (required for CDC)
- AlwaysOn replica lag (if applicable)

</details>

<details>
<summary><strong>All Databases</strong></summary>

- CloudWatch Logs Agent running
- Database connection health
- Network connectivity to database ports
- Connection churn that could impact DMS
- Source database performance issues
- Long-running queries/sessions
- High connection counts

</details>

Run this when:
- Planning a DMS migration (pre-migration assessment)
- DMS replication is slow or stalling
- Source database performance issues
- High replication lag
- Connection errors in DMS logs
- CDC not capturing changes

Usage:
```bash
sudo ./invoke-macos-forensics.sh -m deep -s -v high
```

</details>

<details>
<summary><strong>Development Machine Performance</strong></summary>

Diagnose slow build times, IDE performance, or Docker container issues:
```bash
sudo ./invoke-macos-forensics.sh -m standard
```

What it detects:
- High CPU usage from build processes
- Memory pressure from multiple applications
- Disk I/O bottlenecks
- Database connection issues

</details>

<details>
<summary><strong>Database Server Issues</strong></summary>

Identify database and system bottlenecks on macOS database servers:
```bash
sudo ./invoke-macos-forensics.sh -m deep
```

What it detects:
- Long-running queries
- High connection counts
- Memory pressure affecting database performance
- Disk I/O issues

</details>

<details>
<summary><strong>AWS EC2 Mac Instances</strong></summary>

Diagnose performance issues on EC2 Mac instances:
```bash
sudo ./invoke-macos-forensics.sh -m standard -s -v high
```

What it detects:
- CPU steal time (hypervisor contention)
- Memory pressure
- Network issues
- Automatic AWS Support case creation

</details>

<details>
<summary><strong>Right-Sizing Exercises</strong></summary>

Gather baseline performance data for capacity planning:
```bash
sudo ./invoke-macos-forensics.sh -m quick
```

What it provides:
- Current resource utilization
- Load patterns
- Memory usage trends
- Database connection counts

</details>

</details>

### What Bottlenecks Can Be Found

<a id="what-bottlenecks-can-be-found"></a>
<details>
<summary><strong>What Bottlenecks Can Be Found?</strong> (What the script can detect)</summary>

The tool automatically detects:

<details>
<summary><strong>CPU Issues</strong></summary>

- High CPU utilization (>80%)
- High load per core (>2.0)
- Excessive process CPU consumption
- Context switch storms

Example Detection:
```
BOTTLENECK: CPU: High CPU utilization (85%)
BOTTLENECK: CPU: High load per core (2.5)
```

</details>

<details>
<summary><strong>Memory Issues</strong></summary>

- Low available memory (<10% free)
- High memory pressure
- Excessive swap usage (>1GB)
- Memory leaks (high virtual memory usage)

Example Detection:
```
BOTTLENECK: Memory: Low available memory (8% free)
BOTTLENECK: Memory: High swap usage (2.5GB)
```

</details>

<details>
<summary><strong>Disk Issues</strong></summary>

- High disk usage (>90%)
- Poor I/O performance
- Disk queue length issues

Example Detection:
```
BOTTLENECK: Disk: High disk usage on root volume (92%)
```

</details>

<details>
<summary><strong>Storage Issues</strong></summary>

- Misaligned partitions (4K alignment check - 30-50% perf loss on SSD/SAN)
- MBR partition scheme on >2TB disk (data loss risk - only 2TB accessible)
- SMART drive failures or warnings (failing/about to fail)
- High disk usage (>90% on root volume)
- High I/O wait - processes stuck in uninterruptible sleep (D state)
- AWS EBS optimization opportunities (on EC2 Mac instances)
- Time Machine snapshot accumulation

Example Detection:
```
BOTTLENECK: Storage: MBR partition scheme on >2TB disk disk2 (data loss risk)
BOTTLENECK: Storage: SMART failure detected on disk0
BOTTLENECK: Disk: High disk usage on root volume (92%)
BOTTLENECK: Disk: High I/O wait - 8 processes in uninterruptible sleep
```

</details>

<details>
<summary><strong>Database Issues</strong></summary>

- High connection counts:
  - MySQL/PostgreSQL/Oracle: >500 connections
  - MongoDB/Cassandra: >1000 connections
  - Redis: >10,000 connections
- Long-running queries/operations (>30 seconds)
- Connection rejections (Redis)
- Blocking sessions (SQL Server, Oracle)
- Slow query patterns

Supported Databases:
- MySQL / MariaDB
- PostgreSQL
- MongoDB
- Redis
- Cassandra
- Oracle Database
- Elasticsearch

Example Detection:
```
BOTTLENECK: Database: High MySQL connection count (650)
BOTTLENECK: Database: Long-running MySQL queries detected (>30s)
BOTTLENECK: Database: Redis connection rejections detected (15)
```

</details>

</details>

---

<a id="troubleshooting"></a>
<a id="troubleshooting"></a>
## Troubleshooting

<details>
<summary><strong>Permission Denied Errors</strong></summary>

Problem: Script fails with permission errors

Solution: Run with sudo:
```bash
sudo ./invoke-macos-forensics.sh -m standard
```

Why: Many system diagnostics require root privileges to access performance counters and system statistics.

</details>

<details>
<summary><strong>Homebrew Installation Fails</strong></summary>

Problem: Automatic Homebrew installation fails

Solution 1: Install Homebrew manually:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Solution 2: Check for existing Homebrew installation:
```bash
which brew
```

If Homebrew is installed but not in PATH, add it:
```bash
# For Apple Silicon Macs
eval "$(/opt/homebrew/bin/brew shellenv)"

# For Intel Macs
eval "$(/usr/local/bin/brew shellenv)"
```

</details>

<details>
<summary><strong>AWS Support Case Creation Fails</strong></summary>

Problem: Support case creation fails even with AWS CLI installed

Checks:

1. Verify AWS CLI installation:
```bash
aws --version
```

2. Check AWS credentials:
```bash
aws sts get-caller-identity
```

3. Verify Support plan:
   - Log into AWS Console
   - Navigate to Support Center
   - Confirm Business or Enterprise Support plan is active

4. Test Support API access:
```bash
aws support describe-services
```

Common Issues:
- No active Support plan (requires Business or Enterprise)
- Insufficient IAM permissions
- Expired AWS credentials
- Wrong AWS region configuration

</details>

<details>
<summary><strong>Database Queries Fail</strong></summary>

Problem: Database forensics shows "Unable to query" messages

Causes:
- Database requires authentication
- Database user lacks necessary permissions
- Database is not listening on default port

Solutions:

MySQL/MariaDB:
```bash
# Grant permissions to root user
mysql -u root -p
GRANT SELECT ON *.* TO 'root'@'localhost';
FLUSH PRIVILEGES;
```

PostgreSQL:
```bash
# Edit pg_hba.conf to allow local connections
sudo vi /usr/local/var/postgresql@14/pg_hba.conf
# Add: local all postgres trust
sudo brew services restart postgresql@14
```

MongoDB:
```bash
# Connect with authentication
mongosh --username admin --password
```

Note: The script will continue and report other metrics even if database queries fail.

</details>

<details>
<summary><strong>High Memory Pressure False Positives</strong></summary>

Problem: Script reports low memory but system feels responsive

Explanation: macOS aggressively uses available memory for caching. The `memory_pressure` command provides a more accurate assessment than raw free memory.

What to check:
- Look at swap usage (high swap = real problem)
- Check memory pressure output (green = OK, yellow = warning, red = critical)
- Review top memory consumers

</details>

<details>
<summary><strong>Storage Profiling Tools</strong></summary>

The script uses native macOS tools for storage analysis:

| Tool | Purpose | Source |
|------|---------|--------|
| diskutil | Disk/volume management, partition schemes | Native macOS |
| system_profiler | Hardware info (NVMe, T2 chip detection) | Native macOS |
| nvram | Secure Boot policy (T2 Macs) | Native macOS |
| bless | Boot volume information | Native macOS |
| fdesetup | FileVault status | Native macOS |
| df | Filesystem capacity | Native macOS |
| du | Directory sizes | Native macOS |
| tmutil | Time Machine snapshot analysis | Native macOS |
| mount | Mount point information | Native macOS |

Partition Scheme Detection:
- GPT (GUID Partition Table) - Modern, required for macOS 10.11+
- MBR (Master Boot Record) - Legacy, 2TB limit (warns if >2TB disk)
- APM (Apple Partition Map) - Legacy PowerPC format

Partition Alignment Analysis:
- Uses `diskutil info` to get partition offsets
- Uses `gpt show` for detailed GPT partition analysis (when available)
- Checks 4K (4096 byte) alignment - minimum for modern storage
- Checks 1MB (1048576 byte) alignment - optimal for SSD/SAN
- Detects storage type from diskutil (SSD, NVMe, USB, Thunderbolt, Fibre Channel)
- Severity based on storage type:
  - Internal SSD/NVMe: High severity (30-50% performance loss)
  - External SSD (USB/Thunderbolt): High severity (30-50% loss)
  - SAN (Fibre Channel): High severity (30-50% loss + I/O amplification)
  - HDD: Medium severity (10-20% loss from read-modify-write)
- Note: APFS containers manage alignment internally and are always optimal
- Alignment issues typically affect HFS+, FAT32, exFAT volumes

Filesystem Detection:
- APFS - Modern Apple filesystem with encryption, snapshots, space sharing
- HFS+ - Legacy Mac filesystem (migration to APFS recommended)
- exFAT/FAT32 - Cross-platform for external drives
- NTFS - Windows (read-only by default on macOS)

Boot Configuration Detection:
- Apple Silicon: Always Secure Boot via iBoot
- Intel T2 Macs: Full/Medium/No Security modes
- Intel non-T2: UEFI without Secure Boot

Optional (via Homebrew):

| Tool | Purpose | Install Command |
|------|---------|-----------------|
| smartctl | Detailed SMART data | `brew install smartmontools` |

Manual installation:
```bash
# Install smartmontools for detailed SMART analysis
brew install smartmontools
```

The script will function without smartmontools but will provide less detailed SMART information (using diskutil's basic SMART status instead).

</details>

---

<a id="configuration"></a>
## Configuration

### Homebrew Integration

The tool automatically manages Homebrew installation:

<details>
<summary><strong>Automatic Installation</strong></summary>

If Homebrew is not installed, the script will:
1. Detect the absence of Homebrew
2. Download the latest Homebrew installer from: `https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh`
3. Run the installer automatically
4. Configure the PATH for the current session
5. Proceed with diagnostics

Manual Installation (if automatic fails):
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

</details>

### AWS Support Integration

The tool can automatically create AWS Support cases when performance issues are detected.

<details>
<summary><strong>Setup Instructions</strong></summary>

Prerequisites:
- AWS account with Business or Enterprise Support plan
- IAM user with Support API permissions

Setup Steps:

1. Install AWS CLI (automatic):
   - The script will automatically install AWS CLI via Homebrew when you use the `-s` flag
   - Manual installation: `brew install awscli`

2. Configure AWS credentials:
```bash
aws configure
```

Enter your:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., us-east-1)
- Default output format (json)

3. Verify Support API access:
```bash
aws support describe-services
```

Required IAM Permissions:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "support:CreateCase",
        "support:AddAttachmentsToSet",
        "support:AddCommunicationToCase"
      ],
      "Resource": "*"
    }
  ]
}
```

Usage:
```bash
# Create support case if bottlenecks found
sudo ./invoke-macos-forensics.sh -m standard -s

# Specify severity level
sudo ./invoke-macos-forensics.sh -m deep -s -v urgent

# Available severity levels: low, normal, high, urgent, critical
```

</details>

---

<a id="profiling-tools"></a>
## Profiling Tools

<details>
<summary><strong>htop, btop, glances, iotop, smartmontools (Homebrew)</strong></summary>

The script automatically installs these enhanced profiling tools via Homebrew:

| Tool | Purpose | Homebrew Package |
|------|---------|------------------|
| htop | Interactive process viewer with CPU/memory bars | `htop` |
| btop | Modern resource monitor with graphs and history | `btop` |
| glances | Comprehensive system monitoring (CPU, mem, disk, network) | `glances` |
| iotop | I/O monitoring by process | `iotop` |
| smartmontools | Disk SMART health data | `smartmontools` |

Native macOS Tools Used:
- `top` - Process and CPU sampling
- `vm_stat` - Virtual memory statistics
- `iostat` - Disk I/O statistics
- `diskutil` - Disk and volume information
- `system_profiler` - Hardware and storage details
- `memory_pressure` - Memory pressure analysis

Manual Installation:
```bash
# Install all enhanced profiling tools
brew install htop btop glances iotop smartmontools

# Or install individually
brew install htop
brew install btop
brew install glances
```

</details>

---

<a id="support"></a>
## Support

### Contact
- Report bugs and feature requests: [adrianr.sanmiguel@gmail.com](mailto:adrianr.sanmiguel@gmail.com)
- GitHub Issues: Report issues on the GitHub repository

### AWS Support
For AWS-specific issues on EC2 Mac instances, the tool can automatically create support cases with diagnostic data attached.

---

<a id="important-notes-and-performance"></a>
## Important Notes & Performance

<details>
<summary><strong>Important Notes & Expected Performance Impact</strong></summary>

- This utility requires sudo privileges for full diagnostics
- Tested on macOS 10.15 (Catalina) through macOS 15 (Sequoia)
- Works on Mac hardware (Intel and Apple Silicon) and AWS EC2 Mac instances
- Database forensics requires database client tools (mysql, psql, mongo, redis-cli, etc.)
- Some database queries require authentication - the script will note when queries fail
- No warranty or official support provided - use at your own discretion
- Always test in non-production environments first

### Expected Performance Impact

Quick Mode (3 minutes):
- CPU: <5% overhead - mostly reading system stats
- Memory: <50MB - lightweight data collection
- Disk I/O: Minimal - no performance testing, only stat collection
- Network: None - passive monitoring only
- Safe for production - read-only operations

Standard Mode (5-10 minutes):
- CPU: 5-10% overhead - includes sampling and process analysis
- Memory: <100MB - additional process tree analysis
- Disk I/O: Minimal - no write testing, only extended stat collection
- Network: None - passive monitoring only
- Safe for production - read-only operations

Deep Mode (15-20 minutes):
- CPU: 10-20% overhead - includes extended sampling
- Memory: <150MB - comprehensive process and memory analysis
- Disk I/O: Minimal - macOS version does not perform write tests
- Network: None - passive monitoring only
- Safe for production - read-only operations

Database Query Analysis (all modes):
- CPU: <2% overhead per database - lightweight queries to system tables
- Memory: <20MB per database - result set caching
- Database Load: Minimal - uses performance schema/DMVs/system views
- Safe for production - read-only queries, no table locks

General Guidelines:
- The tool is read-only - no disk write tests on macOS
- No application restarts or configuration changes
- Monitoring tools run for brief intervals
- Database queries target system/performance tables only, not user data
- All operations are non-blocking and use minimal system resources

</details>

---

<a id="version-history"></a>
## Version History

<details>
<summary><strong>Version History</strong></summary>

- v1.3 (February 2026) - README overhaul
  - Structure and flow aligned with linux-forensics/unix-forensics: table of contents (Contents) with anchors, TL;DR, Quick links
  - Replaced long "Available Tool" section with a short blurb; Use Cases and What Bottlenecks are subsections of Examples
  - Section order: Troubleshooting before Configuration; Profiling Tools and Important Notes & Performance are collapsible
  - Removed emojis; slimmed Key Features; consistent section headers and styling; removed What's Included
- v1.2 (February 2026) - Partition scheme and boot configuration
  - Partition scheme analysis (GPT vs MBR vs APM with >2TB warnings)
  - Boot configuration (Apple Silicon iBoot, Intel UEFI, T2 Secure Boot status)
  - Filesystem type detection (APFS, HFS+, exFAT, FAT32, NTFS)
  - APFS feature detection (FileVault, snapshots, space sharing)
- v1.1 (February 2026) - Storage profiling
  - APFS container and CoreStorage analysis; SSD/HDD/Fusion Drive/NVMe detection
  - SMART health monitoring; capacity profiling; Time Machine snapshot analysis
  - Network storage detection (NFS, SMB, AFP); storage performance baseline testing
  - AWS EC2 Mac EBS optimization recommendations
- v1.0 (January 2026) - Initial release
  - Automatic Homebrew and AWS CLI installation; CPU, Memory, Disk, Network forensics
  - DBA-level database query analysis; AWS Support case integration; automatic bottleneck detection

</details>

---

Note: This tool is provided as-is for diagnostic purposes. Always test in non-production environments first.

