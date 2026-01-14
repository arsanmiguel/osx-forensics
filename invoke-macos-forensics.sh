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
    ps aux | sort -rk 3 | head -11 | tee -a "$OUTPUT_FILE"
    
    # Check for high CPU usage
    local cpu_idle=$(top -l 1 -n 0 | grep "CPU usage" | awk '{print $7}' | sed 's/%//')
    local cpu_used=$(echo "100 - $cpu_idle" | bc)
    
    if (( $(echo "$cpu_used > 80" | bc -l) )); then
        BOTTLENECKS+=("CPU: High CPU utilization (${cpu_used}%)")
    fi
    
    if (( $(echo "$load_per_core > 2.0" | bc -l) )); then
        BOTTLENECKS+=("CPU: High load per core (${load_per_core})")
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
    ps aux | sort -rk 4 | head -11 | tee -a "$OUTPUT_FILE"
    
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
    echo "Disk I/O Statistics:" | tee -a "$OUTPUT_FILE"
    iostat -d -c 5 | tee -a "$OUTPUT_FILE"
    
    # Check for high disk usage
    local disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    if (( disk_usage > 90 )); then
        BOTTLENECKS+=("Disk: High disk usage on root volume (${disk_usage}%)")
    fi
    
    log_success "Disk forensics completed"
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
    netstat -s | head -50 | tee -a "$OUTPUT_FILE"
    
    # Active connections
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Active Network Connections (top 20):" | tee -a "$OUTPUT_FILE"
    netstat -an | head -21 | tee -a "$OUTPUT_FILE"
    
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
    
    local subject="macOS Performance Issues Detected - $(hostname)"
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
            analyze_network
            analyze_databases
            ;;
        deep)
            analyze_cpu
            analyze_memory
            analyze_disk
            analyze_network
            analyze_databases
            ;;
        disk)
            analyze_disk
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
