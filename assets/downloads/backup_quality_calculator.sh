#!/bin/bash

# =============================================================================
# Odoo Backup Quality Assessment Script
# Part of "The Definitive Guide to Odoo Database Backup and Restore"
# Created by Aria Shaw - 2025
# =============================================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Script configuration
SCORE=0
MAX_SCORE=120
LOG_FILE="backup_quality_assessment_$(date +%Y%m%d_%H%M%S).log"

# Function to log results
log_result() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to display colored output
print_colored() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to ask questions and update score
ask_question() {
    local question=$1
    local points=$2
    local category=$3

    while true; do
        echo -e "${CYAN}$question${NC}"
        echo -e "${WHITE}(y/n/s for skip):${NC} \c"
        read -r answer

        case $answer in
            [Yy]* )
                ((SCORE+=points))
                log_result "$category: $question - YES (+$points points)"
                break
                ;;
            [Nn]* )
                log_result "$category: $question - NO (0 points)"
                break
                ;;
            [Ss]* )
                log_result "$category: $question - SKIPPED"
                break
                ;;
            * )
                echo -e "${YELLOW}Please answer y (yes), n (no), or s (skip)${NC}"
                ;;
        esac
    done
}

# Function to display progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))

    printf "\r${BLUE}Progress: ["
    printf "%*s" $filled | tr ' ' '='
    printf "%*s" $((width - filled)) | tr ' ' '-'
    printf "] %d%% (%d/%d)${NC}" $percentage $current $total
}

# Function to display category header
category_header() {
    local title=$1
    local max_points=$2
    echo ""
    print_colored "$PURPLE" "=================================================="
    print_colored "$WHITE" "  $title (Maximum: $max_points points)"
    print_colored "$PURPLE" "=================================================="
    echo ""
}

