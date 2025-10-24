#!/bin/bash

# Blue/Green Failover Test Script
# This script tests the failover mechanism and verifies zero-downtime

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_REQUESTS=0
SUCCESSFUL_REQUESTS=0
FAILED_REQUESTS=0
BLUE_RESPONSES=0
GREEN_RESPONSES=0
ERROR_RESPONSES=0

print_header() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Function to check if services are running
check_services() {
    print_info "Checking if services are running..."
    
    if ! docker compose ps | grep -q "nginx"; then
        print_error "Nginx service is not running!"
        exit 1
    fi
    
    if ! docker compose ps | grep -q "app_blue"; then
        print_error "Blue service is not running!"
        exit 1
    fi
    
    if ! docker compose ps | grep -q "app_green"; then
        print_error "Green service is not running!"
        exit 1
    fi
    
    print_success "All services are running"
}

# Function to test endpoint
test_endpoint() {
    local url=$1
    local expected_pool=$2
    
    # Get full response with headers
    full_response=$(curl -s -i "$url" 2>/dev/null)
    
    # Extract status code
    status=$(echo "$full_response" | grep -E "^HTTP" | awk '{print $2}')
    
    # Extract X-App-Pool header
    pool=$(echo "$full_response" | grep -i "^X-App-Pool:" | awk '{print $2}' | tr -d '\r\n ')
    
    TOTAL_REQUESTS=$((TOTAL_REQUESTS + 1))
    
    if [ "$status" = "200" ]; then
        SUCCESSFUL_REQUESTS=$((SUCCESSFUL_REQUESTS + 1))
        
        # Count pool responses based on header
        if [ "$pool" = "blue" ]; then
            BLUE_RESPONSES=$((BLUE_RESPONSES + 1))
        elif [ "$pool" = "green" ]; then
            GREEN_RESPONSES=$((GREEN_RESPONSES + 1))
        fi
        
        echo -n "."
    else
        FAILED_REQUESTS=$((FAILED_REQUESTS + 1))
        ERROR_RESPONSES=$((ERROR_RESPONSES + 1))
        echo -n "X"
    fi
}

# Function to get detailed response
get_detailed_response() {
    local url=$1
    
    echo ""
    print_info "Testing: $url"
    
    response=$(curl -i -s "$url" 2>/dev/null)
    
    # Extract status code
    status=$(echo "$response" | grep HTTP | awk '{print $2}')
    
    # Extract headers
    app_pool=$(echo "$response" | grep -i "X-App-Pool:" | awk '{print $2}' | tr -d '\r')
    release_id=$(echo "$response" | grep -i "X-Release-Id:" | awk '{print $2}' | tr -d '\r')
    
    # Extract body
    body=$(echo "$response" | sed '1,/^\r$/d')
    
    echo ""
    echo "Status Code: $status"
    echo "X-App-Pool: $app_pool"
    echo "X-Release-Id: $release_id"
    echo "Body: $body"
    echo ""
    
    if [ "$status" = "200" ]; then
        print_success "Response OK"
        return 0
    else
        print_error "Response FAILED"
        return 1
    fi
}

# Function to display statistics
display_stats() {
    echo ""
    echo "================================================"
    echo "Test Statistics"
    echo "================================================"
    echo "Total Requests:      $TOTAL_REQUESTS"
    echo "Successful (200):    $SUCCESSFUL_REQUESTS ($(awk "BEGIN {printf \"%.1f\", ($SUCCESSFUL_REQUESTS/$TOTAL_REQUESTS)*100}")%)"
    echo "Failed (non-200):    $FAILED_REQUESTS ($(awk "BEGIN {printf \"%.1f\", ($FAILED_REQUESTS/$TOTAL_REQUESTS)*100}")%)"
    echo ""
    echo "Blue Responses:      $BLUE_RESPONSES ($(awk "BEGIN {printf \"%.1f\", ($BLUE_RESPONSES/$TOTAL_REQUESTS)*100}")%)"
    echo "Green Responses:     $GREEN_RESPONSES ($(awk "BEGIN {printf \"%.1f\", ($GREEN_RESPONSES/$TOTAL_REQUESTS)*100}")%)"
    echo "Error Responses:     $ERROR_RESPONSES"
    echo "================================================"
    echo ""
}

# Function to reset chaos mode
reset_chaos() {
    print_info "Resetting chaos mode on both services..."
    
    # Stop chaos on Blue
    curl -s -X POST "http://localhost:8081/chaos/stop" > /dev/null 2>&1 || true
    
    # Stop chaos on Green
    curl -s -X POST "http://localhost:8082/chaos/stop" > /dev/null 2>&1 || true
    
    # Wait for services to recover
    sleep 3
    
    print_success "Chaos mode reset"
}

