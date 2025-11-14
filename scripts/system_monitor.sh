#!/bin/bash

##############################################################################
# Author: Corbescu Alexandru-Robert
# Date Created: 2025-11-13
# Last Modified: 2025-11-14

# Description
# Continuously monitor system resources (CPU, RAM, Disk) and check 
# Pi-hole container status. Logs output to STDOUT for Docker log capture.
##############################################################################

# Configuration
SLEEP_INTERVAL=30  # Seconds between monitoring cycles
PIHOLE_CONTAINER="pihole"  # Name of Pi-hole container to check

# Colors for output (will work in terminal, ignored by Docker logs)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print a separator line
print_separator() {
    echo "========================================================================"
}

# Function to print section header
print_header() {
    echo -e "${BLUE}### $1 ###${NC}"
}

# Function to get CPU usage percentage
print_cpu_usage() {
    # Calculate CPU usage (100 - idle)
    cpu_usage=$(echo "100 - $(mpstat | awk 'END {print $12}' | tr ',' '.')" | bc)
    echo -e "CPU Usage:\n   ${cpu_usage}%"
}

# Function to get memory information
print_memory_info() {
    # Get memory usage percentage

    # Parse /proc/meminfo for accurate memory stats
    mem_total=$(cat /proc/meminfo | grep "MemTotal" | awk '{print $2}')
    mem_available=$(cat /proc/meminfo | grep "MemAvailable" | awk '{print $2}')

    # Convert to MB
    mem_total_mb=$(echo "scale=3; $mem_total / 1024" | bc -l)
    mem_available_mb=$(echo "scale=3; $mem_available / 1024" | bc -l)   
    mem_used_mb=$(echo "scale=3; $mem_total_mb - $mem_available_mb" | bc -l)

    # Calculate percentage
    mem_usage_percent=$(echo "scale=3; ($mem_used_mb / $mem_total_mb) * 100" | bc -l)

    echo -e "Memory Summary:\n   Total:     ${mem_total_mb} MB\n   Used:      ${mem_used_mb} MB\n   Available: ${mem_available_mb} MB\n   Usage:     ${mem_usage_percent}%"
}

# Function to get disk information
print_disk_info() {
    # Get root filesystem stats
    disk_info=$(df -h / | tail -1)
    disk_total=$(echo "$disk_info" | awk '{print $2}')
    disk_used=$(echo "$disk_info" | awk '{print $3}')
    disk_available=$(echo "$disk_info" | awk '{print $4}')
    disk_usage_percent=$(echo "$disk_info" | awk '{print $5}')

    echo -e "\n    Disk Summary (Root Filesystem):\n        Total:     ${disk_total}\n        Used:      ${disk_used}\n        Available: ${disk_available}\n        Usage:     ${disk_usage_percent}"
}

# Function to get OS information
print_os_info() {

    os_info=$(hostnamectl)
    echo "$os_info" | grep "Operating System"
    echo "$os_info" | grep "Kernel"
    echo "$os_info" | grep "Architecture"
}

main() {
    echo -e "${GREEN}🚀 System Monitor Started${NC}"
    echo "Monitoring interval: ${SLEEP_INTERVAL} seconds"
    echo "Target Pi-hole container: ${PIHOLE_CONTAINER}"
    print_separator
    echo ""

    # Infinite loop
    while true; do
        # Current timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')

        print_separator
        echo -e "${YELLOW}⏰ Timestamp: ${timestamp}${NC}"
        print_separator

        # OS Information
        print_header "Operating System"
        print_os_info

        # CPU Usage
        print_header "CPU Usage"
        print_cpu_usage

        # CPU Usage
        print_header "Memory Usage"
        print_memory_info


        print_separator
        echo -e "${BLUE}💤 Sleeping for ${SLEEP_INTERVAL} seconds...${NC}"
        print_separator
        echo ""
        
        # Sleep before next iteration
        sleep "$SLEEP_INTERVAL"
    done
}

# Trap SIGTERM and SIGINT for graceful shutdown
trap 'echo -e "\n${RED}🛑 System Monitor Stopped${NC}"; exit 0' SIGTERM SIGINT

# Start monitoring
main
