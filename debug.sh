#!/bin/bash

# Debug Script - Shows exactly what responses look like
# Use this to troubleshoot header and response parsing issues

echo "================================================"
echo "Debug: Response Analysis"
echo "================================================"
echo ""

echo "1. Testing Nginx (port 8080) - Full Response:"
echo "------------------------------------------------"
curl -i http://localhost:8080/version
echo ""
echo ""

echo "2. Testing Blue directly (port 8081) - Full Response:"
echo "------------------------------------------------"
curl -i http://localhost:8081/version
echo ""
echo ""

echo "3. Testing Green directly (port 8082) - Full Response:"
echo "------------------------------------------------"
curl -i http://localhost:8082/version
echo ""
echo ""

echo "4. Extracting Headers from Nginx Response:"
echo "------------------------------------------------"
response=$(curl -s -i http://localhost:8080/version)
echo "Full response:"
echo "$response"
echo ""
echo "Status Code:"
echo "$response" | grep -E "^HTTP" | awk '{print $2}'
echo ""
echo "X-App-Pool Header:"
echo "$response" | grep -i "^X-App-Pool:" | awk '{print $2}' | tr -d '\r'
echo ""
echo "X-Release-Id Header:"
echo "$response" | grep -i "^X-Release-Id:" | awk '{print $2}' | tr -d '\r'
echo ""
echo ""

echo "5. Testing pool detection logic:"
echo "------------------------------------------------"
pool=$(echo "$response" | grep -i "^X-App-Pool:" | awk '{print $2}' | tr -d '\r\n ')
echo "Detected pool: [$pool]"
if [ "$pool" = "blue" ]; then
    echo "✓ Detected as BLUE"
elif [ "$pool" = "green" ]; then
    echo "✓ Detected as GREEN"
else
    echo "✗ Unable to detect pool (got: '$pool')"
fi
echo ""

echo "================================================"
echo "Debug complete"
echo "================================================"
