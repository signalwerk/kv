#!/bin/bash

# Shared utilities for all tests

# Load the .env file
basePath="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"
source "$basePath/.env"

# Configuration
USERNAME="signalwerk"
PASSWORD="$DB_USER_PASSWORD"
DOMAIN="testproject"
BASE_URL="http://localhost:3000"
TOKEN_STORE="token.txt"

# Generate unique names for test runs to avoid conflicts
TEST_RUN_ID=$(date +%s)
TEST_USER_PREFIX="testuser_${TEST_RUN_ID}"
TEST_DOMAIN_PREFIX="testdomain_${TEST_RUN_ID}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Utility functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_test() {
    echo -e "${YELLOW}🧪 $1${NC}"
}

# Helper function to filter out createdAt and modifiedAt
filter_data_items() {
    jq 'del(.data[].createdAt, .data[].modifiedAt)'
}

filter_data_item() {
    jq 'del(.data.createdAt, .data.modifiedAt)'
}

# Function to get admin token
get_admin_token() {
    local domain=${1:-"editor"}
    curl -s -X POST $BASE_URL/login \
         -H "Content-Type: application/json" \
         -d '{"username": "'$USERNAME'", "password": "'$PASSWORD'"}' | jq -r '.token'
}

# Function to cleanup token file
cleanup_token() {
    rm -rf $TOKEN_STORE
}

# Function to store token
store_token() {
    local token=$1
    echo "$token" > $TOKEN_STORE
}

# Function to read token
read_token() {
    cat $TOKEN_STORE 2>/dev/null || echo ""
}

# Function to check if server is running
check_server() {
    curl -s -o /dev/null -w "%{http_code}" $BASE_URL/editor/data > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_error "Server is not running at $BASE_URL"
        return 1
    fi
    return 0
}

# Function to create test output directory
ensure_data_dir() {
    mkdir -p "$basePath/data"
}

# Function to cleanup test data from previous runs
cleanup_test_data() {
    local admin_token=$(get_admin_token "editor")
    
    if [ -n "$admin_token" ] && [ "$admin_token" != "null" ]; then
        log_info "Cleaning up test data from previous runs..."
        
        # Hard delete old soft-deleted domains to avoid unique constraint issues
        # Note: This is a maintenance operation for test cleanup
        local db_path="${basePath}/${DB_PATH:-data.db}"
        if [ -f "$db_path" ]; then
            sqlite3 "$db_path" "DELETE FROM domain WHERE name LIKE 'testdomain_%' OR name LIKE 'testproject_%';" 2>/dev/null || true
            sqlite3 "$db_path" "DELETE FROM users WHERE username LIKE 'testuser_%';" 2>/dev/null || true
        fi
        
        log_success "Test data cleanup completed"
    fi
} 