# Function to display final score and recommendations
show_results() {
    clear
    echo ""
    print_colored "$PURPLE" "========================================"
    print_colored "$WHITE" "   ODOO BACKUP QUALITY ASSESSMENT"
    print_colored "$PURPLE" "========================================"
    echo ""
    print_colored "$CYAN" "Assessment Date: $(date '+%Y-%m-%d %H:%M:%S')"
    print_colored "$CYAN" "Assessment Log: $LOG_FILE"
    echo ""

    print_colored "$WHITE" "Your Backup Quality Score: $SCORE / $MAX_SCORE"

    # Calculate percentage
    local percentage=$((SCORE * 100 / MAX_SCORE))

    # Display score bar
    local bar_width=40
    local filled_width=$((SCORE * bar_width / MAX_SCORE))
    printf "${BLUE}Score Bar: ["
    printf "%*s" $filled_width | tr ' ' '█'
    printf "%*s" $((bar_width - filled_width)) | tr ' ' '░'
    printf "] %d%%${NC}\n" $percentage

    echo ""

    # Score interpretation with detailed feedback
    if [ $SCORE -ge 100 ]; then
        print_colored "$GREEN" "🏆 EXCELLENT: Your backup strategy is enterprise-grade!"
        echo ""
        print_colored "$GREEN" "Strengths:"
        print_colored "$WHITE" "• Comprehensive verification procedures in place"
        print_colored "$WHITE" "• Robust monitoring and automation"
        print_colored "$WHITE" "• Regular testing and disaster recovery preparation"
        print_colored "$WHITE" "• Professional-level backup management"
        echo ""
        print_colored "$CYAN" "Recommendations:"
        print_colored "$WHITE" "• Continue current practices and regular reviews"
        print_colored "$WHITE" "• Consider sharing your expertise with the community"
        print_colored "$WHITE" "• Stay updated with latest Odoo backup best practices"

    elif [ $SCORE -ge 80 ]; then
        print_colored "$GREEN" "✅ GOOD: Solid backup practices with room for improvement"
        echo ""
        print_colored "$YELLOW" "Areas for improvement:"
        print_colored "$WHITE" "• Enhance real-time backup monitoring"
        print_colored "$WHITE" "• Implement more comprehensive post-backup verification"
        print_colored "$WHITE" "• Strengthen disaster recovery procedures"
        echo ""
        print_colored "$CYAN" "Next steps:"
        print_colored "$WHITE" "• Focus on automation and alerting improvements"
        print_colored "$WHITE" "• Establish regular test restore schedules"
        print_colored "$WHITE" "• Document and test emergency procedures"

    elif [ $SCORE -ge 60 ]; then
        print_colored "$YELLOW" "⚠️  ADEQUATE: Basic backup coverage, needs strengthening"
        echo ""
        print_colored "$YELLOW" "Critical gaps identified:"
        print_colored "$WHITE" "• Inconsistent verification procedures"
        print_colored "$WHITE" "• Limited monitoring and alerting"
        print_colored "$WHITE" "• Insufficient disaster recovery preparation"
        echo ""
        print_colored "$CYAN" "Priority actions:"
        print_colored "$WHITE" "• Implement systematic post-backup verification"
        print_colored "$WHITE" "• Set up automated backup monitoring"
        print_colored "$WHITE" "• Schedule monthly test restores"
        print_colored "$WHITE" "• Create backup failure alert system"

    elif [ $SCORE -ge 40 ]; then
        print_colored "$RED" "❌ POOR: Significant gaps in backup strategy"
        echo ""
        print_colored "$RED" "Major concerns:"
        print_colored "$WHITE" "• Minimal backup verification"
        print_colored "$WHITE" "• No systematic testing procedures"
        print_colored "$WHITE" "• High risk of backup failures going unnoticed"
        echo ""
        print_colored "$CYAN" "Immediate actions required:"
        print_colored "$WHITE" "• Implement basic verification procedures immediately"
        print_colored "$WHITE" "• Set up fundamental backup monitoring"
        print_colored "$WHITE" "• Test restore capabilities within one week"
        print_colored "$WHITE" "• Create emergency response procedures"

    else
        print_colored "$RED" "🚨 CRITICAL: Backup strategy needs immediate attention!"
        echo ""
        print_colored "$RED" "URGENT - High risk of data loss:"
        print_colored "$WHITE" "• Backup procedures are insufficient"
        print_colored "$WHITE" "• No verification or testing in place"
        print_colored "$WHITE" "• Disaster recovery capabilities unknown"
        echo ""
        print_colored "$CYAN" "Emergency action plan:"
        print_colored "$WHITE" "• Stop all non-essential activities"
        print_colored "$WHITE" "• Implement basic backup verification TODAY"
        print_colored "$WHITE" "• Test restore procedures within 24 hours"
        print_colored "$WHITE" "• Establish emergency backup procedures"
        print_colored "$WHITE" "• Consider professional consultation"
    fi

    echo ""
    print_colored "$PURPLE" "========================================"
    echo ""

    # Detailed category breakdown
    print_colored "$CYAN" "Score Breakdown by Category:"
    echo ""
    print_colored "$WHITE" "• Pre-backup verification:    ${pre_backup_score:-0}/20 points"
    print_colored "$WHITE" "• During backup monitoring:   ${during_backup_score:-0}/15 points"
    print_colored "$WHITE" "• Post-backup verification:   ${post_backup_score:-0}/25 points"
    print_colored "$WHITE" "• Test restore procedures:    ${test_restore_score:-0}/30 points"
    print_colored "$WHITE" "• Automation and monitoring:  ${automation_score:-0}/20 points"
    print_colored "$WHITE" "• Emergency preparedness:     ${emergency_score:-0}/10 points"

    echo ""
    print_colored "$YELLOW" "📊 Assessment saved to: $LOG_FILE"
    print_colored "$CYAN" "💡 Retake this assessment monthly to track improvement!"
    echo ""
}

