# macOS Performance Forensic Tools

## Overview

A comprehensive Bash-based diagnostic tool for macOS that automatically detects performance bottlenecks and can create AWS Support cases with detailed forensic data. It is recommended that you run this on the server that is suspected of performance issues. In it's original version, this was created for AWS DMS migration troubleshooting, where you would run this on your SOURCE DATABASE SERVER. This has been made more flexible to allow for helping diagnose any Windows performance troubleshooting scenario -- and help you open an AWS Support case with the full details included in it.


**Key Features:**
- ✅ Comprehensive performance forensics (CPU, Memory, Disk, Network, Database)
- ✅ **Storage profiling** (partition schemes, boot config, APFS/CoreStorage, SSD/HDD/Fusion, SMART health)
- ✅ Automated bottleneck detection
- ✅ **Automatic Homebrew installation** if not present
- ✅ **Automatic AWS CLI installation** via Homebrew when needed
- ✅ CPU forensics (load average analysis, top consumers, process tracking)
- ✅ Memory forensics (pressure detection, swap analysis, top consumers)
- ✅ Disk I/O analysis (usage, performance metrics)
- ✅ **Database forensics** - DBA-level query analysis + DMS readiness checks
- ✅ Network analysis (connection states, interface statistics)
- ✅ **Automatic AWS Support case creation** with diagnostic data
- ✅ Works on macOS 10.15 (Catalina) through macOS 15 (Sequoia)

---

## 🚀 **Quick Start**

### **Prerequisites**
- macOS 10.15 (Catalina) through macOS 15 (Sequoia)
- sudo privileges
- Homebrew (optional, will be installed automatically if needed)
- AWS CLI (optional, will be installed automatically for support case creation)

### **Supported macOS Versions**

**Tested on:**
- macOS 15 (Sequoia)
- macOS 14 (Sonoma)
- macOS 13 (Ventura)
- macOS 12 (Monterey)
- macOS 11 (Big Sur)
- macOS 10.15 (Catalina)

**Note:** The script automatically installs Homebrew if not present and uses it to install any missing utilities.

### **Installation**

1. **Clone the repository:**
```bash
git clone https://github.com/arsanmiguel/osx-forensics.git
cd osx-forensics
```

2. **Make executable:**
```bash
chmod +x invoke-macos-forensics.sh
```

3. **Run diagnostics:**
```bash
sudo ./invoke-macos-forensics.sh
```

---

## 📊 **Available Tool**

### **invoke-macos-forensics.sh**
**A complete macOS performance diagnostic tool** - comprehensive forensics with automatic issue detection.

<details>
<summary><strong>What it does</strong></summary>

**System Detection & Setup:**
- Automatically detects macOS version
- Checks for Homebrew installation
- **Automatically installs Homebrew** if not present
- Checks for required utilities (native macOS tools)
- **Automatically installs AWS CLI** when support case creation is requested
- Continues with graceful degradation if tools unavailable

**CPU Forensics:**
- Load average analysis (1m, 5m, 15m)
- Load per core calculation
- CPU utilization sampling
- Top 10 CPU-consuming processes
- Automatic detection of high CPU usage (>80%)
- Automatic detection of high load per core (>2.0)
- **SAR CPU analysis:** Real-time sampling (sar -u)

**Memory Forensics:**
- Memory statistics via vm_stat
- Memory pressure analysis
- Swap usage monitoring
- Top 10 memory-consuming processes
- Automatic detection of low memory (<10% free)
- Automatic detection of high swap usage (>1GB)
- **SAR paging analysis:** Real-time sampling (sar -g, sar -p)

**Disk Forensics:**
- Disk usage analysis
- Disk I/O statistics via iostat
- Automatic detection of high disk usage (>90%)
- **SAR disk analysis:** Real-time sampling (sar -d)

**Storage Profiling:**
- **Partition scheme analysis** (GPT vs MBR with >2TB warnings, APM detection)
- **Partition alignment analysis** (4K/1MB alignment check for SSD/SAN performance)
- **Boot configuration detection:**
  - Apple Silicon: Apple Boot ROM (iBoot), always Secure Boot
  - Intel: UEFI, T2 Secure Boot status (Full/Medium/No Security)
  - Boot volume and startup disk identification
- **Filesystem type detection:**
  - APFS (modern, encryption, snapshots, space sharing)
  - HFS+ (legacy - recommends migration to APFS)
  - exFAT, FAT32, NTFS (external/cross-platform)
