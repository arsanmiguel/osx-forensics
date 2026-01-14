# macOS Performance Forensic Tools

## Overview

A comprehensive Bash utility designed to help system administrators and engineers diagnose macOS performance issues. Provides automated bottleneck detection, detailed forensics, and AWS Support integration.

**Key Features:**
- ✅ Comprehensive performance forensics (CPU, Memory, Disk, Network, Database)
- ✅ Automated bottleneck detection
- ✅ CPU forensics (load analysis, process tracking)
- ✅ Memory forensics (pressure detection, swap analysis)
- ✅ **Database forensics** - Detection of running database processes
- ✅ **Automatic AWS Support case creation** with diagnostic data
- ✅ **Automatic Homebrew installation** if not present
- ✅ Works on macOS 10.15 (Catalina) and later

---

## 🚀 **Quick Start**

### **Prerequisites**
- macOS 10.15 (Catalina) or later
- sudo privileges
- AWS CLI configured (optional, for automatic support case creation)
- Homebrew (optional, will be installed automatically if needed)

### **Installation**

1. **Clone the repository:**
```bash
git clone https://github.com/arsanmiguel/osx-forensics.git
cd osx-forensics
```

2. **Make the script executable:**
```bash
chmod +x invoke-macos-forensics.sh
```

---

## 📊 **Usage**

### **invoke-macos-forensics.sh**
**A complete macOS performance diagnostic tool** - comprehensive forensics with automatic issue detection.

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
```

---

## **What Bottlenecks Can Be Found?**

The tool automatically detects:

- **CPU Issues:** High CPU utilization (>80%), High load per core (>2.0)
- **Memory Issues:** Low available memory (<10% free), High swap usage (>1GB)
- **Disk Issues:** High disk usage (>90%)
- **Database Issues:** Running database processes (MySQL, PostgreSQL, MongoDB, Redis)

---

## 🔧 **AWS Support Integration**

The tool can automatically create AWS Support cases when performance issues are detected.

**Setup:**
1. Install AWS CLI: `brew install awscli`
2. Configure credentials: `aws configure`
3. Verify access: `aws support describe-services`

---

## ⚠️ **Important Notes**

- This utility requires sudo privileges
- Tested on macOS 10.15 (Catalina) through macOS 14 (Sonoma)
- Works on Mac hardware and AWS EC2 Mac instances
- **No warranty or official support provided** - use at your own discretion

---

## 📝 **Version History**

- **v1.0** (January 2026) - Initial release with automatic Homebrew installation

---

**Contact:** adrianrs@amazon.com
