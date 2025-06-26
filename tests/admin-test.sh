#!/bin/bash

# Admin functionality tests

# Source shared utilities
source "$(dirname "${BASH_SOURCE[0]}")/shared.sh"

run_admin_tests() {
    log_test "Admin Functionality Tests"
    echo "================================"
    
    local test_failed=0
    local admin_token=$(read_token)
    
    if [ -z "$admin_token" ]; then
        log_error "No admin token found. Make sure auth tests ran first."
        return 1
    fi
    
    # Test 1: Get all domains
    log_info "Getting all domains..."
    curl -s -H "Authorization: Bearer $admin_token" -X GET $BASE_URL/admin/domains > "$basePath/data/300-admin-domains.json"
    
    local domains_count=$(cat "$basePath/data/300-admin-domains.json" | jq -r '.domains | length' 2>/dev/null)
    if [ "$domains_count" -gt 0 ]; then
        log_success "Retrieved $domains_count domains"
    else
        log_error "Failed to retrieve domains"
        test_failed=1
    fi
    
    # Test 2: Create a new test domain
    local test_domain="${TEST_DOMAIN_PREFIX}_admin"
    log_info "Creating test domain '$test_domain'..."
    curl -s -H "Authorization: Bearer $admin_token" \
         -X POST $BASE_URL/admin/domains \
         -H "Content-Type: application/json" \
         -d "{\"name\": \"$test_domain\"}" > "$basePath/data/301-create-domain.json"
    
    local create_msg=$(cat "$basePath/data/301-create-domain.json" | jq -r '.message' 2>/dev/null)
    if [ "$create_msg" = "Domain created successfully" ]; then
        log_success "Test domain created successfully"
    else
        log_error "Failed to create test domain"
        test_failed=1
    fi
    
    # Test 3: Try to create duplicate domain
    log_info "Testing duplicate domain creation..."
    curl -s -H "Authorization: Bearer $admin_token" \
         -X POST $BASE_URL/admin/domains \
         -H "Content-Type: application/json" \
         -d "{\"name\": \"$test_domain\"}" > "$basePath/data/302-duplicate-domain.json"
    
    local duplicate_error=$(cat "$basePath/data/302-duplicate-domain.json" | jq -r '.error' 2>/dev/null)
    if [[ "$duplicate_error" == *"already exists"* ]]; then
        log_success "Duplicate domain correctly rejected"
    else
        log_error "Duplicate domain should be rejected"
        test_failed=1
    fi
    
    # Test 4: Get all users (admin route)
    log_info "Getting all users (admin route)..."
    curl -s -H "Authorization: Bearer $admin_token" -X GET $BASE_URL/admin/users > "$basePath/data/310-editor-users.json"
    
    local users_count=$(cat "$basePath/data/310-editor-users.json" | jq -r '.users | length' 2>/dev/null)
    if [ "$users_count" -gt 0 ]; then
        log_success "Retrieved $users_count users from admin route"
    else
        log_error "Failed to retrieve users from admin route"
        test_failed=1
    fi
    
    # Test 5: Get a test user ID for domain assignment
    local test_username="${TEST_USER_PREFIX}_auth"
    local test_user_id=$(cat "$basePath/data/310-editor-users.json" | jq -r ".users[] | select(.username==\"$test_username\") | .id" 2>/dev/null)
    
    if [ -n "$test_user_id" ] && [ "$test_user_id" != "null" ]; then
        log_success "Found test user ID: $test_user_id"
        
        # Test 6: Grant user access to test domain
        log_info "Granting user access to $test_domain..."
        curl -s -H "Authorization: Bearer $admin_token" \
             -X POST $BASE_URL/admin/users/$test_user_id/domains \
             -H "Content-Type: application/json" \
             -d "{\"domain\": \"$test_domain\"}" > "$basePath/data/320-grant-domain-access.json"
        
        local grant_msg=$(cat "$basePath/data/320-grant-domain-access.json" | jq -r '.message' 2>/dev/null)
        if [[ "$grant_msg" == *"successfully"* ]]; then
            log_success "Domain access granted successfully"
        else
            log_error "Failed to grant domain access"
            test_failed=1
        fi
        
        # Test 7: Try to grant duplicate access
        log_info "Testing duplicate domain access grant..."
        curl -s -H "Authorization: Bearer $admin_token" \
             -X POST $BASE_URL/admin/users/$test_user_id/domains \
             -H "Content-Type: application/json" \
             -d "{\"domain\": \"$test_domain\"}" > "$basePath/data/321-duplicate-access.json"
        
        local duplicate_msg=$(cat "$basePath/data/321-duplicate-access.json" | jq -r '.message' 2>/dev/null)
        if [[ "$duplicate_msg" == *"already has access"* ]]; then
            log_success "Duplicate access correctly handled"
        else
            log_warning "Duplicate access handling may need attention"
        fi
        
        # Test 8: Update user status (deactivate)
        log_info "Deactivating test user..."
        curl -s -H "Authorization: Bearer $admin_token" \
             -X PUT $BASE_URL/admin/users/$test_user_id \
             -H "Content-Type: application/json" \
             -d '{"isActive": false}' > "$basePath/data/330-deactivate-user.json"
        
        local deactivate_msg=$(cat "$basePath/data/330-deactivate-user.json" | jq -r '.message' 2>/dev/null)
        if [ "$deactivate_msg" = "User updated" ]; then
            log_success "User deactivated successfully"
        else
            log_error "Failed to deactivate user"
            test_failed=1
        fi
        
        # Test 9: Reactivate user
        log_info "Reactivating test user..."
        curl -s -H "Authorization: Bearer $admin_token" \
             -X PUT $BASE_URL/admin/users/$test_user_id \
             -H "Content-Type: application/json" \
             -d '{"isActive": true}' > "$basePath/data/331-reactivate-user.json"
        
        local reactivate_msg=$(cat "$basePath/data/331-reactivate-user.json" | jq -r '.message' 2>/dev/null)
        if [ "$reactivate_msg" = "User updated" ]; then
            log_success "User reactivated successfully"
        else
            log_error "Failed to reactivate user"
            test_failed=1
        fi
        
        # Test 10: Remove domain access
        log_info "Removing domain access..."
        curl -s -H "Authorization: Bearer $admin_token" \
             -X DELETE $BASE_URL/admin/users/$test_user_id/domains/$test_domain > "$basePath/data/340-remove-domain-access.json"
        
        local remove_msg=$(cat "$basePath/data/340-remove-domain-access.json" | jq -r '.message' 2>/dev/null)
        if [[ "$remove_msg" == *"successfully"* ]]; then
            log_success "Domain access removed successfully"
        else
            log_error "Failed to remove domain access"
            test_failed=1
        fi
    else
        log_warning "Test user not found - skipping user management tests"
    fi
    
    # Test 11: Try admin operations with non-admin token (if we have a user token)
    # This would require creating a separate user token, but we'll skip for now
    # as it would complicate the test setup
    
    # Test 12: Delete test domain
    log_info "Deleting test domain..."
    curl -s -H "Authorization: Bearer $admin_token" \
         -X DELETE $BASE_URL/admin/domains/$test_domain > "$basePath/data/350-delete-domain.json"
    
    local delete_msg=$(cat "$basePath/data/350-delete-domain.json" | jq -r '.message' 2>/dev/null)
    if [ "$delete_msg" = "Domain deleted successfully" ]; then
        log_success "Test domain deleted successfully"
    else
        log_error "Failed to delete test domain"
        test_failed=1
    fi
    
    # Test 13: Try to delete non-existent domain
    log_info "Testing deletion of non-existent domain..."
    local nonexistent_response=$(curl -s -w "%{http_code}" -o /dev/null \
                               -H "Authorization: Bearer $admin_token" \
                               -X DELETE $BASE_URL/admin/domains/nonexistent)
    
    if [ "$nonexistent_response" = "404" ]; then
        log_success "Non-existent domain deletion correctly returns 404"
    else
        log_error "Non-existent domain deletion should return 404 (got $nonexistent_response)"
        test_failed=1
    fi
    
    # Test 14: Create a test user to test admin tool activate/deactivate commands
    local admin_test_username="${TEST_USER_PREFIX}_admin_test"
    local admin_test_password="testpass456"
    log_info "Creating test user for admin tool testing..."
    
    local create_user_result=$(curl -s -H "Authorization: Bearer $admin_token" \
                              -X POST $BASE_URL/admin/users \
                              -H "Content-Type: application/json" \
                              -d "{\"username\": \"$admin_test_username\", \"password\": \"$admin_test_password\", \"domain\": \"editor\"}")
    
    echo "$create_user_result" > "$basePath/data/360-create-admin-test-user.json"
    
    local admin_test_user_id=$(echo "$create_user_result" | jq -r '.user.id' 2>/dev/null)
    local create_user_msg=$(echo "$create_user_result" | jq -r '.message' 2>/dev/null)
    
    if [ "$create_user_msg" = "User created successfully" ] && [ -n "$admin_test_user_id" ] && [ "$admin_test_user_id" != "null" ]; then
        log_success "Test user created successfully (ID: $admin_test_user_id)"
        
        # Test 15: Test user deactivation via API (simulate admin tool functionality)
        log_info "Testing user deactivation via API..."
        curl -s -H "Authorization: Bearer $admin_token" \
             -X PUT $BASE_URL/admin/users/$admin_test_user_id \
             -H "Content-Type: application/json" \
             -d '{"isActive": false}' > "$basePath/data/365-test-deactivate-user.json"
        
        local deactivate_msg=$(cat "$basePath/data/365-test-deactivate-user.json" | jq -r '.message' 2>/dev/null)
        if [ "$deactivate_msg" = "User updated" ]; then
            log_success "User deactivation API works correctly"
        else
            log_error "User deactivation API failed"
            test_failed=1
        fi
        
        # Verify user is actually deactivated by checking status
        local user_status=$(curl -s -H "Authorization: Bearer $admin_token" -X GET $BASE_URL/admin/users | jq -r ".users[] | select(.id==$admin_test_user_id) | .isActive" 2>/dev/null)
        if [ "$user_status" = "0" ]; then
            log_success "User correctly deactivated (isActive: $user_status)"
        else
            log_error "User deactivation verification failed (isActive: $user_status)"
            test_failed=1
        fi
        
        # Test 16: Test user activation via API (simulate admin tool functionality)
        log_info "Testing user activation via API..."
        curl -s -H "Authorization: Bearer $admin_token" \
             -X PUT $BASE_URL/admin/users/$admin_test_user_id \
             -H "Content-Type: application/json" \
             -d '{"isActive": true}' > "$basePath/data/366-test-activate-user.json"
        
        local activate_msg=$(cat "$basePath/data/366-test-activate-user.json" | jq -r '.message' 2>/dev/null)
        if [ "$activate_msg" = "User updated" ]; then
            log_success "User activation API works correctly"
        else
            log_error "User activation API failed"
            test_failed=1
        fi
        
        # Verify user is actually activated by checking status
        local user_status_after=$(curl -s -H "Authorization: Bearer $admin_token" -X GET $BASE_URL/admin/users | jq -r ".users[] | select(.id==$admin_test_user_id) | .isActive" 2>/dev/null)
        if [ "$user_status_after" = "1" ]; then
            log_success "User correctly activated (isActive: $user_status_after)"
        else
            log_error "User activation verification failed (isActive: $user_status_after)"
            test_failed=1
        fi
        
        # Test 17: Test that newly created users are active by default
        log_info "Testing that newly created users are active by default..."
        local default_active_username="${TEST_USER_PREFIX}_default_active"
        local default_active_result=$(curl -s -H "Authorization: Bearer $admin_token" \
                                     -X POST $BASE_URL/admin/users \
                                     -H "Content-Type: application/json" \
                                     -d "{\"username\": \"$default_active_username\", \"password\": \"testpass789\", \"domain\": \"editor\"}")
        
        echo "$default_active_result" > "$basePath/data/370-default-active-user.json"
        
        local default_active_user_id=$(echo "$default_active_result" | jq -r '.user.id' 2>/dev/null)
        local default_active_status=$(echo "$default_active_result" | jq -r '.user.isActive' 2>/dev/null)
        
        if [ "$default_active_status" = "true" ]; then
            log_success "New users are created as active by default"
        else
            log_error "New users should be created as active by default (got: $default_active_status)"
            test_failed=1
        fi
        
        # Cleanup test users
        log_info "Cleaning up test users..."
        curl -s -H "Authorization: Bearer $admin_token" -X DELETE $BASE_URL/admin/users/$admin_test_user_id > /dev/null 2>&1
        if [ -n "$default_active_user_id" ] && [ "$default_active_user_id" != "null" ]; then
            curl -s -H "Authorization: Bearer $admin_token" -X DELETE $BASE_URL/admin/users/$default_active_user_id > /dev/null 2>&1
        fi
        log_success "Test users cleaned up"
        
    else
        log_warning "Could not create test user for admin tool testing - skipping admin tool tests"
    fi
    
    echo ""
    if [ $test_failed -eq 0 ]; then
        log_success "All admin functionality tests passed!"
        return 0
    else
        log_error "Some admin functionality tests failed!"
        return 1
    fi
} 