- **APFS feature detection:** FileVault status, local snapshots, space sharing
- Storage topology detection (APFS containers, CoreStorage, Apple RAID sets)
- Storage tiering analysis (SSD vs HDD vs Fusion Drive vs NVMe)
- AWS EC2 Mac EBS volume detection and optimization recommendations
- SMART health status monitoring (drive health, wear indicators)
- Capacity profiling (top directories by size, large file detection, application sizes)
- Cache and temporary storage analysis (system caches, Xcode DerivedData)
- Time Machine local snapshot analysis
- Network storage detection (NFS, SMB/CIFS, AFP mounts)
- Filesystem health verification (volume verification status)
- Storage performance baseline testing (sequential read/write in deep mode)

**Network Forensics:**
- Network interface configuration
- Network statistics
- Active connection monitoring
- **SAR network analysis:** Real-time sampling (sar -n DEV)

**Note on macOS SAR:** Unlike Linux sysstat, macOS does not automatically collect historical SAR data. The built-in sar command provides real-time sampling only with limited options compared to Linux. For continuous data collection, use: `sar -o /tmp/sardata.bin -u 60 &`

**Database Forensics:**
- Automatic detection of running databases
- **MySQL/MariaDB**: Connection count, long-running queries (>30s), top 5 queries by execution time, performance schema analysis
  <details>
  <summary><strong>DMS Readiness</strong></summary>
  
  - Binary logging (log_bin=ON)
  - Binlog format (ROW)
  - Retention (expire_logs_days >= 1)
  - Replication lag
  
  </details>
- **PostgreSQL**: Connection count, long-running queries (>30s), top 5 queries from pg_stat_statements, active session analysis
  <details>
  <summary><strong>DMS Readiness</strong></summary>
  
  - WAL level (logical)
  - Replication slots (max_replication_slots >= 1)
  - Replication lag
  
  </details>
- **Oracle**: Connection count, active sessions, top queries by elapsed time
  <details>
  <summary><strong>DMS Readiness</strong></summary>
  
  - ARCHIVELOG mode
  - Supplemental logging
  - Data Guard lag
  
  </details>
- **SQL Server**: Connection count, active sessions, top queries, blocking detection
  <details>
  <summary><strong>DMS Readiness</strong></summary>
  
  - SQL Agent status
  - Recovery model (FULL)
  - AlwaysOn replica lag
  
  </details>
- **MongoDB**: Connection count, long-running operations (>30s), current operations analysis
- **Redis**: Connection count, ops/sec metrics, connection rejections, slowlog analysis
- **Cassandra**: Connection count, process resource usage
- **Elasticsearch**: Connection count, long-running search tasks
- Automatic bottleneck detection for high connection counts
- Automatic detection of long-running queries/operations

**AWS Support Integration:**
- Automatic case creation when bottlenecks detected
- Diagnostic data attachment
- Configurable severity levels

</details>

<details>
<summary><strong>Usage</strong></summary>

```bash
# Quick diagnostics (fast assessment)
sudo ./invoke-macos-forensics.sh -m quick

# Standard diagnostics (recommended)
sudo ./invoke-macos-forensics.sh -m standard

# Deep diagnostics (extended analysis)
sudo ./invoke-macos-forensics.sh -m deep

# Auto-create support case if issues found
sudo ./invoke-macos-forensics.sh -m standard -s -v high

# Disk-only diagnostics
sudo ./invoke-macos-forensics.sh -m disk

# CPU-only diagnostics
sudo ./invoke-macos-forensics.sh -m cpu

# Memory-only diagnostics
sudo ./invoke-macos-forensics.sh -m memory

# Custom output directory
sudo ./invoke-macos-forensics.sh -m standard -o /var/log
```

**Options:**
- `-m, --mode` - Diagnostic mode: quick, standard, deep, disk, cpu, memory
- `-s, --support` - Create AWS Support case if issues found
- `-v, --severity` - Support case severity: low, normal, high, urgent, critical
- `-o, --output` - Output directory (default: current directory)
- `-h, --help` - Show help message

</details>

<details>
<summary><strong>Output Example</strong></summary>

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                macOS PERFORMANCE FORENSICS TOOL v1.0                          ║
║                                                                               ║
║                    Comprehensive System Diagnostics                           ║
║                    with AWS Support Integration                               ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝

[14:03:25] macOS Version: 14.2.1
[14:03:25] Starting forensics analysis in standard mode...
[14:03:25] Output file: macos-forensics-20260114-140325.txt

[14:03:25] Checking required utilities...
[14:03:25] Homebrew is installed
[14:03:25] AWS CLI is installed
[14:03:25] Utility check completed

[14:03:25] Gathering system information...
[14:03:27] System information collected

[14:03:27] Analyzing CPU performance...
[14:03:28] CPU forensics completed

[14:03:28] Analyzing memory usage...
[14:03:28] Memory forensics completed

[14:03:28] Analyzing disk performance...
[14:03:28] Disk forensics completed

[14:03:28] Analyzing network performance...
[14:03:28] Network forensics completed

[14:03:28] Checking for running databases...
[14:03:28] Database forensics completed

================================================================================
  FORENSICS SUMMARY
================================================================================

[14:03:28] Analysis completed in 3 seconds

BOTTLENECKS DETECTED: 2 performance issue(s) found

  • CPU: High CPU utilization (85%)
  • Memory: Low available memory (8% free)

[14:03:28] Detailed report saved to: macos-forensics-20260114-140325.txt
[14:03:28] Creating AWS Support case...
[14:03:30] AWS Support case created: case-123456789

═══════════════════════════════════════════════════════════════════════════════
                         Forensics Analysis Complete                            
