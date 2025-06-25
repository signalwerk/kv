#!/bin/bash

# Domain access control tests

# Source shared utilities
source "$(dirname "${BASH_SOURCE[0]}")/shared.sh"

run_domain_access_tests() {
    log_test "Domain Access Control Tests"
    echo "===================================="
    
    local test_failed=0
    local test_domain="${TEST_DOMAIN_PREFIX}_access"
    local test_user="${TEST_USER_PREFIX}_domain"
    local test_password="testpass123"
    
    # Get admin token
    local admin_token=$(get_admin_token "editor")
    
    if [ "$admin_token" = "null" ] || [ -z "$admin_token" ]; then
        log_error "Failed to get admin token"
        return 1
    fi
    
    # Test 1: Create test domain as admin
    log_info "Creating test domain '$test_domain'..."
    curl -s -H "Authorization: Bearer $admin_token" \
         -X POST $BASE_URL/admin/domains \
         -H "Content-Type: application/json" \
         -d "{\"name\": \"$test_domain\"}" > "$basePath/data/400-create-test-domain.json"
    
    local create_result=$(cat "$basePath/data/400-create-test-domain.json" | jq -r '.message' 2>/dev/null)
    if [ "$create_result" = "Domain created successfully" ]; then
        log_success "Test domain created"
    else
        log_error "Failed to create test domain"
        test_failed=1
    fi
    
    # Test 2: Register a new test user in editor domain
    log_info "Registering test user..."
    curl -s -X POST $BASE_URL/editor/register \
         -H "Content-Type: application/json" \
         -d "{\"username\": \"$test_user\", \"password\": \"$test_password\"}" > "$basePath/data/401-register-test-user.json"
    
    local register_result=$(cat "$basePath/data/401-register-test-user.json" | jq -r '.message' 2>/dev/null)
    if [ "$register_result" = "User created" ]; then
        log_success "Test user registered"
        
        # Activate the user (as admin would do)
        local user_id=$(cat "$basePath/data/401-register-test-user.json" | jq -r '.id' 2>/dev/null)
        if [ -n "$user_id" ] && [ "$user_id" != "null" ]; then
            log_info "Activating registered user..."
            curl -s -H "Authorization: Bearer $admin_token" \
                 -X PUT $BASE_URL/editor/users/$user_id \
                 -H "Content-Type: application/json" \
                 -d '{"isActive": true}' > "$basePath/data/401b-user-activate.json"
            log_success "User activated"
        fi
    else
        log_error "Failed to register test user"
        test_failed=1
    fi
    
    # Test 3: Login as test user
    log_info "Logging in as test user..."
    local login_response=$(curl -s -X POST $BASE_URL/editor/login \
                          -H "Content-Type: application/json" \
                          -d "{\"username\": \"$test_user\", \"password\": \"$test_password\"}")
    
    # but remove the token
    login_response_clean=$(echo "$login_response" | jq -r 'del(.token)')
    echo "$login_response" > "$basePath/data/402-user-login.json"
    
    local user_token=$(echo "$login_response" | jq -r '.token' 2>/dev/null)
    
    if [ "$user_token" = "null" ] || [ -z "$user_token" ]; then
        log_error "Failed to get user token"
        test_failed=1
    else
        log_success "User token acquired"
        
        # Test 4: User should have access to editor domain (where they registered)
        log_info "Testing access to editor domain (should work)..."
        local editor_access=$(curl -s -w "%{http_code}" -o /dev/null \
                             -H "Authorization: Bearer $user_token" \
                             -X GET $BASE_URL/editor/data)
        
        if [ "$editor_access" = "200" ]; then
            log_success "User can access editor domain"
        else
            log_error "User cannot access editor domain (got $editor_access)"
            test_failed=1
        fi
        
        # Test 5: User should NOT have access to test domain (they weren't granted access)
        log_info "Testing access to test domain (should fail)..."
        curl -s -H "Authorization: Bearer $user_token" \
             -X GET $BASE_URL/$test_domain/data > "$basePath/data/410-unauthorized-access.json" 2>/dev/null
        
        local test_access=$(curl -s -w "%{http_code}" -o /dev/null \
                           -H "Authorization: Bearer $user_token" \
                           -X GET $BASE_URL/$test_domain/data)
        
        if [ "$test_access" = "403" ]; then
            log_success "User correctly denied access to test domain"
        else
            log_error "User should not have access to test domain (got $test_access)"
            test_failed=1
        fi
        
        # Test 6: Get user ID for domain grant
        local user_id=$(curl -s -H "Authorization: Bearer $admin_token" \
                       -X GET $BASE_URL/editor/users | jq -r ".users[] | select(.username==\"$test_user\") | .id")
        
        if [ -n "$user_id" ] && [ "$user_id" != "null" ]; then
            log_success "Found user ID: $user_id"
            
            # Test 7: Admin grants user access to test domain
            log_info "Admin granting user access to test domain..."
            curl -s -H "Authorization: Bearer $admin_token" \
                 -X POST $BASE_URL/admin/users/$user_id/domains \
                 -H "Content-Type: application/json" \
                 -d "{\"domain\": \"$test_domain\"}" > "$basePath/data/420-grant-domain-access.json"
            
            local grant_result=$(cat "$basePath/data/420-grant-domain-access.json" | jq -r '.message' 2>/dev/null)
            if [[ "$grant_result" == *"successfully"* ]]; then
                log_success "Domain access granted"
            else
                log_error "Failed to grant domain access"
                test_failed=1
            fi
            
            # Test 8: User should now have access to test domain
            log_info "Testing access to test domain after grant (should work)..."
            curl -s -H "Authorization: Bearer $user_token" \
                 -X GET $BASE_URL/$test_domain/data > "$basePath/data/430-authorized-access.json"
            
            local granted_access=$(curl -s -w "%{http_code}" -o /dev/null \
                                  -H "Authorization: Bearer $user_token" \
                                  -X GET $BASE_URL/$test_domain/data)
            
            if [ "$granted_access" = "200" ]; then
                log_success "User can now access test domain"
            else
                log_error "User still cannot access test domain (got $granted_access)"
                test_failed=1
            fi
            
            # Test 9: Test data operations in the new domain
            log_info "Testing data operations in test domain..."
            curl -s -H "Authorization: Bearer $user_token" \
                 -X POST $BASE_URL/$test_domain/data \
                 -H "Content-Type: application/json" \
                 -d '{"key": "domain-test-key", "value": "domain test value"}' > "$basePath/data/440-domain-data-post.json"
            
            local data_result=$(cat "$basePath/data/440-domain-data-post.json" | jq -r '.data.value' 2>/dev/null)
            if [ "$data_result" = "domain test value" ]; then
                log_success "Data operations work in granted domain"
            else
                log_error "Data operations failed in granted domain"
                test_failed=1
            fi
            
            # Test 10: Remove domain access
            log_info "Removing domain access..."
            curl -s -H "Authorization: Bearer $admin_token" \
                 -X DELETE $BASE_URL/admin/users/$user_id/domains/$test_domain > "$basePath/data/450-revoke-domain-access.json"
            
            local revoke_result=$(cat "$basePath/data/450-revoke-domain-access.json" | jq -r '.message' 2>/dev/null)
            if [[ "$revoke_result" == *"successfully"* ]]; then
                log_success "Domain access revoked"
            else
                log_error "Failed to revoke domain access"
                test_failed=1
            fi
            
            # Test 11: User should no longer have access
            log_info "Testing access after revocation (should fail)..."
            local revoked_access=$(curl -s -w "%{http_code}" -o /dev/null \
                                  -H "Authorization: Bearer $user_token" \
                                  -X GET $BASE_URL/$test_domain/data)
            
            if [ "$revoked_access" = "403" ]; then
                log_success "Access correctly revoked"
            else
                log_error "Access should be revoked (got $revoked_access)"
                test_failed=1
            fi
        else
            log_error "Could not find user ID"
            test_failed=1
        fi
    fi
    
    # Test 12: Admin should always have access to all domains
    log_info "Testing admin access to test domain (should work)..."
    curl -s -H "Authorization: Bearer $admin_token" \
         -X GET $BASE_URL/$test_domain/data > "$basePath/data/460-admin-access.json"
    
    local admin_access=$(curl -s -w "%{http_code}" -o /dev/null \
                        -H "Authorization: Bearer $admin_token" \
                        -X GET $BASE_URL/$test_domain/data)
    
    if [ "$admin_access" = "200" ]; then
        log_success "Admin can access test domain"
    else
        log_error "Admin cannot access test domain (got $admin_access)"
        test_failed=1
    fi
    
    # Test 13: Test invalid domain access
    log_info "Testing access to non-existent domain..."
    local invalid_domain_access=$(curl -s -w "%{http_code}" -o /dev/null \
                                 -H "Authorization: Bearer $admin_token" \
                                 -X GET $BASE_URL/nonexistentdomain/data)
    
    if [ "$invalid_domain_access" = "404" ]; then
        log_success "Non-existent domain correctly returns 404"
    else
        log_error "Non-existent domain should return 404 (got $invalid_domain_access)"
        test_failed=1
    fi
    
    # Cleanup
    log_info "Cleaning up test domain..."
    curl -s -H "Authorization: Bearer $admin_token" \
         -X DELETE $BASE_URL/admin/domains/$test_domain > "$basePath/data/470-cleanup-domain.json"
    
    local cleanup_result=$(cat "$basePath/data/470-cleanup-domain.json" | jq -r '.message' 2>/dev/null)
    if [ "$cleanup_result" = "Domain deleted successfully" ]; then
        log_success "Test domain deleted"
    else
        log_warning "Failed to cleanup test domain"
    fi
    
    echo ""
    if [ $test_failed -eq 0 ]; then
        log_success "All domain access control tests passed!"
        return 0
    else
        log_error "Some domain access control tests failed!"
        return 1
    fi
} 