# Function to save detailed report
save_report() {
    local report_file="backup_quality_report_$(date +%Y%m%d_%H%M%S).txt"

    cat > "$report_file" << EOF
Odoo Backup Quality Assessment Report
====================================
Assessment Date: $(date '+%Y-%m-%d %H:%M:%S')
Assessed by: $(whoami)
Server: $(hostname)

OVERALL SCORE: $SCORE / $MAX_SCORE ($(($SCORE * 100 / $MAX_SCORE))%)

SCORE BREAKDOWN:
• Pre-backup verification:    ${pre_backup_score:-0}/20 points
• During backup monitoring:   ${during_backup_score:-0}/15 points
• Post-backup verification:   ${post_backup_score:-0}/25 points
• Test restore procedures:    ${test_restore_score:-0}/30 points
• Automation and monitoring:  ${automation_score:-0}/20 points
• Emergency preparedness:     ${emergency_score:-0}/10 points

RECOMMENDATIONS:
EOF

    if [ $SCORE -ge 100 ]; then
        echo "- Continue excellent practices" >> "$report_file"
        echo "- Share expertise with community" >> "$report_file"
        echo "- Stay updated with best practices" >> "$report_file"
    elif [ $SCORE -ge 80 ]; then
        echo "- Enhance real-time monitoring" >> "$report_file"
        echo "- Improve post-backup verification" >> "$report_file"
        echo "- Strengthen disaster recovery" >> "$report_file"
    elif [ $SCORE -ge 60 ]; then
        echo "- Implement systematic verification" >> "$report_file"
        echo "- Set up automated monitoring" >> "$report_file"
        echo "- Schedule regular test restores" >> "$report_file"
    elif [ $SCORE -ge 40 ]; then
        echo "- URGENT: Implement basic verification" >> "$report_file"
        echo "- Set up fundamental monitoring" >> "$report_file"
        echo "- Test restore capabilities immediately" >> "$report_file"
    else
        echo "- CRITICAL: Immediate attention required" >> "$report_file"
        echo "- Implement emergency backup procedures" >> "$report_file"
        echo "- Consider professional consultation" >> "$report_file"
    fi

    cat >> "$report_file" << EOF

NEXT ASSESSMENT: $(date -d '+1 month' '+%Y-%m-%d')

For complete backup procedures and best practices, refer to:
"The Definitive Guide to Odoo Database Backup and Restore" by Aria Shaw
https://ariashaw.com

Assessment Log: $LOG_FILE
Report File: $report_file
EOF

    print_colored "$GREEN" "📋 Detailed report saved to: $report_file"
}

# Main assessment function
run_assessment() {
    clear
    print_colored "$PURPLE" "========================================"
    print_colored "$WHITE" "   ODOO BACKUP QUALITY ASSESSMENT"
    print_colored "$PURPLE" "========================================"
    echo ""
    print_colored "$CYAN" "This assessment will evaluate your Odoo backup strategy"
    print_colored "$CYAN" "across 6 critical categories to ensure your backups"
    print_colored "$CYAN" "will actually work when you need them most."
    echo ""
    print_colored "$YELLOW" "⏱️  Estimated time: 5-10 minutes"
    print_colored "$YELLOW" "📝 Responses will be logged for tracking improvement"
    echo ""
    print_colored "$WHITE" "Press Enter to begin..."
    read -r

    # Category 1: Pre-backup verification (20 points)
    category_header "Pre-backup Verification" "20"
    local category_start=$SCORE

    ask_question "Do you check available disk space before each backup?" 5 "Pre-backup"
    ask_question "Do you verify PostgreSQL is responding before backup?" 5 "Pre-backup"
    ask_question "Do you check Odoo process stability before backup?" 5 "Pre-backup"
    ask_question "Do you verify filestore accessibility before backup?" 5 "Pre-backup"

    pre_backup_score=$((SCORE - category_start))
    show_progress 1 6

    # Category 2: During backup monitoring (15 points)
    category_header "During Backup Monitoring" "15"
    category_start=$SCORE

    ask_question "Do you monitor backup process resource usage in real-time?" 8 "During backup"
    ask_question "Do you watch for errors and warnings during backup?" 7 "During backup"

    during_backup_score=$((SCORE - category_start))
    show_progress 2 6

    # Category 3: Post-backup verification (25 points)
    category_header "Post-backup Verification" "25"
    category_start=$SCORE

    ask_question "Do you verify backup file integrity after completion?" 8 "Post-backup"
    ask_question "Do you validate backup content and manifest files?" 8 "Post-backup"
    ask_question "Do you check backup file size and format?" 9 "Post-backup"

    post_backup_score=$((SCORE - category_start))
    show_progress 3 6

    # Category 4: Test restore procedures (30 points)
    category_header "Test Restore Procedures" "30"
    category_start=$SCORE

    ask_question "Do you perform monthly test restores?" 15 "Test restore"
    ask_question "Do you test application functionality after restore?" 15 "Test restore"

    test_restore_score=$((SCORE - category_start))
    show_progress 4 6

    # Category 5: Automation and monitoring (20 points)
    category_header "Automation and Monitoring" "20"
    category_start=$SCORE

    ask_question "Do you have automated backup processes working reliably?" 10 "Automation"
    ask_question "Do you have monitoring and alerting for backup failures?" 10 "Automation"

    automation_score=$((SCORE - category_start))
    show_progress 5 6

    # Category 6: Emergency preparedness (10 points)
    category_header "Emergency Preparedness" "10"
    category_start=$SCORE

    ask_question "Do you regularly test disaster recovery procedures?" 10 "Emergency prep"

    emergency_score=$((SCORE - category_start))
    show_progress 6 6

    echo ""
    print_colored "$GREEN" "Assessment complete! Calculating results..."
    sleep 2
}