═══════════════════════════════════════════════════════════════════════════════
```

</details>

---

## 📖 **Examples**

<details>
<summary><strong>Example 1: Quick Health Check</strong></summary>

```bash
sudo ./invoke-macos-forensics.sh -m quick
```
**Output:** Fast assessment of CPU, memory, and disk usage with automatic bottleneck detection

**Use Case:** Daily health checks, quick troubleshooting

</details>

<details>
<summary><strong>Example 2: Production Issue with Auto-Ticket</strong></summary>

```bash
sudo ./invoke-macos-forensics.sh -m deep -s -v urgent
```
**Output:** Comprehensive diagnostics + AWS Support case with all data attached

**Use Case:** Critical production issues requiring AWS Support assistance

</details>

<details>
<summary><strong>Example 3: CPU Performance Analysis</strong></summary>

```bash
sudo ./invoke-macos-forensics.sh -m cpu
```
**Output:** Detailed CPU analysis with load averages and top consumers

**Use Case:** Investigating high CPU usage or slow application performance

</details>

<details>
<summary><strong>Example 4: Memory Investigation</strong></summary>

```bash
sudo ./invoke-macos-forensics.sh -m memory
```
**Output:** Memory pressure analysis, swap usage, and top memory consumers

**Use Case:** Investigating memory leaks or out-of-memory issues

</details>

<details>
<summary><strong>Example 5: Database Performance</strong></summary>

```bash
sudo ./invoke-macos-forensics.sh -m standard
```
**Output:** Full system diagnostics including database query analysis

**Use Case:** Diagnosing slow database queries or connection issues

</details>

---

## 🎯 **Use Cases**

<details>
<summary><strong>AWS DMS Migrations</strong></summary>

**This tool is designed to run on your SOURCE DATABASE SERVER**, not on the DMS replication instance (which is AWS-managed).

**What it checks for DMS by database type:**

<details>
<summary><strong>MySQL/MariaDB</strong></summary>

- ✅ Binary logging enabled (log_bin=ON, required for CDC)
- ✅ Binlog format set to ROW (required for DMS)
- ✅ Binary log retention configured (expire_logs_days >= 1)
- ✅ Replication lag (if source is a replica)

</details>

<details>
<summary><strong>PostgreSQL</strong></summary>

- ✅ WAL level set to 'logical' (required for CDC)
- ✅ Replication slots configured (max_replication_slots >= 1)
- ✅ Replication lag (if standby server)

</details>

<details>
<summary><strong>Oracle</strong></summary>

- ✅ ARCHIVELOG mode enabled (required for CDC)
- ✅ Supplemental logging enabled (required for DMS)
- ✅ Data Guard apply lag (if standby)

</details>

<details>
<summary><strong>SQL Server</strong></summary>

- ✅ SQL Server Agent running (required for CDC)
- ✅ Database recovery model set to FULL (required for CDC)
- ✅ AlwaysOn replica lag (if applicable)

</details>

<details>
<summary><strong>All Databases</strong></summary>

- ✅ CloudWatch Logs Agent running
- ✅ Database connection health
- ✅ Network connectivity to database ports
- ✅ Connection churn that could impact DMS
- ✅ Source database performance issues
- ✅ Long-running queries/sessions
- ✅ High connection counts

</details>

**Run this when:**
- Planning a DMS migration (pre-migration assessment)
- DMS replication is slow or stalling
- Source database performance issues
- High replication lag
- Connection errors in DMS logs
- CDC not capturing changes

**Usage:**
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

**What it detects:**
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

**What it detects:**
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

**What it detects:**
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

**What it provides:**
- Current resource utilization
- Load patterns
- Memory usage trends
- Database connection counts

</details>

---

## **What Bottlenecks Can Be Found?**

The tool automatically detects:

<details>
<summary><strong>CPU Issues</strong></summary>

- **High CPU utilization** (>80%)
- **High load per core** (>2.0)
- Excessive process CPU consumption
- Context switch storms

**Example Detection:**
```
BOTTLENECK: CPU: High CPU utilization (85%)
BOTTLENECK: CPU: High load per core (2.5)
```

</details>

<details>
<summary><strong>Memory Issues</strong></summary>

- **Low available memory** (<10% free)
- **High memory pressure**
- **Excessive swap usage** (>1GB)
- Memory leaks (high virtual memory usage)

**Example Detection:**
```
BOTTLENECK: Memory: Low available memory (8% free)
BOTTLENECK: Memory: High swap usage (2.5GB)
```

</details>

<details>
<summary><strong>Disk Issues</strong></summary>

- **High disk usage** (>90%)
- Poor I/O performance
- Disk queue length issues

**Example Detection:**
```
BOTTLENECK: Disk: High disk usage on root volume (92%)
```

</details>

<details>
<summary><strong>Storage Issues</strong></summary>

- **Misaligned partitions** (4K alignment check - 30-50% perf loss on SSD/SAN)
- **MBR partition scheme on >2TB disk** (data loss risk - only 2TB accessible)
- **SMART drive failures** or warnings (failing/about to fail)
- **High disk usage** (>90% on root volume)
- **High I/O wait** - processes stuck in uninterruptible sleep (D state)
- AWS EBS optimization opportunities (on EC2 Mac instances)
- Time Machine snapshot accumulation

**Example Detection:**
```
BOTTLENECK: Storage: MBR partition scheme on >2TB disk disk2 (data loss risk)
BOTTLENECK: Storage: SMART failure detected on disk0
BOTTLENECK: Disk: High disk usage on root volume (92%)
BOTTLENECK: Disk: High I/O wait - 8 processes in uninterruptible sleep
```

</details>

<details>
<summary><strong>Database Issues</strong></summary>

- **High connection counts:**
  - MySQL/PostgreSQL/Oracle: >500 connections
  - MongoDB/Cassandra: >1000 connections
  - Redis: >10,000 connections
- **Long-running queries/operations** (>30 seconds)
- **Connection rejections** (Redis)
- Blocking sessions (SQL Server, Oracle)
- Slow query patterns

**Supported Databases:**
- MySQL / MariaDB
- PostgreSQL
- MongoDB
- Redis
- Cassandra
- Oracle Database
- Elasticsearch

**Example Detection:**
```
BOTTLENECK: Database: High MySQL connection count (650)
BOTTLENECK: Database: Long-running MySQL queries detected (>30s)
BOTTLENECK: Database: Redis connection rejections detected (15)
```

</details>

---

## 🔧 **Configuration**

### **Homebrew Integration**

The tool automatically manages Homebrew installation:

<details>
<summary><strong>Automatic Installation</strong></summary>

If Homebrew is not installed, the script will:
1. Detect the absence of Homebrew
2. Download the latest Homebrew installer from: `https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh`
3. Run the installer automatically
4. Configure the PATH for the current session
5. Proceed with diagnostics

**Manual Installation (if automatic fails):**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

</details>

### **AWS Support Integration**

The tool can automatically create AWS Support cases when performance issues are detected.

<details>
<summary><strong>Setup Instructions</strong></summary>

**Prerequisites:**
- AWS account with Business or Enterprise Support plan
- IAM user with Support API permissions

**Setup Steps:**

1. **Install AWS CLI (automatic):**
   - The script will automatically install AWS CLI via Homebrew when you use the `-s` flag
   - Manual installation: `brew install awscli`

2. **Configure AWS credentials:**
```bash
aws configure
```

Enter your:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., us-east-1)
- Default output format (json)

3. **Verify Support API access:**
```bash
aws support describe-services
```

**Required IAM Permissions:**
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

**Usage:**
```bash
# Create support case if bottlenecks found
sudo ./invoke-macos-forensics.sh -m standard -s

