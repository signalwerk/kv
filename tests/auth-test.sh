#!/bin/bash

# Authentication tests

# Source shared utilities
source "$(dirname "${BASH_SOURCE[0]}")/shared.sh"

run_auth_tests() {
    log_test "Authentication Tests"
    echo "========================="
    
    local test_failed=0
    
    # Test 1: Admin login
    log_info "Testing admin login..."
    cleanup_token
    
    # Get admin token and store it
    local admin_token=$(get_admin_token "editor")
    
    if [ "$admin_token" = "null" ] || [ -z "$admin_token" ]; then
        log_error "Admin login failed"
        test_failed=1
    else
        store_token "$admin_token"
        log_success "Admin login successful"
        
        # Check login status
        curl -s -H "Authorization: Bearer $admin_token" -X GET $BASE_URL/users/me > "$basePath/data/000-admin-status.json"
        
        local username=$(cat "$basePath/data/000-admin-status.json" | jq -r '.user.username' 2>/dev/null)
        if [ "$username" = "$USERNAME" ]; then
            log_success "Admin status verified"
        else
            log_error "Admin status verification failed"
            test_failed=1
        fi
    fi
    
    # Test 2: Create user via admin API (replaces register route)
    log_info "Creating test user via admin API..."
    local test_username="${TEST_USER_PREFIX}_auth"
    local create_response=$(curl -s -H "Authorization: Bearer $admin_token" \
                           -X POST $BASE_URL/admin/users \
                           -H "Content-Type: application/json" \
                           -d "{\"username\": \"$test_username\", \"password\": \"testpass123\", \"isActive\": true, \"domain\": \"editor\"}")
    
    echo "$create_response" > "$basePath/data/001-user-register.json"
    
    local create_success=$(echo "$create_response" | jq -r '.message' 2>/dev/null)
    if [ "$create_success" = "User created successfully" ]; then
        log_success "User creation successful via admin API"
        
        # User is already active (created with isActive: true)
        local user_id=$(echo "$create_response" | jq -r '.user.id' 2>/dev/null)
        if [ -n "$user_id" ] && [ "$user_id" != "null" ]; then
            log_success "User created and activated (ID: $user_id)"
            # Create activation confirmation file for compatibility
            echo '{"message": "User activated", "changes": 1}' > "$basePath/data/001b-user-activate.json"
        fi
    else
        log_error "User creation failed"
        test_failed=1
    fi
    
    # Test 3: User login
    log_info "Testing user login..."
    local login_response=$(curl -s -X POST $BASE_URL/login \
                          -H "Content-Type: application/json" \
                          -d "{\"username\": \"$test_username\", \"password\": \"testpass123\"}")

    # but remove the token
    login_response_clean=$(echo "$login_response" | jq -r 'del(.token)')
    echo "$login_response_clean" > "$basePath/data/002-user-login.json"
    
    local user_token=$(echo "$login_response" | jq -r '.token' 2>/dev/null)
    
    if [ "$user_token" = "null" ] || [ -z "$user_token" ]; then
        log_error "User login failed"
        test_failed=1
    else
        log_success "User login successful"
        
        # Check user status
        curl -s -H "Authorization: Bearer $user_token" -X GET $BASE_URL/users/me > "$basePath/data/003-user-status.json"
        
        local user_username=$(cat "$basePath/data/003-user-status.json" | jq -r '.user.username' 2>/dev/null)
        if [ "$user_username" = "$test_username" ]; then
            log_success "User status verified"
        else
            log_error "User status verification failed"
            test_failed=1
        fi
    fi
    
    # Test 4: Invalid login
    log_info "Testing invalid login..."
    local invalid_response=$(curl -s -X POST $BASE_URL/login \
                           -H "Content-Type: application/json" \
                           -d '{"username": "nonexistent", "password": "wrongpass"}')
    
    echo "$invalid_response" > "$basePath/data/004-invalid-login.json"
    
    local error_msg=$(echo "$invalid_response" | jq -r '.error' 2>/dev/null)
    if [[ "$error_msg" == *"Incorrect username"* ]]; then
        log_success "Invalid login correctly rejected"
    else
        log_error "Invalid login should have been rejected"
        test_failed=1
    fi
    
    # Test 5: Access without token
    log_info "Testing access without token..."
    local no_token_response=$(curl -s -w "%{http_code}" -o /dev/null -X GET $BASE_URL/editor/data)
    
    if [ "$no_token_response" = "401" ]; then
        log_success "Access correctly denied without token"
    else
        log_error "Access should be denied without token (got $no_token_response)"
        test_failed=1
    fi
    
    echo ""
    if [ $test_failed -eq 0 ]; then
        log_success "All authentication tests passed!"
        return 0
    else
        log_error "Some authentication tests failed!"
        return 1
    fi
} 