# Main test sequence
main() {
    print_header "Blue/Green Failover Test"
    
    # Check if services are running
    check_services
    
    # Reset any existing chaos mode
    reset_chaos
    
    # Phase 1: Test normal operation (Blue should be active)
    print_header "Phase 1: Normal Operation (Blue Active)"
    
    print_info "Testing /version endpoint through Nginx..."
    get_detailed_response "http://localhost:8080/version"
    
    print_info "Testing direct Blue access..."
    get_detailed_response "http://localhost:8081/version"
    
    print_info "Testing direct Green access..."
    get_detailed_response "http://localhost:8082/version"
    
    print_info "Running 10 consecutive requests..."
    for i in {1..10}; do
        test_endpoint "http://localhost:8080/version" "blue"
    done
    echo ""
    
    if [ $BLUE_RESPONSES -eq 10 ] && [ $FAILED_REQUESTS -eq 0 ]; then
        print_success "Phase 1 PASSED: All requests went to Blue with 100% success rate"
    else
        print_error "Phase 1 FAILED: Expected 10 Blue responses, got $BLUE_RESPONSES (Failures: $FAILED_REQUESTS)"
    fi
    
    # Phase 2: Trigger chaos and test failover
    print_header "Phase 2: Failover Test (Triggering Chaos on Blue)"
    
    print_info "Triggering chaos mode on Blue (port 8081)..."
    chaos_response=$(curl -s -X POST "http://localhost:8081/chaos/start?mode=error")
    echo "Chaos response: $chaos_response"
    print_success "Chaos mode activated on Blue"
    
    sleep 2
    
    print_info "Testing immediate failover to Green..."
    get_detailed_response "http://localhost:8080/version"
    
    # Phase 3: Continuous testing during failure
    print_header "Phase 3: Sustained Load Test (Blue Failed, Green Active)"
    
    print_info "Running 50 requests over 10 seconds..."
    print_info "Each dot (.) = 200 OK, Each X = Failed request"
    echo ""
    
    # Reset counters for this phase
    PHASE3_START_TOTAL=$TOTAL_REQUESTS
    PHASE3_START_GREEN=$GREEN_RESPONSES
    PHASE3_START_FAILED=$FAILED_REQUESTS
    
    for i in {1..50}; do
        test_endpoint "http://localhost:8080/version" "green"
        sleep 0.2
    done
    echo ""
    echo ""
    
    # Calculate Phase 3 statistics
    PHASE3_TOTAL=$((TOTAL_REQUESTS - PHASE3_START_TOTAL))
    PHASE3_GREEN=$((GREEN_RESPONSES - PHASE3_START_GREEN))
    PHASE3_FAILED=$((FAILED_REQUESTS - PHASE3_START_FAILED))
    PHASE3_GREEN_PERCENT=$(awk "BEGIN {printf \"%.1f\", ($PHASE3_GREEN/$PHASE3_TOTAL)*100}")
    
    echo ""
    print_info "Phase 3 Results:"
    echo "  Total Requests: $PHASE3_TOTAL"
    echo "  Green Responses: $PHASE3_GREEN ($PHASE3_GREEN_PERCENT%)"
    echo "  Failed Requests: $PHASE3_FAILED"
    echo ""
    
    if [ $PHASE3_FAILED -eq 0 ] && [ $(echo "$PHASE3_GREEN_PERCENT >= 95" | bc) -eq 1 ]; then
        print_success "Phase 3 PASSED: Zero failures with $PHASE3_GREEN_PERCENT% Green responses"
    else
        print_error "Phase 3 FAILED: Had $PHASE3_FAILED failures and only $PHASE3_GREEN_PERCENT% Green responses (need ≥95%)"
    fi
    
    # Phase 4: Stop chaos and verify recovery
    print_header "Phase 4: Recovery Test (Stopping Chaos)"
    
    print_info "Stopping chaos mode on Blue..."
    recovery_response=$(curl -s -X POST "http://localhost:8081/chaos/stop")
    echo "Recovery response: $recovery_response"
    print_success "Chaos mode stopped"
    
    sleep 5
    
    print_info "Testing Blue recovery..."
    get_detailed_response "http://localhost:8081/version"
    
    print_info "Note: Nginx will keep using Green until Blue's fail_timeout (5s) expires"
    
    # Final statistics
    print_header "Final Test Results"
    display_stats
    
    # Overall pass/fail
    echo ""
    if [ $FAILED_REQUESTS -eq 0 ]; then
        print_success "✓✓✓ ALL TESTS PASSED ✓✓✓"
        print_success "Zero-downtime failover working correctly!"
        exit 0
    else
        print_error "✗✗✗ TESTS FAILED ✗✗✗"
        print_error "Had $FAILED_REQUESTS failed requests (requirement: 0 failures)"
        exit 1
    fi
}

# Run main test
main
