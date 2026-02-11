#!/bin/bash

#############################################################################
# macOS Performance Forensic Tool
# 
# Comprehensive performance diagnostics with automatic bottleneck detection
# and AWS Support integration
#
# Supports: macOS 10.15 (Catalina) and later
#
# Usage: sudo ./invoke-macos-forensics.sh [OPTIONS]
#
# Options:
#   -m, --mode MODE          Diagnostic mode: quick, standard, deep, disk, cpu, memory
#   -s, --support            Create AWS Support case if issues found
#   -v, --severity LEVEL     Support case severity: low, normal, high, urgent, critical
#   -o, --output PATH        Output directory (default: current directory)
#   -h, --help               Show this help message
#
# Requires: sudo privileges
# Optional: AWS CLI for support case creation, Homebrew for package management
#############################################################################

set -euo pipefail

# Default values
MODE="standard"
CREATE_SUPPORT_CASE=false
SEVERITY="normal"
OUTPUT_DIR="$(pwd)"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT_FILE="${OUTPUT_DIR}/macos-forensics-${TIMESTAMP}.txt"
BOTTLENECKS=()
MISSING_PACKAGES=()

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Homebrew installation URL (latest)
HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

#############################################################################
# Logging Functions
#############################################################################

log_info() {
    echo -e "${CYAN}[$(date +%H:%M:%S)] $1${NC}"
}

log_success() {
    echo -e "${GREEN}[$(date +%H:%M:%S)] $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[$(date +%H:%M:%S)] $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date +%H:%M:%S)] $1${NC}"
}

#############################################################################
# Homebrew Management
#############################################################################

check_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        log_success "Homebrew is installed"
        return 0
    else
        log_warning "Homebrew is not installed"
        return 1
    fi
}

install_homebrew() {
    log_info "Installing Homebrew..."
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Homebrew is required for installing diagnostic utilities." | tee -a "$OUTPUT_FILE"
    echo "Installing from: ${HOMEBREW_INSTALL_URL}" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    # Download and run Homebrew installer
    if /bin/bash -c "$(curl -fsSL ${HOMEBREW_INSTALL_URL})"; then
        log_success "Homebrew installed successfully"
        
        # Add Homebrew to PATH for this session
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        
        return 0
    else
        log_error "Failed to install Homebrew"
        return 1
    fi
}

install_package() {
    local package="$1"
    
    if ! check_homebrew; then
        if ! install_homebrew; then
            log_error "Cannot install ${package} without Homebrew"
            MISSING_PACKAGES+=("$package")
            return 1
        fi
    fi
    
    log_info "Installing ${package} via Homebrew..."
    if brew install "$package" 2>&1 | tee -a "$OUTPUT_FILE"; then
        log_success "${package} installed successfully"
        return 0
    else
        log_error "Failed to install ${package}"
        MISSING_PACKAGES+=("$package")
        return 1
    fi
}

#############################################################################
# Utility Checks
#############################################################################

check_required_utilities() {
    log_info "Checking required utilities..."
    
    local utilities=(
        "top:coreutils"
        "iostat:coreutils"
        "vm_stat:native"
        "sysctl:native"
        "diskutil:native"
        "netstat:native"
        "ps:native"
        "iotop:iotop"
        "htop:htop"
        "btop:btop"
        "glances:glances"
    )
    
    for util_pair in "${utilities[@]}"; do
        local util="${util_pair%%:*}"
        local package="${util_pair##*:}"
        
        if [[ "$package" == "native" ]]; then
            if ! command -v "$util" >/dev/null 2>&1; then
                log_warning "${util} not found (should be native to macOS)"
            fi
        else
            if ! command -v "$util" >/dev/null 2>&1; then
                log_warning "${util} not found, attempting to install..."
                install_package "$package" || true
            fi
        fi
    done
    
    # Check for AWS CLI if support case creation is requested
    if [[ "$CREATE_SUPPORT_CASE" == true ]]; then
        if ! command -v aws >/dev/null 2>&1; then
            log_warning "AWS CLI not found, attempting to install..."
            install_package "awscli" || true
        else
            log_success "AWS CLI is installed"
        fi
    fi
    
    log_success "Utility check completed"
}

#############################################################################
# System Information
#############################################################################

gather_system_info() {
    log_info "Gathering system information..."
    
    echo "" | tee -a "$OUTPUT_FILE"
    echo "================================================================================" | tee -a "$OUTPUT_FILE"
    echo "  SYSTEM INFORMATION" | tee -a "$OUTPUT_FILE"
    echo "================================================================================" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    echo "Hostname: $(hostname)" | tee -a "$OUTPUT_FILE"
    echo "macOS Version: $(sw_vers -productVersion)" | tee -a "$OUTPUT_FILE"
    echo "Build: $(sw_vers -buildVersion)" | tee -a "$OUTPUT_FILE"
    echo "Kernel: $(uname -r)" | tee -a "$OUTPUT_FILE"
    echo "Architecture: $(uname -m)" | tee -a "$OUTPUT_FILE"
    echo "Uptime: $(uptime | awk '{print $3,$4}' | sed 's/,//')" | tee -a "$OUTPUT_FILE"
    
    local cpu_model=$(sysctl -n machdep.cpu.brand_string)
    echo "CPU: ${cpu_model}" | tee -a "$OUTPUT_FILE"
    
    local cpu_cores=$(sysctl -n hw.ncpu)
    echo "CPU Cores: ${cpu_cores}" | tee -a "$OUTPUT_FILE"
    
    local total_mem=$(sysctl -n hw.memsize | awk '{print $1/1024/1024/1024 " GB"}')
    echo "Total Memory: ${total_mem}" | tee -a "$OUTPUT_FILE"
    
    # Check if running on EC2
    if curl -s -m 2 http://169.254.169.254/latest/meta-data/instance-id >/dev/null 2>&1; then
        local instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
        echo "Instance ID: ${instance_id}" | tee -a "$OUTPUT_FILE"
    else
        echo "Instance ID: Not EC2" | tee -a "$OUTPUT_FILE"
    fi
    
    log_success "System information collected"
}

#############################################################################
# Glances System Overview
#############################################################################

analyze_glances_overview() {
    if command -v glances >/dev/null 2>&1; then
        echo "" | tee -a "$OUTPUT_FILE"
        echo "================================================================================" | tee -a "$OUTPUT_FILE"
        echo "  GLANCES SYSTEM OVERVIEW" | tee -a "$OUTPUT_FILE"
        echo "================================================================================" | tee -a "$OUTPUT_FILE"
        echo "" | tee -a "$OUTPUT_FILE"
        
        log_info "Capturing glances system snapshot..."
        
        # Glances system summary - note interactive use only
        # (macOS glances --stdout doesn't exit cleanly in batch mode)
        echo "Glances is installed and available for interactive monitoring." | tee -a "$OUTPUT_FILE"
        echo "" | tee -a "$OUTPUT_FILE"
        echo "Usage: Run 'glances' for real-time monitoring with:" | tee -a "$OUTPUT_FILE"
        echo "  - CPU, memory, disk, network graphs" | tee -a "$OUTPUT_FILE"
        echo "  - Per-process resource usage" | tee -a "$OUTPUT_FILE"
        echo "  - Docker/container monitoring" | tee -a "$OUTPUT_FILE"
        echo "  - Alerts and thresholds" | tee -a "$OUTPUT_FILE"
        echo "  - Web server mode: glances -w" | tee -a "$OUTPUT_FILE"
        
        log_success "Glances overview completed"
    fi
}

#############################################################################
# CPU Forensics
#############################################################################