# Specify severity level
sudo ./invoke-macos-forensics.sh -m deep -s -v urgent

# Available severity levels: low, normal, high, urgent, critical
```

</details>

---

## 🛠️ **Troubleshooting**

<details>
<summary><strong>Permission Denied Errors</strong></summary>

**Problem:** Script fails with permission errors

**Solution:** Run with sudo:
```bash
sudo ./invoke-macos-forensics.sh -m standard
```

**Why:** Many system diagnostics require root privileges to access performance counters and system statistics.

</details>

<details>
<summary><strong>Homebrew Installation Fails</strong></summary>

**Problem:** Automatic Homebrew installation fails

**Solution 1:** Install Homebrew manually:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Solution 2:** Check for existing Homebrew installation:
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

**Problem:** Support case creation fails even with AWS CLI installed

**Checks:**

1. **Verify AWS CLI installation:**
```bash
aws --version
```

2. **Check AWS credentials:**
```bash
aws sts get-caller-identity
```

3. **Verify Support plan:**
   - Log into AWS Console
   - Navigate to Support Center
   - Confirm Business or Enterprise Support plan is active

4. **Test Support API access:**
```bash
aws support describe-services
```

**Common Issues:**
- No active Support plan (requires Business or Enterprise)
- Insufficient IAM permissions
- Expired AWS credentials
- Wrong AWS region configuration

</details>

<details>
<summary><strong>Database Queries Fail</strong></summary>

**Problem:** Database forensics shows "Unable to query" messages

**Causes:**
- Database requires authentication
- Database user lacks necessary permissions
- Database is not listening on default port

**Solutions:**

**MySQL/MariaDB:**
```bash
# Grant permissions to root user
mysql -u root -p
GRANT SELECT ON *.* TO 'root'@'localhost';
FLUSH PRIVILEGES;
```

**PostgreSQL:**
```bash
# Edit pg_hba.conf to allow local connections
sudo vi /usr/local/var/postgresql@14/pg_hba.conf
# Add: local all postgres trust
sudo brew services restart postgresql@14
```

**MongoDB:**
```bash
# Connect with authentication
mongosh --username admin --password
```

**Note:** The script will continue and report other metrics even if database queries fail.

</details>

<details>
<summary><strong>High Memory Pressure False Positives</strong></summary>

**Problem:** Script reports low memory but system feels responsive

**Explanation:** macOS aggressively uses available memory for caching. The `memory_pressure` command provides a more accurate assessment than raw free memory.

**What to check:**
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

**Partition Scheme Detection:**
- **GPT** (GUID Partition Table) - Modern, required for macOS 10.11+
- **MBR** (Master Boot Record) - Legacy, 2TB limit (warns if >2TB disk)
- **APM** (Apple Partition Map) - Legacy PowerPC format

**Partition Alignment Analysis:**
- Uses `diskutil info` to get partition offsets
- Uses `gpt show` for detailed GPT partition analysis (when available)
- Checks 4K (4096 byte) alignment - minimum for modern storage
- Checks 1MB (1048576 byte) alignment - optimal for SSD/SAN
- Detects storage type from diskutil (SSD, NVMe, USB, Thunderbolt, Fibre Channel)
- Severity based on storage type:
  - **Internal SSD/NVMe**: High severity (30-50% performance loss)
  - **External SSD (USB/Thunderbolt)**: High severity (30-50% loss)
  - **SAN (Fibre Channel)**: High severity (30-50% loss + I/O amplification)
  - **HDD**: Medium severity (10-20% loss from read-modify-write)
- Note: APFS containers manage alignment internally and are always optimal
- Alignment issues typically affect HFS+, FAT32, exFAT volumes

**Filesystem Detection:**
- **APFS** - Modern Apple filesystem with encryption, snapshots, space sharing
- **HFS+** - Legacy Mac filesystem (migration to APFS recommended)
- **exFAT/FAT32** - Cross-platform for external drives
- **NTFS** - Windows (read-only by default on macOS)

**Boot Configuration Detection:**
- Apple Silicon: Always Secure Boot via iBoot
- Intel T2 Macs: Full/Medium/No Security modes
- Intel non-T2: UEFI without Secure Boot

**Optional (via Homebrew):**

| Tool | Purpose | Install Command |
|------|---------|-----------------|
| smartctl | Detailed SMART data | `brew install smartmontools` |

**Manual installation:**
```bash
# Install smartmontools for detailed SMART analysis
brew install smartmontools
```

The script will function without smartmontools but will provide less detailed SMART information (using diskutil's basic SMART status instead).

</details>

---

## 📦 **What's Included**

- `invoke-macos-forensics.sh` - Comprehensive forensics tool with bottleneck detection
- `README.md` - This documentation

---

## 🤝 **Support**

### **Contact**
- **Report bugs and feature requests:** [adrianrs@amazon.com](mailto:adrianrs@amazon.com)
- **GitHub Issues:** Report issues on the GitHub repository

### **AWS Support**
For AWS-specific issues on EC2 Mac instances, the tool can automatically create support cases with diagnostic data attached.

---

## ⚠️ **Important Notes**

- This utility requires sudo privileges for full diagnostics
- Tested on macOS 10.15 (Catalina) through macOS 15 (Sequoia)
- Works on Mac hardware (Intel and Apple Silicon) and AWS EC2 Mac instances
- Database forensics requires database client tools (mysql, psql, mongo, redis-cli, etc.)
- Some database queries require authentication - the script will note when queries fail
- **No warranty or official support provided** - use at your own discretion
- Always test in non-production environments first

### **Expected Performance Impact**

**Quick Mode (3 minutes):**
- CPU: <5% overhead - mostly reading system stats
- Memory: <50MB - lightweight data collection
- Disk I/O: Minimal - no performance testing, only stat collection
- Network: None - passive monitoring only
- **Safe for production** - read-only operations

**Standard Mode (5-10 minutes):**
- CPU: 5-10% overhead - includes sampling and process analysis
- Memory: <100MB - additional process tree analysis
- Disk I/O: Minimal - no write testing, only extended stat collection
- Network: None - passive monitoring only
- **Safe for production** - read-only operations

**Deep Mode (15-20 minutes):**
- CPU: 10-20% overhead - includes extended sampling
- Memory: <150MB - comprehensive process and memory analysis
- Disk I/O: Minimal - macOS version does not perform write tests
- Network: None - passive monitoring only
- **Safe for production** - read-only operations

**Database Query Analysis (all modes):**
- CPU: <2% overhead per database - lightweight queries to system tables
- Memory: <20MB per database - result set caching
- Database Load: Minimal - uses performance schema/DMVs/system views
- **Safe for production** - read-only queries, no table locks

**General Guidelines:**
- The tool is **read-only** - no disk write tests on macOS
- No application restarts or configuration changes
- Monitoring tools run for brief intervals
- Database queries target system/performance tables only, not user data
- All operations are non-blocking and use minimal system resources

---

## 📝 **Version History**

- **v1.2** (February 2026) - Added partition scheme and boot configuration detection
  - Partition scheme analysis (GPT vs MBR vs APM with >2TB warnings)
  - Boot configuration (Apple Silicon iBoot, Intel UEFI, T2 Secure Boot status)
  - Filesystem type detection (APFS, HFS+, exFAT, FAT32, NTFS)
  - APFS feature detection (FileVault, snapshots, space sharing)

- **v1.1** (February 2026) - Added comprehensive storage profiling
  - APFS container and CoreStorage analysis
  - SSD/HDD/Fusion Drive/NVMe detection
  - SMART health monitoring
  - Capacity profiling (directories, files, applications, caches)
  - Time Machine snapshot analysis
  - Network storage detection (NFS, SMB, AFP)
  - Storage performance baseline testing
  - AWS EC2 Mac EBS optimization recommendations

- **v1.0** (January 2026) - Initial release
  - Automatic Homebrew installation
  - Automatic AWS CLI installation
  - Comprehensive CPU, Memory, Disk, Network forensics
  - DBA-level database query analysis for 8 database platforms
  - AWS Support case integration
  - Automatic bottleneck detection

---

**Note:** This tool is provided as-is for diagnostic purposes. Always test in non-production environments first.

