#!/bin/bash

# Test Script for AI Gateway
# This script tests all endpoints of the AI Gateway

set -e

# Configuration
GATEWAY_URL=${GATEWAY_URL:-"http://localhost"}
API_KEY=${API_KEY:-"your-api-key-here"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Test health endpoint
test_health() {
    print_test "Testing health endpoint..."
    
    response=$(curl -s -w "%{http_code}" -o /tmp/health_response.json "$GATEWAY_URL/health")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        print_success "Health check passed"
        cat /tmp/health_response.json | jq '.'
    else
        print_error "Health check failed with status: $http_code"
        cat /tmp/health_response.json
        return 1
    fi
}

# Test readiness endpoint
test_readiness() {
    print_test "Testing readiness endpoint..."
    
    response=$(curl -s -w "%{http_code}" -o /tmp/ready_response.json "$GATEWAY_URL/ready")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        print_success "Readiness check passed"
        cat /tmp/ready_response.json | jq '.'
    else
        print_error "Readiness check failed with status: $http_code"
        cat /tmp/ready_response.json
        return 1
    fi
}

# Test models endpoint
test_models() {
    print_test "Testing models endpoint..."
    
    response=$(curl -s -w "%{http_code}" -o /tmp/models_response.json \
        -H "Authorization: Bearer $API_KEY" \
        "$GATEWAY_URL/api/v1/models")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        print_success "Models endpoint working"
        echo "Available models:"
        cat /tmp/models_response.json | jq '.data[].id'
    else
        print_error "Models endpoint failed with status: $http_code"
        cat /tmp/models_response.json
        return 1
    fi
}

# Test chat endpoint with different models
test_chat() {
    local model=$1
    local message=$2
    
    print_test "Testing chat with model: $model"
    
    payload=$(cat <<EOF
{
    "message": "$message",
    "model": "$model",
    "temperature": 0.7,
    "max_tokens": 100
}
EOF
)
    
    response=$(curl -s -w "%{http_code}" -o /tmp/chat_response.json \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        -d "$payload" \
        "$GATEWAY_URL/api/v1/chat")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        print_success "Chat request successful with $model"
        echo "Response:"
        cat /tmp/chat_response.json | jq '.response'
        echo "Processing time: $(cat /tmp/chat_response.json | jq '.processing_time')s"
        echo "Tokens used: $(cat /tmp/chat_response.json | jq '.tokens_used')"
    else
        print_error "Chat request failed with status: $http_code"
        cat /tmp/chat_response.json
        return 1
    fi
}

# Test rate limiting
test_rate_limiting() {
    print_test "Testing rate limiting..."
    
    local success_count=0
    local rate_limited_count=0
    
    for i in {1..10}; do
        response=$(curl -s -w "%{http_code}" -o /dev/null \
            -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $API_KEY" \
            -d '{"message": "Test rate limiting", "model": "gemini-pro"}' \
            "$GATEWAY_URL/api/v1/chat")
        
        if [ "$response" = "200" ]; then
            ((success_count++))
        elif [ "$response" = "429" ]; then
            ((rate_limited_count++))
        fi
        
        sleep 0.1
    done
    
    print_success "Rate limiting test completed"
    echo "Successful requests: $success_count"
    echo "Rate limited requests: $rate_limited_count"
}

# Test authentication
test_authentication() {
    print_test "Testing authentication..."
    
    # Test without API key
    response=$(curl -s -w "%{http_code}" -o /tmp/auth_response.json \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"message": "Test auth", "model": "gemini-pro"}' \
        "$GATEWAY_URL/api/v1/chat")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "401" ] || [ "$http_code" = "403" ]; then
        print_success "Authentication properly enforced"
    else
        print_warning "Authentication might not be properly configured (status: $http_code)"
    fi
    
    # Test with invalid API key
    response=$(curl -s -w "%{http_code}" -o /tmp/auth_response.json \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer invalid-key" \
        -d '{"message": "Test auth", "model": "gemini-pro"}' \
        "$GATEWAY_URL/api/v1/chat")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "401" ] || [ "$http_code" = "403" ]; then
        print_success "Invalid API key properly rejected"
    else
        print_warning "Invalid API key handling might need attention (status: $http_code)"
    fi
}

# Test error handling
test_error_handling() {
    print_test "Testing error handling..."
    
    # Test with invalid model
    response=$(curl -s -w "%{http_code}" -o /tmp/error_response.json \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        -d '{"message": "Test error", "model": "invalid-model"}' \
        "$GATEWAY_URL/api/v1/chat")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
        print_success "Invalid model properly handled"
        cat /tmp/error_response.json | jq '.'
    else
        print_warning "Error handling for invalid model might need attention (status: $http_code)"
    fi
    
    # Test with malformed JSON
    response=$(curl -s -w "%{http_code}" -o /tmp/error_response.json \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        -d '{"message": "Test error", "model":}' \
        "$GATEWAY_URL/api/v1/chat")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "400" ]; then
        print_success "Malformed JSON properly handled"
    else
        print_warning "Malformed JSON handling might need attention (status: $http_code)"
    fi
}

# Test metrics endpoint
test_metrics() {
    print_test "Testing metrics endpoint..."
    
    response=$(curl -s -w "%{http_code}" -o /tmp/metrics_response.txt "$GATEWAY_URL/metrics")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        print_success "Metrics endpoint working"
        echo "Sample metrics:"
        head -20 /tmp/metrics_response.txt
    else
        print_error "Metrics endpoint failed with status: $http_code"
        return 1
    fi
}

# Performance test
performance_test() {
    print_test "Running performance test..."
    
    local concurrent_requests=5
    local total_requests=20
    
    echo "Running $total_requests requests with $concurrent_requests concurrent connections..."
    
    # Create test payload
    cat > /tmp/perf_payload.json <<EOF
{
    "message": "This is a performance test message. Please respond with a brief acknowledgment.",
    "model": "gemini-pro",
    "temperature": 0.5,
    "max_tokens": 50
}
EOF
    
    # Run performance test
    start_time=$(date +%s)
    
    for i in $(seq 1 $total_requests); do
        (
            curl -s -w "%{http_code},%{time_total}\n" -o /dev/null \
                -X POST \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $API_KEY" \
                -d @/tmp/perf_payload.json \
                "$GATEWAY_URL/api/v1/chat" >> /tmp/perf_results.txt
        ) &
        
        # Limit concurrent requests
        if (( i % concurrent_requests == 0 )); then
            wait
        fi
    done
    wait
    
    end_time=$(date +%s)
    total_time=$((end_time - start_time))
    
    # Analyze results
    success_count=$(grep "^200," /tmp/perf_results.txt | wc -l)
    avg_response_time=$(grep "^200," /tmp/perf_results.txt | cut -d',' -f2 | awk '{sum+=$1} END {print sum/NR}')
    
    print_success "Performance test completed"
    echo "Total time: ${total_time}s"
    echo "Successful requests: $success_count/$total_requests"
    echo "Average response time: ${avg_response_time}s"
    echo "Requests per second: $(echo "scale=2; $success_count / $total_time" | bc)"
}

# Main test runner
main() {
    echo "Starting AI Gateway Test Suite"
    echo "Gateway URL: $GATEWAY_URL"
    echo "================================"
    
    # Check if required tools are available
    for tool in curl jq bc; do
        if ! command -v $tool &> /dev/null; then
            print_error "$tool is required but not installed"
            exit 1
        fi
    done
    
    # Run tests
    test_health || exit 1
    echo
    
    test_readiness || exit 1
    echo
    
    test_models || exit 1
    echo
    
    test_chat "gemini-pro" "Hello, how are you?" || exit 1
    echo
    
    test_chat "text-bison" "What is artificial intelligence?" || exit 1
    echo
    
    test_authentication
    echo
    
    test_error_handling
    echo
    
    test_rate_limiting
    echo
    
    test_metrics || exit 1
    echo
    
    performance_test
    echo
    
    print_success "All tests completed successfully!"
    
    # Cleanup
    rm -f /tmp/*_response.* /tmp/perf_*.* 2>/dev/null || true
}

# Run main function
main "$@"