analyze_cpu() {
    log_info "Analyzing CPU performance..."
    
    echo "" | tee -a "$OUTPUT_FILE"
    echo "================================================================================" | tee -a "$OUTPUT_FILE"
    echo "  CPU FORENSICS" | tee -a "$OUTPUT_FILE"
    echo "================================================================================" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    # Load average
    local load_avg=$(uptime | awk -F'load averages:' '{print $2}' | xargs)
    echo "Load Average (1m, 5m, 15m): ${load_avg}" | tee -a "$OUTPUT_FILE"
    
    local cpu_cores=$(sysctl -n hw.ncpu)
    local load_1m=$(echo "$load_avg" | awk '{print $1}')
    local load_per_core=$(echo "scale=2; $load_1m / $cpu_cores" | bc)
    echo "Load per Core: ${load_per_core}" | tee -a "$OUTPUT_FILE"
    
    # CPU usage from top
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Current CPU Usage:" | tee -a "$OUTPUT_FILE"
    top -l 1 -n 0 | grep "CPU usage" | tee -a "$OUTPUT_FILE"
    
    # Top CPU consumers
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Top 10 CPU-consuming processes:" | tee -a "$OUTPUT_FILE"
    { ps aux | sort -rk 3 | head -11 || true; } | tee -a "$OUTPUT_FILE"
    
    # ==========================================================================
    # ENHANCED CPU PROFILING (htop/btop)
    # ==========================================================================
    if command -v htop >/dev/null 2>&1; then
        echo "" | tee -a "$OUTPUT_FILE"
        echo "--- HTOP AVAILABLE ---" | tee -a "$OUTPUT_FILE"
        echo "  htop installed - run 'sudo htop' for interactive process monitoring" | tee -a "$OUTPUT_FILE"
        echo "  Features: Per-CPU usage bars, process tree, memory visualization" | tee -a "$OUTPUT_FILE"
        echo "  Note: htop requires terminal for full output (curses-based)" | tee -a "$OUTPUT_FILE"
    fi
    
    if command -v btop >/dev/null 2>&1; then
        echo "" | tee -a "$OUTPUT_FILE"
        echo "--- BTOP AVAILABLE ---" | tee -a "$OUTPUT_FILE"
        echo "  btop installed - run 'btop' for interactive system monitoring" | tee -a "$OUTPUT_FILE"
        echo "  Features: CPU, memory, disk, network graphs with historical data" | tee -a "$OUTPUT_FILE"
    fi
    
    # Check for high CPU usage
    local cpu_idle=$(top -l 1 -n 0 | grep "CPU usage" | awk '{print $7}' | sed 's/%//')
    local cpu_used=$(echo "100 - $cpu_idle" | bc)
    
    if (( $(echo "$cpu_used > 80" | bc -l) )); then
        BOTTLENECKS+=("CPU: High CPU utilization (${cpu_used}%)")
    fi
    
    if (( $(echo "$load_per_core > 2.0" | bc -l) )); then
        BOTTLENECKS+=("CPU: High load per core (${load_per_core})")
    fi
    
    # ==========================================================================
    # SAR CPU ANALYSIS (macOS)
    # ==========================================================================
    if command -v sar >/dev/null 2>&1; then
        echo "" | tee -a "$OUTPUT_FILE"
        echo "--- SAR CPU ANALYSIS ---" | tee -a "$OUTPUT_FILE"
        
        # Real-time CPU sampling
        echo "" | tee -a "$OUTPUT_FILE"
        echo "CPU Utilization (sar -u, 5 samples):" | tee -a "$OUTPUT_FILE"
        sar -u 1 5 2>/dev/null | tee -a "$OUTPUT_FILE" || log_warning "sar -u failed"
        
        # Note: macOS sar doesn't auto-collect historical data like Linux sysstat
        echo "" | tee -a "$OUTPUT_FILE"
        echo "Note: macOS does not auto-collect historical sar data." | tee -a "$OUTPUT_FILE"
        echo "For continuous collection, use: sar -o /tmp/sardata.bin -u 60 &" | tee -a "$OUTPUT_FILE"
    else
        echo "" | tee -a "$OUTPUT_FILE"
        echo "sar not available on this system" | tee -a "$OUTPUT_FILE"
    fi
    
    log_success "CPU forensics completed"
}

#############################################################################
# Memory Forensics
#############################################################################

analyze_memory() {
    log_info "Analyzing memory usage..."
    
    echo "" | tee -a "$OUTPUT_FILE"
    echo "================================================================================" | tee -a "$OUTPUT_FILE"
    echo "  MEMORY FORENSICS" | tee -a "$OUTPUT_FILE"
    echo "================================================================================" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    # Memory statistics
    vm_stat | tee -a "$OUTPUT_FILE"
    
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Memory Pressure:" | tee -a "$OUTPUT_FILE"
    memory_pressure | tee -a "$OUTPUT_FILE"
    
    # Top memory consumers
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Top 10 memory-consuming processes:" | tee -a "$OUTPUT_FILE"
    { ps aux | sort -rk 4 | head -11 || true; } | tee -a "$OUTPUT_FILE"
    
    # Check memory pressure
    local mem_pressure=$(memory_pressure | grep "System-wide memory free percentage" | awk '{print $5}' | sed 's/%//')
    
    if [[ -n "$mem_pressure" ]] && (( $(echo "$mem_pressure < 10" | bc -l) )); then
        BOTTLENECKS+=("Memory: Low available memory (${mem_pressure}% free)")
    fi
    
    # Check swap usage
    local swap_used=$(sysctl vm.swapusage | grep -o "used = [0-9.]*[GM]" | awk '{print $3}')
    if [[ "$swap_used" =~ G ]]; then
        local swap_gb=$(echo "$swap_used" | sed 's/G//')
        if (( $(echo "$swap_gb > 1.0" | bc -l) )); then
            BOTTLENECKS+=("Memory: High swap usage (${swap_used})")
        fi
    fi
    
    # ==========================================================================
    # SAR MEMORY/PAGING ANALYSIS (macOS)
    # ==========================================================================
    if command -v sar >/dev/null 2>&1; then
        echo "" | tee -a "$OUTPUT_FILE"
        echo "--- SAR MEMORY/PAGING ANALYSIS ---" | tee -a "$OUTPUT_FILE"
        
        # Page-out activity (memory pressure indicator)
        echo "" | tee -a "$OUTPUT_FILE"
        echo "Page-out Activity (sar -g, 5 samples):" | tee -a "$OUTPUT_FILE"
        sar -g 1 5 2>/dev/null | tee -a "$OUTPUT_FILE" || log_warning "sar -g failed"
        
        # Page-in activity
        echo "" | tee -a "$OUTPUT_FILE"
        echo "Page-in Activity (sar -p, 5 samples):" | tee -a "$OUTPUT_FILE"
        sar -p 1 5 2>/dev/null | tee -a "$OUTPUT_FILE" || log_warning "sar -p failed"
    fi
    
    log_success "Memory forensics completed"
}

#############################################################################
# Disk Forensics
#############################################################################

analyze_disk() {
    log_info "Analyzing disk performance..."
    
    echo "" | tee -a "$OUTPUT_FILE"
    echo "================================================================================" | tee -a "$OUTPUT_FILE"
    echo "  DISK FORENSICS" | tee -a "$OUTPUT_FILE"
    echo "================================================================================" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    # Disk usage
    echo "Disk Usage:" | tee -a "$OUTPUT_FILE"
    df -h | tee -a "$OUTPUT_FILE"
    
    # Disk I/O statistics
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Disk I/O Statistics (5 samples):" | tee -a "$OUTPUT_FILE"
    iostat -d -c 5 | tee -a "$OUTPUT_FILE"
    
    # I/O wait analysis using iotop if available
    # macOS iotop syntax: iotop [-C] [-P] [interval [count]]
    if command -v iotop >/dev/null 2>&1; then
        echo "" | tee -a "$OUTPUT_FILE"
        echo "Top I/O Consumers (iotop):" | tee -a "$OUTPUT_FILE"
        iotop -C -P 1 5 2>/dev/null | tee -a "$OUTPUT_FILE" || echo "  Unable to run iotop" | tee -a "$OUTPUT_FILE"
    else
        echo "" | tee -a "$OUTPUT_FILE"
        echo "iotop not available (built into macOS, check path)" | tee -a "$OUTPUT_FILE"
    fi
    
    # Disk activity by process
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Processes with High Disk Activity:" | tee -a "$OUTPUT_FILE"
    { ps aux | awk 'NR==1 || $8 ~ /D/' | head -20 || true; } | tee -a "$OUTPUT_FILE"
    
    # Check disk latency using diskutil
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Disk Latency Analysis:" | tee -a "$OUTPUT_FILE"
    for disk in $(diskutil list | grep "^/dev/disk" | awk '{print $1}' | head -3); do
        echo "  ${disk}:" | tee -a "$OUTPUT_FILE"
        diskutil info "$disk" | grep -E "Device Block Size|Total Size|Volume Free Space|SMART Status" | tee -a "$OUTPUT_FILE"
    done
    
    # Check for high disk usage
    local disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    if (( disk_usage > 90 )); then
        BOTTLENECKS+=("Disk: High disk usage on root volume (${disk_usage}%)")
    fi
    
    # Check for I/O wait by looking at processes in D state (uninterruptible sleep)
    local io_wait_procs=$(ps aux | awk '$8 ~ /D/' | wc -l | tr -d ' ')
    if (( io_wait_procs > 5 )); then
        BOTTLENECKS+=("Disk: High I/O wait - ${io_wait_procs} processes in uninterruptible sleep")
    fi
    
    # ==========================================================================
    # SAR DISK I/O ANALYSIS (macOS)
    # ==========================================================================
    if command -v sar >/dev/null 2>&1; then
        echo "" | tee -a "$OUTPUT_FILE"
        echo "--- SAR DISK I/O ANALYSIS ---" | tee -a "$OUTPUT_FILE"
        
        # Disk activity
        echo "" | tee -a "$OUTPUT_FILE"
        echo "Disk Activity (sar -d, 5 samples):" | tee -a "$OUTPUT_FILE"
        sar -d 1 5 2>/dev/null | tee -a "$OUTPUT_FILE" || log_warning "sar -d failed"
    fi
    
    log_success "Disk forensics completed"
}

#############################################################################
# Storage Profiling
#############################################################################

