# Test Suite Documentation

This directory contains modular test scripts for the KV store application.

## Structure

- `shared.sh` - Common utilities and configuration shared across all tests
- `auth-test.sh` - Authentication and user registration tests
- `data-test.sh` - Data CRUD operations tests
- `admin-test.sh` - Admin functionality tests (user/domain management)
- `domain-access-test.sh` - Domain access control tests

## Usage

### Run all tests (recommended)
```bash
./test.sh
```

### Run specific test suite
```bash
./test.sh --suite auth          # Authentication tests
./test.sh --suite data          # Data CRUD tests
./test.sh --suite admin         # Admin functionality tests
./test.sh --suite domain-access # Domain access control tests
```

### Other options
```bash
./test.sh --help                # Show help
./test.sh --list                # List available test suites
./test.sh --skip-server-check   # Skip server availability check
```

## Test Output

All tests save their API responses as JSON files in the `../data/` directory. This allows you to:
- Track changes in git
- Debug issues by examining the actual API responses
- Verify data consistency across test runs

## Test Sequence

The tests are designed to run in a specific order:
1. **Authentication** - Sets up admin token and creates test users
2. **Data** - Tests CRUD operations using tokens from auth tests
3. **Admin** - Tests admin functionality using existing users
4. **Domain Access** - Tests domain access control with new domains

## Requirements

- Server must be running on `http://localhost:3000`
- `.env` file must be present with `DB_USER_PASSWORD` set
- `jq` command must be available for JSON processing
- `curl` command must be available for API requests

## JSON Output Files

Files are numbered to show the sequence of operations:
- `000-099` - Authentication tests
- `100-199` - Data CRUD tests  
- `200-299` - (Additional data tests)
- `300-399` - Admin functionality tests
- `400-499` - Domain access control tests 