# Function to display help
show_help() {
    echo ""
    print_colored "$CYAN" "Odoo Backup Quality Assessment Script"
    print_colored "$WHITE" "======================================"
    echo ""
    print_colored "$WHITE" "This script evaluates your Odoo backup strategy across 6 categories:"
    print_colored "$YELLOW" "• Pre-backup verification (20 points)"
    print_colored "$YELLOW" "• During backup monitoring (15 points)"
    print_colored "$YELLOW" "• Post-backup verification (25 points)"
    print_colored "$YELLOW" "• Test restore procedures (30 points)"
    print_colored "$YELLOW" "• Automation and monitoring (20 points)"
    print_colored "$YELLOW" "• Emergency preparedness (10 points)"
    echo ""
    print_colored "$WHITE" "Usage:"
    print_colored "$CYAN" "  $0                 Run the assessment"
    print_colored "$CYAN" "  $0 --help         Show this help message"
    print_colored "$CYAN" "  $0 --version      Show version information"
    echo ""
    print_colored "$WHITE" "Output Files:"
    print_colored "$YELLOW" "• Assessment log: backup_quality_assessment_YYYYMMDD_HHMMSS.log"
    print_colored "$YELLOW" "• Detailed report: backup_quality_report_YYYYMMDD_HHMMSS.txt"
    echo ""
    print_colored "$GREEN" "💡 Tip: Run this assessment monthly to track improvement!"
    echo ""
}

# Function to show version
show_version() {
    echo ""
    print_colored "$CYAN" "Odoo Backup Quality Assessment Script"
    print_colored "$WHITE" "Version 1.0.0 - January 2025"
    print_colored "$WHITE" "Part of 'The Definitive Guide to Odoo Database Backup and Restore'"
    print_colored "$WHITE" "Created by Aria Shaw"
    print_colored "$YELLOW" "https://ariashaw.com"
    echo ""
}

# Main script logic
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --version|-v)
        show_version
        exit 0
        ;;
    "")
        # Run the assessment
        run_assessment
        show_results

        echo ""
        print_colored "$CYAN" "Would you like to save a detailed report? (y/n): \c"
        read -r save_response
        if [[ $save_response =~ ^[Yy] ]]; then
            save_report
        fi

        echo ""
        print_colored "$GREEN" "Thank you for using the Backup Quality Assessment!"
        print_colored "$CYAN" "Remember to reassess monthly and keep improving your backup strategy."
        echo ""
        ;;
    *)
        print_colored "$RED" "Unknown option: $1"
        print_colored "$WHITE" "Use --help for usage information"
        exit 1
        ;;
esac

# Log completion
log_result "Assessment completed with score: $SCORE/$MAX_SCORE"