#!/bin/bash

# Data CRUD tests

# Source shared utilities
source "$(dirname "${BASH_SOURCE[0]}")/shared.sh"

run_data_tests() {
    log_test "Data CRUD Tests"
    echo "====================="
    
    local test_failed=0
    local token=$(read_token)
    
    if [ -z "$token" ]; then
        log_error "No token found. Make sure auth tests ran first."
        return 1
    fi
    
    # Test 1: Delete existing test data (cleanup)
    log_info "Cleaning up existing test data..."
    curl -s -H "Authorization: Bearer $token" -X DELETE $BASE_URL/editor/data/test---key1 > "$basePath/data/050-delete-key.json"
    log_success "Cleanup completed"
    
    # Test 2: Get all data (should be empty or not contain our test key)
    log_info "Getting all data after cleanup..."
    curl -s -H "Authorization: Bearer $token" -X GET $BASE_URL/editor/data | filter_data_items > "$basePath/data/051-get-data.json"
    
    local has_test_key=$(cat "$basePath/data/051-get-data.json" | jq -r '.data[] | select(.key=="test---key1") | .key' 2>/dev/null)
    if [ -z "$has_test_key" ]; then
        log_success "Test key not found (as expected)"
    else
        log_warning "Test key still exists after deletion"
    fi
    
    # Test 3: Add new data
    log_info "Adding new data..."
    curl -s -H "Authorization: Bearer $token" -X POST $BASE_URL/editor/data \
         -H "Content-Type: application/json" \
         -d '{"key": "test---key1", "value": "hello world"}' | filter_data_item > "$basePath/data/100-post-data.json"
    
    local added_value=$(cat "$basePath/data/100-post-data.json" | jq -r '.data.value' 2>/dev/null)
    if [ "$added_value" = "hello world" ]; then
        log_success "Data added successfully"
    else
        log_error "Failed to add data"
        test_failed=1
    fi
    
    # Test 4: Get all data after addition
    log_info "Getting all data after addition..."
    curl -s -H "Authorization: Bearer $token" -X GET $BASE_URL/editor/data | filter_data_items > "$basePath/data/101-get-data.json"
    
    local found_value=$(cat "$basePath/data/101-get-data.json" | jq -r '.data[] | select(.key=="test---key1") | .value' 2>/dev/null)
    if [ "$found_value" = "hello world" ]; then
        log_success "Data found in list"
    else
        log_error "Added data not found in list"
        test_failed=1
    fi
    
    # Test 5: Get specific key
    log_info "Getting specific key..."
    curl -s -H "Authorization: Bearer $token" -X GET $BASE_URL/editor/data/test---key1 | filter_data_item > "$basePath/data/110-get-data.json"
    
    local specific_value=$(cat "$basePath/data/110-get-data.json" | jq -r '.data.value' 2>/dev/null)
    if [ "$specific_value" = "hello world" ]; then
        log_success "Specific key retrieved successfully"
    else
        log_error "Failed to retrieve specific key"
        test_failed=1
    fi
    
    # Test 6: Update data
    log_info "Updating data..."
    curl -s -H "Authorization: Bearer $token" -X PUT $BASE_URL/editor/data/test---key1 \
         -H "Content-Type: application/json" \
         -d '{"value": "new value"}' | filter_data_item > "$basePath/data/200-put-data.json"
    
    local updated_value=$(cat "$basePath/data/200-put-data.json" | jq -r '.data.value' 2>/dev/null)
    if [ "$updated_value" = "new value" ]; then
        log_success "Data updated successfully"
    else
        log_error "Failed to update data"
        test_failed=1
    fi
    
    # Test 7: Get all data after update
    log_info "Getting all data after update..."
    curl -s -H "Authorization: Bearer $token" -X GET $BASE_URL/editor/data | filter_data_items > "$basePath/data/201-get-data.json"
    
    local updated_found=$(cat "$basePath/data/201-get-data.json" | jq -r '.data[] | select(.key=="test---key1") | .value' 2>/dev/null)
    if [ "$updated_found" = "new value" ]; then
        log_success "Updated data found in list"
    else
        log_error "Updated data not found in list"
        test_failed=1
    fi
    
    # Test 8: Try to get non-existent key
    log_info "Testing non-existent key retrieval..."
    local not_found_response=$(curl -s -w "%{http_code}" -o /dev/null \
                              -H "Authorization: Bearer $token" \
                              -X GET $BASE_URL/editor/data/nonexistent-key)
    
    if [ "$not_found_response" = "404" ]; then
        log_success "Non-existent key correctly returns 404"
    else
        log_error "Non-existent key should return 404 (got $not_found_response)"
        test_failed=1
    fi
    
    # Test 9: Try to update non-existent key
    log_info "Testing update of non-existent key..."
    local update_not_found=$(curl -s -w "%{http_code}" -o /dev/null \
                           -H "Authorization: Bearer $token" \
                           -X PUT $BASE_URL/editor/data/nonexistent-key \
                           -H "Content-Type: application/json" \
                           -d '{"value": "should fail"}')
    
    if [ "$update_not_found" = "404" ]; then
        log_success "Update of non-existent key correctly returns 404"
    else
        log_error "Update of non-existent key should return 404 (got $update_not_found)"
        test_failed=1
    fi
    
    # Test 10: Delete the test key
    log_info "Deleting test key..."
    local delete_response=$(curl -s -H "Authorization: Bearer $token" \
                          -X DELETE $BASE_URL/editor/data/test---key1)
    
    echo "$delete_response" > "$basePath/data/210-delete-final.json"
    
    local delete_msg=$(echo "$delete_response" | jq -r '.message' 2>/dev/null)
    if [ "$delete_msg" = "Key deleted" ]; then
        log_success "Key deleted successfully"
    else
        log_error "Failed to delete key"
        test_failed=1
    fi
    
    # Test 11: Verify key is deleted
    log_info "Verifying key deletion..."
    local deleted_check=$(curl -s -w "%{http_code}" -o /dev/null \
                         -H "Authorization: Bearer $token" \
                         -X GET $BASE_URL/editor/data/test---key1)
    
    if [ "$deleted_check" = "404" ]; then
        log_success "Deleted key is no longer accessible"
    else
        log_error "Deleted key should not be accessible (got $deleted_check)"
        test_failed=1
    fi
    
    echo ""
    if [ $test_failed -eq 0 ]; then
        log_success "All data CRUD tests passed!"
        return 0
    else
        log_error "Some data CRUD tests failed!"
        return 1
    fi
} 