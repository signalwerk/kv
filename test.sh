#!/bin/bash

# Main test orchestrator - runs all test suites

set -e

# Get script directory
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Source shared utilities
source "$scriptDir/tests/shared.sh"

# Test suite functions
source "$scriptDir/tests/auth-test.sh"
source "$scriptDir/tests/data-test.sh"
source "$scriptDir/tests/admin-test.sh"
source "$scriptDir/tests/domain-access-test.sh"

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -s, --suite SUITE       Run specific test suite (auth, data, admin, domain-access)"
    echo "  -l, --list              List available test suites"
    echo "  --skip-server-check     Skip server availability check"
    echo ""
    echo "Available test suites:"
    echo "  auth                    Authentication tests"
    echo "  data                    Data CRUD tests"
    echo "  admin                   Admin functionality tests"
    echo "  domain-access          Domain access control tests"
    echo "  all                     Run all test suites (default)"
}

# Function to list available test suites
list_suites() {
    echo "Available test suites:"
    echo "  auth                    Authentication and user management"
    echo "  data                    Data CRUD operations"
    echo "  admin                   Admin functionality (user/domain management)"
    echo "  domain-access          Domain access control"
    echo "  all                     All test suites"
}

# Function to run a specific test suite
run_test_suite() {
    local suite=$1
    
    case $suite in
        "auth")
            run_auth_tests
            return $?
            ;;
        "data")
            run_data_tests
            return $?
            ;;
        "admin")
            run_admin_tests
            return $?
            ;;
        "domain-access")
            run_domain_access_tests
            return $?
            ;;
        *)
            log_error "Unknown test suite: $suite"
            return 1
            ;;
    esac
}

# Function to run all test suites
run_all_tests() {
    local total_failed=0
    
    log_info "🚀 Starting comprehensive test suite..."
    echo "========================================"
    echo ""
    
    # Run authentication tests first (needed for other tests)
    if run_test_suite "auth"; then
        log_success "✅ Authentication tests passed"
    else
        log_error "❌ Authentication tests failed"
        total_failed=$((total_failed + 1))
    fi
    
    echo ""
    echo "----------------------------------------"
    echo ""
    
    # Run data CRUD tests
    if run_test_suite "data"; then
        log_success "✅ Data CRUD tests passed"
    else
        log_error "❌ Data CRUD tests failed"
        total_failed=$((total_failed + 1))
    fi
    
    echo ""
    echo "----------------------------------------"
    echo ""
    
    # Run admin functionality tests
    if run_test_suite "admin"; then
        log_success "✅ Admin functionality tests passed"
    else
        log_error "❌ Admin functionality tests failed"
        total_failed=$((total_failed + 1))
    fi
    
    echo ""
    echo "----------------------------------------"
    echo ""
    
    # Run domain access control tests
    if run_test_suite "domain-access"; then
        log_success "✅ Domain access control tests passed"
    else
        log_error "❌ Domain access control tests failed"
        total_failed=$((total_failed + 1))
    fi
    
    echo ""
    echo "========================================"
    echo ""
    
    if [ $total_failed -eq 0 ]; then
        log_success "🎉 All test suites passed! ($((4 - total_failed))/4)"
        return 0
    else
        log_error "💥 $total_failed test suite(s) failed! ($((4 - total_failed))/4 passed)"
        return 1
    fi
}

# Main function
main() {
    local suite="all"
    local skip_server_check=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -s|--suite)
                suite="$2"
                shift 2
                ;;
            -l|--list)
                list_suites
                exit 0
                ;;
            --skip-server-check)
                skip_server_check=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
    
    # Setup
    log_info "Setting up test environment..."
    ensure_data_dir
    cleanup_test_data
    
    # Check if server is running (unless skipped)
    if [ "$skip_server_check" = false ]; then
        if ! check_server; then
            log_error "Server check failed. Make sure the server is running on $BASE_URL"
            log_info "You can skip this check with --skip-server-check"
            exit 1
        fi
        log_success "Server is running"
    fi
    
    echo ""
    
    # Run tests
    if [ "$suite" = "all" ]; then
        run_all_tests
        exit $?
    else
        log_info "Running $suite test suite..."
        echo "========================================"
        echo ""
        
        if run_test_suite "$suite"; then
            log_success "✅ $suite tests passed!"
            exit 0
        else
            log_error "❌ $suite tests failed!"
            exit 1
        fi
    fi
}

# Run main function with all arguments
main "$@"