analyze_storage_profile() {
    log_info "Performing comprehensive storage analysis..."
    
    echo "" | tee -a "$OUTPUT_FILE"
    echo "================================================================================" | tee -a "$OUTPUT_FILE"
    echo "  STORAGE PROFILING" | tee -a "$OUTPUT_FILE"
    echo "================================================================================" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    # ==========================================================================
    # PARTITION SCHEME ANALYSIS (GPT vs MBR)
    # ==========================================================================
    echo "--- PARTITION SCHEME ANALYSIS ---" | tee -a "$OUTPUT_FILE"
    
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Disk Partition Schemes:" | tee -a "$OUTPUT_FILE"
    
    local gpt_count=0
    local mbr_count=0
    local apfs_container_count=0
    
    for disk in $(diskutil list | grep "^/dev/disk" | grep -v synthesized | awk '{print $1}'); do
        local disk_info=$(diskutil info "$disk" 2>/dev/null)
        local partition_type=$(echo "$disk_info" | grep "Content (IOContent):" | cut -d: -f2 | xargs)
        local disk_size=$(echo "$disk_info" | grep "Disk Size:" | cut -d: -f2 | cut -d'(' -f1 | xargs)
        local disk_size_bytes=$(echo "$disk_info" | grep "Disk Size:" | grep -oE '\([0-9]+ Bytes\)' | grep -oE '[0-9]+')
        
        local scheme=""
        case "$partition_type" in
            GUID_partition_scheme|"GUID_partition_scheme")
                scheme="GPT (GUID Partition Table)"
                ((gpt_count++))
                ;;
            FDisk_partition_scheme|"FDisk_partition_scheme")
                scheme="MBR (Master Boot Record)"
                ((mbr_count++))
                # Check if >2TB with MBR
                if [[ -n "$disk_size_bytes" ]] && (( disk_size_bytes > 2199023255552 )); then
                    BOTTLENECKS+=("Storage: MBR partition scheme on >2TB disk $disk (data loss risk - only 2TB accessible)")
                fi
                ;;
            Apple_partition_scheme)
                scheme="APM (Apple Partition Map - Legacy PowerPC)"
                ;;
            Apple_APFS)
                scheme="APFS Container (synthesized)"
                ((apfs_container_count++))
                ;;
            *)
                scheme="$partition_type"
                ;;
        esac
        
        echo "  $disk: $scheme - $disk_size" | tee -a "$OUTPUT_FILE"
    done
    
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Partition Scheme Summary:" | tee -a "$OUTPUT_FILE"
    echo "  GPT Disks: $gpt_count (modern, UEFI, required for macOS 10.11+)" | tee -a "$OUTPUT_FILE"
    if (( mbr_count > 0 )); then
        echo "  MBR Disks: $mbr_count (legacy, 2TB limit - external drives only)" | tee -a "$OUTPUT_FILE"
    fi
    if (( apfs_container_count > 0 )); then
        echo "  APFS Containers: $apfs_container_count (virtual container disks)" | tee -a "$OUTPUT_FILE"
    fi
    
    # ==========================================================================
    # PARTITION ALIGNMENT ANALYSIS
    # ==========================================================================
    echo "" | tee -a "$OUTPUT_FILE"
    echo "--- PARTITION ALIGNMENT ANALYSIS ---" | tee -a "$OUTPUT_FILE"
    echo "Checking for 4K alignment (critical for SSD/SAN performance)..." | tee -a "$OUTPUT_FILE"
    
    local aligned_count=0
    local misaligned_count=0
    
    # Iterate through physical disks (not synthesized APFS containers)
    for disk in $(diskutil list | grep "^/dev/disk" | grep -v synthesized | awk '{print $1}'); do
        local disk_info=$(diskutil info "$disk" 2>/dev/null)
        
        # Determine storage type
        local storage_type="HDD"
        local solid_state=$(echo "$disk_info" | grep "Solid State:" | cut -d: -f2 | xargs)
        local media_name=$(echo "$disk_info" | grep "Media Name:" | cut -d: -f2 | xargs)
        local protocol=$(echo "$disk_info" | grep "Protocol:" | cut -d: -f2 | xargs)
        
        if [[ "$solid_state" == "Yes" ]]; then
            storage_type="SSD"
        fi
        
        # Check for NVMe
        if [[ "$protocol" == *"NVMe"* ]] || [[ "$media_name" == *"NVMe"* ]]; then
            storage_type="NVMe"
        fi
        
        # Check for external/USB (often SSD these days)
        if [[ "$protocol" == *"USB"* ]]; then
            storage_type="USB"
        fi
        
        # Check for Thunderbolt (often external SSD or SAN)
        if [[ "$protocol" == *"Thunderbolt"* ]]; then
            storage_type="Thunderbolt"
        fi
        
        # Check for Fibre Channel (SAN)
        if [[ "$protocol" == *"Fibre"* ]] || [[ "$protocol" == *"FC"* ]]; then
            storage_type="SAN"
        fi
        
        # Get block size
        local block_size=$(echo "$disk_info" | grep "Device Block Size:" | grep -oE '[0-9]+' | head -1)
        [[ -z "$block_size" ]] && block_size=512
        
        # Get partition map entries using diskutil list
        local disk_num=$(echo "$disk" | grep -oE 'disk[0-9]+')
        
        # Parse diskutil list for partition offsets
        # macOS diskutil doesn't directly expose partition offsets, so we use 'gpt show' or 'fdisk'
        if command -v gpt >/dev/null 2>&1; then
            # Use gpt tool for GPT disks (requires root)
            local gpt_output=$(gpt show "$disk" 2>/dev/null)
            if [[ -n "$gpt_output" ]]; then
                echo "" | tee -a "$OUTPUT_FILE"
                echo "  $disk [$storage_type] - Block Size: ${block_size} bytes:" | tee -a "$OUTPUT_FILE"
                
                # Parse gpt show output: start_sector size type
                while read -r start_sector size ptype rest; do
                    [[ -z "$start_sector" ]] && continue
                    [[ "$start_sector" == "start" ]] && continue
                    [[ ! "$start_sector" =~ ^[0-9]+$ ]] && continue
                    
                    # Calculate offset in bytes
                    local offset_bytes=$((start_sector * block_size))
                    local offset_kb=$((offset_bytes / 1024))
                    
                    # Check 4K alignment
                    local aligned_4k="NO"
                    if (( offset_bytes % 4096 == 0 )); then
                        aligned_4k="YES"
                    fi
                    
                    # Check 1MB alignment
                    local aligned_1mb="NO"
                    if (( offset_bytes % 1048576 == 0 )); then
                        aligned_1mb="YES"
                    fi
                    
                    # Skip free space entries
                    [[ "$ptype" == "-" ]] && continue
                    
                    if [[ "$aligned_4k" == "YES" ]]; then
                        ((aligned_count++))
                        local align_status="ALIGNED"
                        if [[ "$aligned_1mb" == "YES" ]]; then
                            align_status="ALIGNED (1MB - optimal)"
                        fi
                        echo "    Sector $start_sector: $align_status - Offset: ${offset_kb}KB - Type: $ptype" | tee -a "$OUTPUT_FILE"
                    else
                        ((misaligned_count++))
                        echo "    Sector $start_sector: MISALIGNED - Offset: ${offset_kb}KB - Type: $ptype" | tee -a "$OUTPUT_FILE"
                        
                        # Determine severity
                        local severity="Medium"
                        if [[ "$storage_type" == "SSD" ]] || [[ "$storage_type" == "NVMe" ]] || [[ "$storage_type" == "SAN" ]]; then
                            severity="High"
                        fi
                        
                        BOTTLENECKS+=("Storage: Misaligned partition on $disk sector $start_sector [$storage_type] - ${offset_kb}KB offset")
                    fi
                done <<< "$gpt_output"
            fi
        fi
        
        # Fallback: use diskutil info on each partition slice
        for slice in $(diskutil list "$disk" 2>/dev/null | grep -E "^\s+[0-9]+:" | awk '{print $NF}'); do
            local slice_dev="/dev/$slice"
            [[ -e "$slice_dev" ]] || continue
            
            local slice_info=$(diskutil info "$slice_dev" 2>/dev/null)
            local part_offset=$(echo "$slice_info" | grep "Partition Offset:" | grep -oE '[0-9]+' | head -1)
            
            if [[ -n "$part_offset" ]] && [[ "$part_offset" -gt 0 ]]; then
                local offset_kb=$((part_offset / 1024))
                
                # Check 4K alignment
                local aligned_4k="NO"
                if (( part_offset % 4096 == 0 )); then
                    aligned_4k="YES"
                fi
                
                # Check 1MB alignment
                local aligned_1mb="NO"
                if (( part_offset % 1048576 == 0 )); then
                    aligned_1mb="YES"
                fi
                
                local vol_name=$(echo "$slice_info" | grep "Volume Name:" | cut -d: -f2 | xargs)
                [[ -z "$vol_name" ]] && vol_name="Unnamed"
                
                if [[ "$aligned_4k" == "YES" ]]; then
                    ((aligned_count++))
                    local align_status="ALIGNED"
                    if [[ "$aligned_1mb" == "YES" ]]; then
                        align_status="ALIGNED (1MB - optimal)"
                    fi
                    echo "  $slice_dev ($vol_name): $align_status - Offset: ${offset_kb}KB [$storage_type]" | tee -a "$OUTPUT_FILE"
                else
                    ((misaligned_count++))
                    echo "  $slice_dev ($vol_name): MISALIGNED - Offset: ${offset_kb}KB [$storage_type]" | tee -a "$OUTPUT_FILE"
                    
                    local severity="Medium"
                    local perf_impact="10-20% performance loss"
                    if [[ "$storage_type" == "SSD" ]] || [[ "$storage_type" == "NVMe" ]]; then
                        severity="High"
                        perf_impact="30-50% performance loss"
                    elif [[ "$storage_type" == "SAN" ]] || [[ "$storage_type" == "Thunderbolt" ]]; then
                        severity="High"
                        perf_impact="30-50% performance loss"
                    fi
                    
                    BOTTLENECKS+=("Storage: Misaligned partition $slice_dev ($vol_name) [$storage_type] - Offset ${offset_kb}KB not 4K aligned")
                fi
            fi
        done
    done
    
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Partition Alignment Summary:" | tee -a "$OUTPUT_FILE"
    echo "  Aligned partitions: $aligned_count" | tee -a "$OUTPUT_FILE"
    if (( misaligned_count > 0 )); then
        echo "  Misaligned partitions: $misaligned_count (PERFORMANCE IMPACT)" | tee -a "$OUTPUT_FILE"
        echo "" | tee -a "$OUTPUT_FILE"
        echo "  Misalignment Impact:" | tee -a "$OUTPUT_FILE"
        echo "    - Internal SSD/NVMe: 30-50% performance degradation" | tee -a "$OUTPUT_FILE"
        echo "    - External SSD (USB/Thunderbolt): 30-50% degradation" | tee -a "$OUTPUT_FILE"
        echo "    - SAN (Fibre Channel): 30-50% degradation + backend I/O amplification" | tee -a "$OUTPUT_FILE"
        echo "    - HDD: 10-20% degradation (extra read-modify-write cycles)" | tee -a "$OUTPUT_FILE"
        echo "" | tee -a "$OUTPUT_FILE"
        echo "  Remediation:" | tee -a "$OUTPUT_FILE"
        echo "    - Backup data and reformat with Disk Utility (auto-aligns on modern macOS)" | tee -a "$OUTPUT_FILE"
        echo "    - Use 'diskutil partitionDisk' which aligns by default" | tee -a "$OUTPUT_FILE"
        echo "    - Common cause: drives formatted on older macOS or other OS" | tee -a "$OUTPUT_FILE"
    else
        if (( aligned_count > 0 )); then
            echo "  All partitions are properly aligned" | tee -a "$OUTPUT_FILE"
        else
            echo "  No partition offset data available (APFS containers manage alignment internally)" | tee -a "$OUTPUT_FILE"
        fi
    fi
    
    # Note about APFS
    echo "" | tee -a "$OUTPUT_FILE"
    echo "  Note: APFS containers manage block allocation internally and are always optimally aligned." | tee -a "$OUTPUT_FILE"
    echo "        Alignment issues typically only affect HFS+, FAT32, or exFAT volumes." | tee -a "$OUTPUT_FILE"
    
    # ==========================================================================
    # BOOT CONFIGURATION
    # ==========================================================================
    echo "" | tee -a "$OUTPUT_FILE"
    echo "--- BOOT CONFIGURATION ---" | tee -a "$OUTPUT_FILE"
    
    # All Intel Macs use UEFI, Apple Silicon uses custom boot ROM
    local cpu_brand=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "")
    local arch=$(uname -m)
    
    echo "" | tee -a "$OUTPUT_FILE"
    if [[ "$arch" == "arm64" ]]; then
        echo "  Architecture: Apple Silicon (arm64)" | tee -a "$OUTPUT_FILE"
        echo "  Firmware: Apple Boot ROM (iBoot)" | tee -a "$OUTPUT_FILE"
        echo "  Secure Boot: Always enabled on Apple Silicon" | tee -a "$OUTPUT_FILE"
    else
        echo "  Architecture: Intel x86_64" | tee -a "$OUTPUT_FILE"
        echo "  Firmware: UEFI (Intel Macs since 2006)" | tee -a "$OUTPUT_FILE"
        
        # Check Secure Boot status (T2 Macs)
        local secure_boot=$(nvram 94b73556-2197-4702-82a8-3e1337dafbfb:AppleSecureBootPolicy 2>/dev/null | awk '{print $2}')
        case "$secure_boot" in
            "%02")
                echo "  Secure Boot: Full Security (T2 chip)" | tee -a "$OUTPUT_FILE"
                ;;
            "%01")
                echo "  Secure Boot: Medium Security (T2 chip)" | tee -a "$OUTPUT_FILE"
                ;;
            "%00")
                echo "  Secure Boot: No Security (T2 chip disabled)" | tee -a "$OUTPUT_FILE"
                ;;
            *)
                # Check if T2 chip exists
                if system_profiler SPiBridgeDataType 2>/dev/null | grep -q "T2"; then
                    echo "  Secure Boot: T2 chip present (status unknown)" | tee -a "$OUTPUT_FILE"
                else
                    echo "  Secure Boot: Not available (no T2 chip)" | tee -a "$OUTPUT_FILE"
                fi
                ;;
        esac
    fi
    
    # Boot volume info
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Boot Volume:" | tee -a "$OUTPUT_FILE"
    local boot_vol=$(bless --info --getBoot 2>/dev/null)
    [[ -n "$boot_vol" ]] && echo "  $boot_vol" | tee -a "$OUTPUT_FILE"
    
    # Startup disk
    local startup_disk=$(system_profiler SPSoftwareDataType 2>/dev/null | grep "Boot Volume:" | cut -d: -f2 | xargs)
    [[ -n "$startup_disk" ]] && echo "  Startup Disk: $startup_disk" | tee -a "$OUTPUT_FILE"
    
    # Boot mode
    local boot_mode=$(system_profiler SPSoftwareDataType 2>/dev/null | grep "Boot Mode:" | cut -d: -f2 | xargs)
    [[ -n "$boot_mode" ]] && echo "  Boot Mode: $boot_mode" | tee -a "$OUTPUT_FILE"
    
    # ==========================================================================
    # FILESYSTEM TYPES
    # ==========================================================================
    echo "" | tee -a "$OUTPUT_FILE"
    echo "--- FILESYSTEM TYPES ---" | tee -a "$OUTPUT_FILE"
    
    local apfs_count=0
    local hfs_count=0
    local exfat_count=0
    local msdos_count=0
    local ntfs_count=0
    local other_fs_count=0
    
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Mounted Volumes by Filesystem:" | tee -a "$OUTPUT_FILE"
    
    # Parse mount output for filesystem types
    while IFS= read -r line; do
        local fs_type=$(echo "$line" | grep -oE '\([^)]+\)' | head -1 | tr -d '()')
        local mount_point=$(echo "$line" | awk '{print $3}')
        local device=$(echo "$line" | awk '{print $1}')
        
        case "$fs_type" in
            apfs)
                ((apfs_count++))
                ;;
            hfs)
                ((hfs_count++))
                ;;
            exfat)
                ((exfat_count++))
                ;;
            msdos)
                ((msdos_count++))
                ;;
            ntfs)
                ((ntfs_count++))
                ;;
            *)
                [[ -n "$fs_type" ]] && ((other_fs_count++))
                ;;
        esac
    done < <(mount 2>/dev/null | grep "^/dev")
    
    echo "  APFS: $apfs_count volume(s) - Modern Apple filesystem (encryption, snapshots, space sharing)" | tee -a "$OUTPUT_FILE"
    if (( hfs_count > 0 )); then
        echo "  HFS+: $hfs_count volume(s) - Legacy Mac filesystem (consider migration to APFS)" | tee -a "$OUTPUT_FILE"
    fi
    if (( exfat_count > 0 )); then
        echo "  exFAT: $exfat_count volume(s) - Cross-platform (external drives)" | tee -a "$OUTPUT_FILE"
    fi
    if (( msdos_count > 0 )); then
        echo "  FAT32: $msdos_count volume(s) - Legacy cross-platform" | tee -a "$OUTPUT_FILE"
    fi
    if (( ntfs_count > 0 )); then
        echo "  NTFS: $ntfs_count volume(s) - Windows filesystem (read-only by default)" | tee -a "$OUTPUT_FILE"
    fi
    
    # APFS feature detection
    echo "" | tee -a "$OUTPUT_FILE"
    echo "APFS Features Detected:" | tee -a "$OUTPUT_FILE"
    
    # Check for FileVault (encryption)
    local fv_status=$(fdesetup status 2>/dev/null)
    echo "  FileVault: $fv_status" | tee -a "$OUTPUT_FILE"
    
    # Check for APFS snapshots
    local snapshot_count=$(tmutil listlocalsnapshots / 2>/dev/null | grep -c "com.apple" || echo "0")
    echo "  Local Snapshots: $snapshot_count Time Machine snapshot(s)" | tee -a "$OUTPUT_FILE"
    
    # Check for APFS space sharing (containers with multiple volumes)
    local shared_containers=$(diskutil apfs list 2>/dev/null | grep -c "APFS Volume Disk" || echo "0")
    if (( shared_containers > 1 )); then
        echo "  Space Sharing: Active ($shared_containers volumes sharing container space)" | tee -a "$OUTPUT_FILE"
    fi
    
    # ==========================================================================
    # STORAGE TOPOLOGY
    # ==========================================================================
    echo "" | tee -a "$OUTPUT_FILE"
    echo "--- STORAGE TOPOLOGY ---" | tee -a "$OUTPUT_FILE"
    
    # Disk list with detailed info
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Physical Disks:" | tee -a "$OUTPUT_FILE"
    diskutil list | tee -a "$OUTPUT_FILE"
    
    # APFS Container info
    echo "" | tee -a "$OUTPUT_FILE"
    echo "APFS Containers:" | tee -a "$OUTPUT_FILE"
    diskutil apfs list 2>/dev/null | tee -a "$OUTPUT_FILE" || echo "  No APFS containers found" | tee -a "$OUTPUT_FILE"
    
    # CoreStorage info (for older macOS with Fusion drives)
    echo "" | tee -a "$OUTPUT_FILE"
    echo "CoreStorage Logical Volume Groups:" | tee -a "$OUTPUT_FILE"
    diskutil cs list 2>/dev/null | tee -a "$OUTPUT_FILE" || echo "  No CoreStorage volumes found" | tee -a "$OUTPUT_FILE"
    
    # RAID information
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Software RAID:" | tee -a "$OUTPUT_FILE"
    diskutil appleRAID list 2>/dev/null | tee -a "$OUTPUT_FILE" || echo "  No Apple RAID sets found" | tee -a "$OUTPUT_FILE"
    
    # ==========================================================================
    # STORAGE TIERING (SSD vs HDD vs Fusion)
    # ==========================================================================
    echo "" | tee -a "$OUTPUT_FILE"
    echo "--- STORAGE TIERING ---" | tee -a "$OUTPUT_FILE"
    
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Drive Types:" | tee -a "$OUTPUT_FILE"
    
    local ssd_count=0
    local hdd_count=0
    local fusion_count=0
    
    # Get physical disk info
    for disk in $(diskutil list | grep "^/dev/disk" | awk '{print $1}'); do
        local disk_info=$(diskutil info "$disk" 2>/dev/null)
        local media_name=$(echo "$disk_info" | grep "Media Name:" | cut -d: -f2 | xargs)
        local solid_state=$(echo "$disk_info" | grep "Solid State:" | cut -d: -f2 | xargs)
        local disk_size=$(echo "$disk_info" | grep "Disk Size:" | cut -d: -f2 | cut -d'(' -f1 | xargs)
        local fusion=$(echo "$disk_info" | grep "Fusion Drive:" | cut -d: -f2 | xargs)
        
        if [[ "$fusion" == "Yes" ]]; then
            echo "  $disk: Fusion Drive - $disk_size - $media_name" | tee -a "$OUTPUT_FILE"
            ((fusion_count++))
        elif [[ "$solid_state" == "Yes" ]]; then
            echo "  $disk: SSD - $disk_size - $media_name" | tee -a "$OUTPUT_FILE"
            ((ssd_count++))
        elif [[ "$solid_state" == "No" ]]; then
            echo "  $disk: HDD - $disk_size - $media_name" | tee -a "$OUTPUT_FILE"
            ((hdd_count++))
        fi
    done
    
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Storage Tier Summary: SSD=$ssd_count, HDD=$hdd_count, Fusion=$fusion_count" | tee -a "$OUTPUT_FILE"
    
    # NVMe specific info
    echo "" | tee -a "$OUTPUT_FILE"
    echo "NVMe Controller Info:" | tee -a "$OUTPUT_FILE"
    system_profiler SPNVMeDataType 2>/dev/null | grep -E "Model|Capacity|Link|TRIM" | tee -a "$OUTPUT_FILE" || echo "  No NVMe drives detected" | tee -a "$OUTPUT_FILE"
    
    # ==========================================================================
    # CLOUD STORAGE DETECTION (AWS EC2 Mac)
    # ==========================================================================
    echo "" | tee -a "$OUTPUT_FILE"
    echo "--- CLOUD STORAGE DETECTION ---" | tee -a "$OUTPUT_FILE"
    
    # Check if running on EC2 Mac
    if curl -s -m 2 http://169.254.169.254/latest/meta-data/instance-id &>/dev/null; then
        echo "" | tee -a "$OUTPUT_FILE"
        echo "AWS EC2 Mac Instance Detected:" | tee -a "$OUTPUT_FILE"
        
        local instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
        local instance_type=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
        local region=$(curl -s http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || \
                       curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')
        
        echo "  Instance ID: $instance_id" | tee -a "$OUTPUT_FILE"
        echo "  Instance Type: $instance_type" | tee -a "$OUTPUT_FILE"
        echo "  Region: $region" | tee -a "$OUTPUT_FILE"
        
        # EC2 Mac uses EBS for root volume
        if command -v aws >/dev/null 2>&1; then
            echo "" | tee -a "$OUTPUT_FILE"
            echo "  EBS Volumes:" | tee -a "$OUTPUT_FILE"
            aws ec2 describe-volumes --filters "Name=attachment.instance-id,Values=$instance_id" \
                --query 'Volumes[*].{ID:VolumeId,Type:VolumeType,Size:Size,IOPS:Iops}' \
                --output table --region "$region" 2>/dev/null | tee -a "$OUTPUT_FILE" || \
                echo "  Unable to query EBS volumes" | tee -a "$OUTPUT_FILE"
        fi
    else
        echo "  Not running on AWS EC2" | tee -a "$OUTPUT_FILE"
    fi
    
    # ==========================================================================
    # SMART HEALTH STATUS
    # ==========================================================================
    echo "" | tee -a "$OUTPUT_FILE"
    echo "--- SMART HEALTH STATUS ---" | tee -a "$OUTPUT_FILE"
    
    # Use diskutil for SMART status
    for disk in $(diskutil list | grep "^/dev/disk" | grep -v synthesized | awk '{print $1}'); do
        echo "" | tee -a "$OUTPUT_FILE"
        echo "SMART Status for $disk:" | tee -a "$OUTPUT_FILE"
        local smart_status=$(diskutil info "$disk" 2>/dev/null | grep "SMART Status:")
        echo "  $smart_status" | tee -a "$OUTPUT_FILE"
        
        if echo "$smart_status" | grep -qi "failing\|about to fail"; then
            BOTTLENECKS+=("Storage: SMART failure detected on $disk")
        fi
    done
    
    # Use smartctl if available (via Homebrew)
    if command -v smartctl >/dev/null 2>&1; then
        echo "" | tee -a "$OUTPUT_FILE"
        echo "Detailed SMART Data (smartctl):" | tee -a "$OUTPUT_FILE"
        for disk in /dev/disk0 /dev/disk1; do
            [[ -e "$disk" ]] || continue
            echo "" | tee -a "$OUTPUT_FILE"
            echo "  $disk:" | tee -a "$OUTPUT_FILE"
            smartctl -a "$disk" 2>/dev/null | grep -E "SMART overall|Percentage Used|Power On Hours|Wear_Leveling" | tee -a "$OUTPUT_FILE"
        done
    else
        echo "" | tee -a "$OUTPUT_FILE"
        echo "  Install smartmontools for detailed SMART data: brew install smartmontools" | tee -a "$OUTPUT_FILE"
    fi
    
    # ==========================================================================
    # CAPACITY PROFILING
    # ==========================================================================
    echo "" | tee -a "$OUTPUT_FILE"
    echo "--- CAPACITY PROFILING ---" | tee -a "$OUTPUT_FILE"
    
    # Filesystem capacity
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Filesystem Capacity:" | tee -a "$OUTPUT_FILE"
    df -h | tee -a "$OUTPUT_FILE"
    
    # Storage overview from system_profiler
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Storage Overview:" | tee -a "$OUTPUT_FILE"
    system_profiler SPStorageDataType 2>/dev/null | grep -E "Mount Point:|Available:|Capacity:|File System:|Writable:" | tee -a "$OUTPUT_FILE"
    
    # Top space consumers
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Top 10 Directories by Size (/):" | tee -a "$OUTPUT_FILE"
    { du -hx -d 1 / 2>/dev/null | sort -rh | head -11 || true; } | tee -a "$OUTPUT_FILE"
    
    # User directory breakdown
    echo "" | tee -a "$OUTPUT_FILE"
    echo "User Home Directory Breakdown:" | tee -a "$OUTPUT_FILE"
    if [[ -d "$HOME" ]]; then
        { du -hx -d 1 "$HOME" 2>/dev/null | sort -rh | head -10 || true; } | tee -a "$OUTPUT_FILE"
    fi
    
    # Large files
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Large Files (>1GB):" | tee -a "$OUTPUT_FILE"
    find / -xdev -type f -size +1G -exec ls -lh {} \; 2>/dev/null | sort -k5 -rh | head -10 | tee -a "$OUTPUT_FILE" || echo "  Unable to scan for large files" | tee -a "$OUTPUT_FILE"
    
    # Application sizes
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Largest Applications:" | tee -a "$OUTPUT_FILE"
    { du -sh /Applications/* 2>/dev/null | sort -rh | head -10 || true; } | tee -a "$OUTPUT_FILE"
    
    # Caches and temporary files
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Cache and Temporary Storage:" | tee -a "$OUTPUT_FILE"
    echo "  System Caches: $(du -sh /Library/Caches 2>/dev/null | awk '{print $1}')" | tee -a "$OUTPUT_FILE"
    echo "  User Caches: $(du -sh ~/Library/Caches 2>/dev/null | awk '{print $1}')" | tee -a "$OUTPUT_FILE"
    echo "  Temporary Files: $(du -sh /tmp 2>/dev/null | awk '{print $1}')" | tee -a "$OUTPUT_FILE"
    echo "  Xcode DerivedData: $(du -sh ~/Library/Developer/Xcode/DerivedData 2>/dev/null | awk '{print $1}')" | tee -a "$OUTPUT_FILE"
    
    # Time Machine snapshots
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Time Machine Local Snapshots:" | tee -a "$OUTPUT_FILE"
    tmutil listlocalsnapshots / 2>/dev/null | tee -a "$OUTPUT_FILE" || echo "  No local snapshots found" | tee -a "$OUTPUT_FILE"
    
    # ==========================================================================
    # FILESYSTEM HEALTH
    # ==========================================================================
    echo "" | tee -a "$OUTPUT_FILE"
    echo "--- FILESYSTEM HEALTH ---" | tee -a "$OUTPUT_FILE"
    
    # Volume verification status (internal disks only - external can take too long)
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Volume Verification:" | tee -a "$OUTPUT_FILE"
    echo "  (Verifying internal volumes only - external drives skipped for speed)" | tee -a "$OUTPUT_FILE"
    
    # Only verify volumes on disk0 (internal SSD) - external drives take too long
    for vol in $(diskutil list disk0 2>/dev/null | grep "Apple_APFS" | awk '{print $NF}'); do
        echo "  Checking $vol..." | tee -a "$OUTPUT_FILE"
        if command -v gtimeout >/dev/null 2>&1; then
            { gtimeout 60 diskutil verifyVolume "$vol" 2>/dev/null | grep -E "appears to be OK|error|invalid" || echo "  Verification timed out or skipped"; } | tee -a "$OUTPUT_FILE"
        else
            { diskutil verifyVolume "$vol" 2>/dev/null | grep -E "appears to be OK|error|invalid" || true; } | tee -a "$OUTPUT_FILE"
        fi
    done
    
    # ==========================================================================
    # NETWORK STORAGE
    # ==========================================================================
    echo "" | tee -a "$OUTPUT_FILE"
    echo "--- NETWORK STORAGE ---" | tee -a "$OUTPUT_FILE"
    
    # NFS mounts
    echo "" | tee -a "$OUTPUT_FILE"
    echo "NFS Mounts:" | tee -a "$OUTPUT_FILE"
    mount | grep nfs | tee -a "$OUTPUT_FILE" || echo "  No NFS mounts" | tee -a "$OUTPUT_FILE"
    
    # SMB mounts
    echo "" | tee -a "$OUTPUT_FILE"
    echo "SMB/CIFS Mounts:" | tee -a "$OUTPUT_FILE"
    mount | grep smbfs | tee -a "$OUTPUT_FILE" || echo "  No SMB mounts" | tee -a "$OUTPUT_FILE"
    
    # AFP mounts
    echo "" | tee -a "$OUTPUT_FILE"
    echo "AFP Mounts:" | tee -a "$OUTPUT_FILE"
    mount | grep afpfs | tee -a "$OUTPUT_FILE" || echo "  No AFP mounts" | tee -a "$OUTPUT_FILE"
    
    # ==========================================================================
    # STORAGE PERFORMANCE BASELINE
    # ==========================================================================
    echo "" | tee -a "$OUTPUT_FILE"
    echo "--- STORAGE PERFORMANCE BASELINE ---" | tee -a "$OUTPUT_FILE"
    
    if [[ "$MODE" == "deep" ]] || [[ "$MODE" == "disk" ]]; then
        log_info "Running storage performance baseline tests..."
        
        local test_dir="/tmp/storage_baseline_$$"
        mkdir -p "$test_dir"
        
        # Sequential write test
        echo "" | tee -a "$OUTPUT_FILE"
        echo "Sequential Write Test (1GB):" | tee -a "$OUTPUT_FILE"
        local write_result=$(dd if=/dev/zero of="$test_dir/test_file" bs=1m count=1024 2>&1)
        local write_speed=$(echo "$write_result" | grep -oE '[0-9.]+ [MG]B/s' | tail -1)
        echo "  Write Speed: ${write_speed:-N/A}" | tee -a "$OUTPUT_FILE"
        
        # Sequential read test
        echo "" | tee -a "$OUTPUT_FILE"
        echo "Sequential Read Test (1GB):" | tee -a "$OUTPUT_FILE"
        purge 2>/dev/null || true  # Clear disk cache
        local read_result=$(dd if="$test_dir/test_file" of=/dev/null bs=1m 2>&1)
        local read_speed=$(echo "$read_result" | grep -oE '[0-9.]+ [MG]B/s' | tail -1)
        echo "  Read Speed: ${read_speed:-N/A}" | tee -a "$OUTPUT_FILE"
        
        # Cleanup
        rm -rf "$test_dir"
    else
        echo "  Run with -m deep or -m disk for performance baseline tests" | tee -a "$OUTPUT_FILE"
    fi
    
    log_success "Storage profiling completed"
}

#############################################################################
# Network Forensics
#############################################################################

analyze_network() {
    log_info "Analyzing network performance..."
    
    echo "" | tee -a "$OUTPUT_FILE"
    echo "================================================================================" | tee -a "$OUTPUT_FILE"
    echo "  NETWORK FORENSICS" | tee -a "$OUTPUT_FILE"
    echo "================================================================================" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    # Network interfaces
    echo "Network Interfaces:" | tee -a "$OUTPUT_FILE"
    ifconfig | grep -E "^[a-z]|inet " | tee -a "$OUTPUT_FILE"
    
    # Network statistics
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Network Statistics:" | tee -a "$OUTPUT_FILE"
    { netstat -s | head -50 || true; } | tee -a "$OUTPUT_FILE"
    
    # Active connections
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Active Network Connections (top 20):" | tee -a "$OUTPUT_FILE"
    { netstat -an | head -21 || true; } | tee -a "$OUTPUT_FILE"
    
    # ==========================================================================
    # SAR NETWORK ANALYSIS (macOS)
    # ==========================================================================
    if command -v sar >/dev/null 2>&1; then
        echo "" | tee -a "$OUTPUT_FILE"
        echo "--- SAR NETWORK ANALYSIS ---" | tee -a "$OUTPUT_FILE"
        
        # Network throughput
        echo "" | tee -a "$OUTPUT_FILE"
        echo "Network Throughput (sar -n DEV, 5 samples):" | tee -a "$OUTPUT_FILE"
        sar -n DEV 1 5 2>/dev/null | tee -a "$OUTPUT_FILE" || log_warning "sar -n DEV failed"
        
        # Note about macOS sar limitations
        echo "" | tee -a "$OUTPUT_FILE"
        echo "Note: macOS sar has limited options compared to Linux sysstat." | tee -a "$OUTPUT_FILE"
        echo "For more detailed network analysis, consider: nettop, netstat -s, or tcpdump" | tee -a "$OUTPUT_FILE"
    fi
    
    log_success "Network forensics completed"
}

#############################################################################
# Database Forensics
#############################################################################

analyze_databases() {
    log_info "Checking for running databases..."
    
    echo "" | tee -a "$OUTPUT_FILE"
    echo "================================================================================" | tee -a "$OUTPUT_FILE"
    echo "  DATABASE FORENSICS" | tee -a "$OUTPUT_FILE"
    echo "================================================================================" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    local db_found=false
    
    # MySQL/MariaDB Detection
    if pgrep -x mysqld >/dev/null 2>&1 || pgrep -x mariadbd >/dev/null 2>&1; then
        db_found=true
        echo "=== MySQL/MariaDB Detected ===" | tee -a "$OUTPUT_FILE"
        
        ps aux | grep -E "[m]ysqld|[m]ariadbd" | awk '{printf "  Process: PID %s, CPU: %s%%, MEM: %s%%\n", $2, $3, $4}' | tee -a "$OUTPUT_FILE"
        
        local mysql_conns=$(netstat -an | grep '\.3306' | grep ESTABLISHED | wc -l | tr -d ' ')
        echo "  Active Connections: ${mysql_conns}" | tee -a "$OUTPUT_FILE"
        
        if (( mysql_conns > 500 )); then
            BOTTLENECKS+=("Database: High MySQL connection count (${mysql_conns})")
        fi
        
        if command -v mysql >/dev/null 2>&1; then
            echo "" | tee -a "$OUTPUT_FILE"
            echo "  MySQL Query Analysis:" | tee -a "$OUTPUT_FILE"
            
            mysql -u root -e "SELECT ID, USER, HOST, DB, COMMAND, TIME, STATE, LEFT(INFO, 100) AS QUERY FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND TIME > 30 ORDER BY TIME DESC LIMIT 5;" 2>/dev/null | tee -a "$OUTPUT_FILE" || echo "  Unable to query MySQL (requires authentication)" | tee -a "$OUTPUT_FILE"
            
            mysql -u root -e "SELECT DIGEST_TEXT AS query, COUNT_STAR AS exec_count, ROUND(AVG_TIMER_WAIT/1000000000, 2) AS avg_time_ms, ROUND(SUM_TIMER_WAIT/1000000000, 2) AS total_time_ms FROM performance_schema.events_statements_summary_by_digest ORDER BY SUM_TIMER_WAIT DESC LIMIT 5;" 2>/dev/null | tee -a "$OUTPUT_FILE"
            
            local long_running=$(mysql -u root -N -e "SELECT COUNT(*) FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND TIME > 30;" 2>/dev/null)
            if [[ -n "$long_running" ]] && (( long_running > 0 )); then
                BOTTLENECKS+=("Database: Long-running MySQL queries detected (>30s)")
            fi
        fi
        echo "" | tee -a "$OUTPUT_FILE"
    fi
    
    # PostgreSQL Detection
    if pgrep -x postgres >/dev/null 2>&1 || pgrep -x postmaster >/dev/null 2>&1; then
        db_found=true
        echo "=== PostgreSQL Detected ===" | tee -a "$OUTPUT_FILE"
        
        ps aux | grep -E "[p]ostgres|[p]ostmaster" | head -1 | awk '{printf "  Process: PID %s, CPU: %s%%, MEM: %s%%\n", $2, $3, $4}' | tee -a "$OUTPUT_FILE"
        
        local pg_conns=$(netstat -an | grep '\.5432' | grep ESTABLISHED | wc -l | tr -d ' ')
        echo "  Active Connections: ${pg_conns}" | tee -a "$OUTPUT_FILE"
        
        if (( pg_conns > 500 )); then
            BOTTLENECKS+=("Database: High PostgreSQL connection count (${pg_conns})")
        fi
        
        if command -v psql >/dev/null 2>&1; then
            echo "" | tee -a "$OUTPUT_FILE"
            echo "  PostgreSQL Query Analysis:" | tee -a "$OUTPUT_FILE"
            
            psql -U postgres -c "SELECT pid, usename, application_name, state, EXTRACT(EPOCH FROM (now() - query_start)) AS duration_seconds, LEFT(query, 100) AS query FROM pg_stat_activity WHERE state != 'idle' AND query NOT LIKE '%pg_stat_activity%' ORDER BY duration_seconds DESC LIMIT 5;" 2>/dev/null | tee -a "$OUTPUT_FILE" || echo "  Unable to query PostgreSQL (requires authentication)" | tee -a "$OUTPUT_FILE"
            
            psql -U postgres -c "SELECT query, calls, ROUND(total_exec_time::numeric, 2) AS total_time_ms, ROUND(mean_exec_time::numeric, 2) AS avg_time_ms FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 5;" 2>/dev/null | tee -a "$OUTPUT_FILE"
            
            local long_running=$(psql -U postgres -t -c "SELECT COUNT(*) FROM pg_stat_activity WHERE state != 'idle' AND EXTRACT(EPOCH FROM (now() - query_start)) > 30;" 2>/dev/null | tr -d ' ')
            if [[ -n "$long_running" ]] && (( long_running > 0 )); then
                BOTTLENECKS+=("Database: Long-running PostgreSQL queries detected (>30s)")
            fi
        fi
        echo "" | tee -a "$OUTPUT_FILE"
    fi
    
    # MongoDB Detection
    if pgrep -x mongod >/dev/null 2>&1; then
        db_found=true
        echo "=== MongoDB Detected ===" | tee -a "$OUTPUT_FILE"
        
        ps aux | grep "[m]ongod" | awk '{printf "  Process: PID %s, CPU: %s%%, MEM: %s%%\n", $2, $3, $4}' | tee -a "$OUTPUT_FILE"
        
        local mongo_conns=$(netstat -an | grep '\.27017' | grep ESTABLISHED | wc -l | tr -d ' ')
        echo "  Active Connections: ${mongo_conns}" | tee -a "$OUTPUT_FILE"
        
        if (( mongo_conns > 1000 )); then
            BOTTLENECKS+=("Database: High MongoDB connection count (${mongo_conns})")
        fi
        
        if command -v mongo >/dev/null 2>&1 || command -v mongosh >/dev/null 2>&1; then
            echo "" | tee -a "$OUTPUT_FILE"
            echo "  MongoDB Query Analysis:" | tee -a "$OUTPUT_FILE"
            
            local mongo_cmd="mongo"
            command -v mongosh >/dev/null 2>&1 && mongo_cmd="mongosh"
            
            $mongo_cmd --quiet --eval "db.currentOp({\$or: [{op: {\$in: ['query', 'command']}}, {secs_running: {\$gte: 30}}]}).inprog.forEach(function(op) { print('OpID: ' + op.opid + ' | Duration: ' + op.secs_running + 's | NS: ' + op.ns); });" 2>/dev/null | tee -a "$OUTPUT_FILE" || echo "  Unable to query MongoDB (requires authentication)" | tee -a "$OUTPUT_FILE"
            
            local long_running=$($mongo_cmd --quiet --eval "db.currentOp({secs_running: {\$gte: 30}}).inprog.length" 2>/dev/null)
            if [[ -n "$long_running" ]] && (( long_running > 0 )); then
                BOTTLENECKS+=("Database: Long-running MongoDB operations detected (>30s)")
            fi
        fi
        echo "" | tee -a "$OUTPUT_FILE"
    fi
    
    # Redis Detection
    if pgrep -x redis-server >/dev/null 2>&1; then
        db_found=true
        echo "=== Redis Detected ===" | tee -a "$OUTPUT_FILE"
        
        ps aux | grep "[r]edis-server" | awk '{printf "  Process: PID %s, CPU: %s%%, MEM: %s%%\n", $2, $3, $4}' | tee -a "$OUTPUT_FILE"
        
        local redis_conns=$(netstat -an | grep '\.6379' | grep ESTABLISHED | wc -l | tr -d ' ')
        echo "  Active Connections: ${redis_conns}" | tee -a "$OUTPUT_FILE"
        
        if (( redis_conns > 10000 )); then
            BOTTLENECKS+=("Database: High Redis connection count (${redis_conns})")
        fi
        
        if command -v redis-cli >/dev/null 2>&1; then
            echo "" | tee -a "$OUTPUT_FILE"
            echo "  Redis Performance Metrics:" | tee -a "$OUTPUT_FILE"
            
            local redis_stats=$(redis-cli INFO stats 2>/dev/null)
            local total_commands=$(echo "$redis_stats" | grep "total_commands_processed:" | cut -d: -f2 | tr -d '\r')
            local ops_per_sec=$(echo "$redis_stats" | grep "instantaneous_ops_per_sec:" | cut -d: -f2 | tr -d '\r')
            local rejected_conns=$(echo "$redis_stats" | grep "rejected_connections:" | cut -d: -f2 | tr -d '\r')
            
            echo "  Total Commands: ${total_commands} | Ops/sec: ${ops_per_sec} | Rejected: ${rejected_conns}" | tee -a "$OUTPUT_FILE"
            
            echo "  Top 5 Slow Commands:" | tee -a "$OUTPUT_FILE"
            redis-cli SLOWLOG GET 5 2>/dev/null | tee -a "$OUTPUT_FILE" || echo "  Unable to query Redis slowlog" | tee -a "$OUTPUT_FILE"
            
            if [[ -n "$rejected_conns" ]] && (( rejected_conns > 0 )); then
                BOTTLENECKS+=("Database: Redis connection rejections detected (${rejected_conns})")
            fi
        fi
        echo "" | tee -a "$OUTPUT_FILE"
    fi
    
    # Cassandra Detection
    if pgrep -f "org.apache.cassandra" >/dev/null 2>&1; then
        db_found=true
        echo "=== Cassandra Detected ===" | tee -a "$OUTPUT_FILE"
        
        ps aux | grep "[o]rg.apache.cassandra" | awk '{printf "  Process: PID %s, CPU: %s%%, MEM: %s%%\n", $2, $3, $4}' | tee -a "$OUTPUT_FILE"
        
        local cass_conns=$(netstat -an | grep '\.9042' | grep ESTABLISHED | wc -l | tr -d ' ')
        echo "  Active Connections: ${cass_conns}" | tee -a "$OUTPUT_FILE"
        
        if (( cass_conns > 1000 )); then
            BOTTLENECKS+=("Database: High Cassandra connection count (${cass_conns})")
        fi
        echo "" | tee -a "$OUTPUT_FILE"
    fi
    
    # Oracle Detection
    if pgrep -x oracle >/dev/null 2>&1 || pgrep -f "ora_pmon" >/dev/null 2>&1; then
        db_found=true
        echo "=== Oracle Database Detected ===" | tee -a "$OUTPUT_FILE"
        
        ps aux | grep "[o]ra_pmon" | awk '{printf "  Process: PID %s, CPU: %s%%, MEM: %s%%\n", $2, $3, $4}' | tee -a "$OUTPUT_FILE"
        
        local oracle_conns=$(netstat -an | grep '\.1521' | grep ESTABLISHED | wc -l | tr -d ' ')
        echo "  Active Connections: ${oracle_conns}" | tee -a "$OUTPUT_FILE"
        
        if (( oracle_conns > 500 )); then
            BOTTLENECKS+=("Database: High Oracle connection count (${oracle_conns})")
        fi
        
        if command -v sqlplus >/dev/null 2>&1; then
            echo "" | tee -a "$OUTPUT_FILE"
            echo "  Oracle Query Analysis:" | tee -a "$OUTPUT_FILE"
            
            echo "SELECT sid, serial#, username, status, ROUND(last_call_et/60, 2) AS duration_min, sql_id FROM v\$session WHERE status = 'ACTIVE' AND username IS NOT NULL ORDER BY last_call_et DESC FETCH FIRST 5 ROWS ONLY;" | sqlplus -S / as sysdba 2>/dev/null | tee -a "$OUTPUT_FILE" || echo "  Unable to query Oracle (requires sqlplus and authentication)" | tee -a "$OUTPUT_FILE"
        fi
        echo "" | tee -a "$OUTPUT_FILE"
    fi
    
    # Elasticsearch Detection
    if pgrep -f "org.elasticsearch" >/dev/null 2>&1; then
        db_found=true
        echo "=== Elasticsearch Detected ===" | tee -a "$OUTPUT_FILE"
        
        ps aux | grep "[o]rg.elasticsearch" | awk '{printf "  Process: PID %s, CPU: %s%%, MEM: %s%%\n", $2, $3, $4}' | tee -a "$OUTPUT_FILE"
        
        local es_conns=$(netstat -an | grep '\.9200' | grep ESTABLISHED | wc -l | tr -d ' ')
        echo "  Active Connections: ${es_conns}" | tee -a "$OUTPUT_FILE"
        
        if command -v curl >/dev/null 2>&1; then
            echo "" | tee -a "$OUTPUT_FILE"
            echo "  Elasticsearch Tasks:" | tee -a "$OUTPUT_FILE"
            curl -s "http://localhost:9200/_tasks?detailed=true&actions=*search*" 2>/dev/null | grep -o '"running_time_in_nanos":[0-9]*' | head -5 | tee -a "$OUTPUT_FILE" || echo "  Unable to query Elasticsearch" | tee -a "$OUTPUT_FILE"
        fi
        echo "" | tee -a "$OUTPUT_FILE"
    fi
    
    if [[ "$db_found" == false ]]; then
        echo "No database processes detected" | tee -a "$OUTPUT_FILE"
    fi
    
    log_success "Database forensics completed"
}

#############################################################################
# AWS Support Integration
#############################################################################

create_support_case() {
    if [[ "$CREATE_SUPPORT_CASE" == false ]]; then
        return 0
    fi
    
    if [[ ${#BOTTLENECKS[@]} -eq 0 ]]; then
        log_info "No bottlenecks detected, skipping support case creation"
        return 0
    fi
    
    if ! command -v aws >/dev/null 2>&1; then
        log_error "AWS CLI not available, cannot create support case"
        log_error "Install manually: brew install awscli"
        return 1
    fi
    
    log_info "Creating AWS Support case..."
    
    # Get instance ID if on AWS, otherwise use hostname
    local instance_id=$(curl -s -m 2 http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "")
    local system_identifier
    if [[ -n "$instance_id" ]]; then
        system_identifier="$instance_id"
    else
        system_identifier="$(hostname)"
    fi
    
    local subject="macOS Performance Issues Detected - ${system_identifier}"
    local description="Automated performance forensics detected the following issues:\n\n"
    
    for bottleneck in "${BOTTLENECKS[@]}"; do
        description+="- ${bottleneck}\n"
    done
    
    description+="\n\nDetailed diagnostics attached."
    
    local case_id=$(aws support create-case \
        --subject "$subject" \
        --service-code "general-info" \
        --severity-code "$SEVERITY" \
        --category-code "other" \
        --communication-body "$description" \
        --language "en" \
        --query 'caseId' \
        --output text 2>&1)
    
    if [[ $? -eq 0 ]]; then
        log_success "AWS Support case created: ${case_id}"
        echo "" | tee -a "$OUTPUT_FILE"
        echo "AWS Support case created: ${case_id}" | tee -a "$OUTPUT_FILE"
        
        # Attach diagnostics file
        aws support add-attachments-to-set \
            --attachment-set-id "$(aws support create-attachment-set --attachments fileName=${OUTPUT_FILE},data=$(base64 < ${OUTPUT_FILE}) --query 'attachmentSetId' --output text)" \
            2>&1 | tee -a "$OUTPUT_FILE"
    else
        log_error "Failed to create AWS Support case: ${case_id}"
    fi
}

#############################################################################
# Main Execution
#############################################################################

show_banner() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                               ║"
    echo "║                macOS PERFORMANCE FORENSICS TOOL v1.0                          ║"
    echo "║                                                                               ║"
    echo "║                    Comprehensive System Diagnostics                           ║"
    echo "║                    with AWS Support Integration                               ║"
    echo "║                                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
}

show_help() {
    cat << EOF
macOS Performance Forensic Tool

Usage: sudo ./invoke-macos-forensics.sh [OPTIONS]

Options:
  -m, --mode MODE          Diagnostic mode: quick, standard, deep, disk, cpu, memory
                          (default: standard)
  -s, --support            Create AWS Support case if issues found
  -v, --severity LEVEL     Support case severity: low, normal, high, urgent, critical
                          (default: normal)
  -o, --output PATH        Output directory (default: current directory)
  -h, --help               Show this help message

Modes:
  quick      - Fast assessment (CPU, memory, disk usage only)
  standard   - Comprehensive diagnostics (recommended)
  deep       - Extended diagnostics with I/O testing
  disk       - Disk-only diagnostics
  cpu        - CPU-only diagnostics
  memory     - Memory-only diagnostics

Examples:
  sudo ./invoke-macos-forensics.sh -m quick
  sudo ./invoke-macos-forensics.sh -m deep -s -v high
  sudo ./invoke-macos-forensics.sh -m standard -o /var/log

Requires: sudo privileges
Optional: AWS CLI for support case creation, Homebrew for package management
EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mode)
                MODE="$2"
                shift 2
                ;;
            -s|--support)
                CREATE_SUPPORT_CASE=true
                shift
                ;;
            -v|--severity)
                SEVERITY="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                OUTPUT_FILE="${OUTPUT_DIR}/macos-forensics-${TIMESTAMP}.txt"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_summary() {
    echo "" | tee -a "$OUTPUT_FILE"
    echo "================================================================================" | tee -a "$OUTPUT_FILE"
    echo "  FORENSICS SUMMARY" | tee -a "$OUTPUT_FILE"
    echo "================================================================================" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    log_success "Analysis completed in ${duration} seconds"
    
    if [[ ${#BOTTLENECKS[@]} -eq 0 ]]; then
        echo "" | tee -a "$OUTPUT_FILE"
        log_success "NO BOTTLENECKS FOUND! System performance looks healthy."
    else
        echo "" | tee -a "$OUTPUT_FILE"
        log_error "BOTTLENECKS DETECTED: ${#BOTTLENECKS[@]} performance issue(s) found"
        echo "" | tee -a "$OUTPUT_FILE"
        
        for bottleneck in "${BOTTLENECKS[@]}"; do
            echo "  • ${bottleneck}" | tee -a "$OUTPUT_FILE"
        done
    fi
    
    echo "" | tee -a "$OUTPUT_FILE"
    log_info "Detailed report saved to: ${OUTPUT_FILE}"
    
    if [[ ${#MISSING_PACKAGES[@]} -gt 0 ]]; then
        echo "" | tee -a "$OUTPUT_FILE"
        log_warning "Some utilities were not available:"
        for pkg in "${MISSING_PACKAGES[@]}"; do
            echo "  • ${pkg}" | tee -a "$OUTPUT_FILE"
        done
    fi
}

main() {
    START_TIME=$(date +%s)
    
    show_banner
    parse_arguments "$@"
    
    # Check for sudo
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run with sudo privileges"
        exit 1
    fi
    
    log_info "macOS Version: $(sw_vers -productVersion)"
    log_info "Starting forensics analysis in ${MODE} mode..."
    log_info "Output file: ${OUTPUT_FILE}"
    
    echo "" | tee -a "$OUTPUT_FILE"
    check_required_utilities
    
    gather_system_info
    analyze_glances_overview
    
    case "$MODE" in
        quick)
            analyze_cpu
            analyze_memory
            df -h | tee -a "$OUTPUT_FILE"
            ;;
        standard)
            analyze_cpu
            analyze_memory
            analyze_disk
            analyze_storage_profile
            analyze_network
            analyze_databases
            ;;
        deep)
            analyze_cpu
            analyze_memory
            analyze_disk
            analyze_storage_profile
            analyze_network
            analyze_databases
            ;;
        disk)
            analyze_disk
            analyze_storage_profile
            ;;
        cpu)
            analyze_cpu
            ;;
        memory)
            analyze_memory
            ;;
        *)
            log_error "Invalid mode: ${MODE}"
            show_help
            exit 1
            ;;
    esac
    
    show_summary
    create_support_case
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "                         Forensics Analysis Complete                            "
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
}

# Run main function
main "$@"
