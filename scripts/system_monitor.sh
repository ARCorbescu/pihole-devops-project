#!/bin/bash

##############################################################################
# System Monitor Script - Bash Version
# 
# Purpose: Continuously monitor system resources (CPU, RAM, Disk) and 
#          check Pi-hole container status. Logs output to STDOUT for 
#          Docker log capture.
#
# Author: [Your Name]
# Date: $(date +%Y-%m-%d)
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
get_cpu_usage() {
    # Calculate CPU usage (100 - idle)
    cpu_usage=$(echo "100 - $(mpstat | awk 'END {print $12}' | tr ',' '.')" | bc)
    echo "$cpu_usage"
}

cpu_usage=$(get_cpu_usage)
echo "CPU Usage: ${cpu_usage}%"