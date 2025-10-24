#!/bin/bash

# Reset Script - Stops chaos mode on both Blue and Green services
# Use this before running tests or to restore normal operation

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

echo ""
echo "================================================"
echo "Reset Chaos Mode"
echo "================================================"
echo ""

print_info "Stopping chaos mode on Blue (port 8081)..."
blue_response=$(curl -s -X POST "http://localhost:8081/chaos/stop" 2>/dev/null || echo '{"error":"Failed"}')
echo "Response: $blue_response"

print_info "Stopping chaos mode on Green (port 8082)..."
green_response=$(curl -s -X POST "http://localhost:8082/chaos/stop" 2>/dev/null || echo '{"error":"Failed"}')
echo "Response: $green_response"

echo ""
print_info "Waiting 3 seconds for services to recover..."
sleep 3

echo ""
print_info "Verifying Blue status..."
blue_status=$(curl -s -w "\n%{http_code}" "http://localhost:8081/version" 2>/dev/null)
blue_code=$(echo "$blue_status" | tail -n 1)

if [ "$blue_code" = "200" ]; then
    print_success "Blue is responding normally (HTTP $blue_code)"
else
    print_error "Blue is still failing (HTTP $blue_code)"
fi

print_info "Verifying Green status..."
green_status=$(curl -s -w "\n%{http_code}" "http://localhost:8082/version" 2>/dev/null)
green_code=$(echo "$green_status" | tail -n 1)

if [ "$green_code" = "200" ]; then
    print_success "Green is responding normally (HTTP $green_code)"
else
    print_error "Green is still failing (HTTP $green_code)"
fi

echo ""
print_info "Testing through Nginx (should route to Blue)..."
nginx_response=$(curl -s "http://localhost:8080/version" | jq -r '.pool // "unknown"' 2>/dev/null)

echo ""
if [ "$nginx_response" = "blue" ]; then
    print_success "✓✓✓ Reset complete! Nginx is routing to Blue ✓✓✓"
elif [ "$nginx_response" = "green" ]; then
    print_info "Nginx is still routing to Green (Blue may still be in fail_timeout)"
    print_info "Wait 5-10 seconds and Nginx will automatically switch back to Blue"
else
    print_error "Unable to determine current routing"
fi

echo ""
echo "================================================"
echo ""
