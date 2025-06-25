#!/bin/bash

basePath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Load the .env file
source "$basePath/.env"

endpoint="http://localhost:3000"
# endpoint="https://kv.srv.signalwerk.ch"
username="signalwerk"
password="$DB_USER_PASSWORD"
domain="editor"

# File to store the JWT token
tokenStore="admin_token.txt"

# Function to login and get token
login() {
    echo "Logging in as admin..."
    curl -s -X POST $endpoint/${domain}/login \
         -H "Content-Type: application/json" \
         -d '{"username": "'${username}'", "password": "'${password}'"}' | jq -r '.token' > $tokenStore

    if [ ! -s $tokenStore ] || [ "$(cat $tokenStore)" = "null" ]; then
        echo "Failed to login. Check credentials."
        exit 1
    fi
    echo "Login successful."
}

# Function to list all users
list_users() {
    token=$(cat $tokenStore)
    echo ""
    echo "=== ALL USERS ==="
    curl -s -H "Authorization: Bearer $token" -X GET $endpoint/${domain}/users | jq '.'
}

# Function to list all projects/domains
list_projects() {
    token=$(cat $tokenStore)
    echo ""
    echo "=== ALL PROJECTS/DOMAINS ==="
    curl -s -H "Authorization: Bearer $token" -X GET $endpoint/admin/domains | jq '.'
}

# Function to create a new project/domain
create_project() {
    if [ -z "$1" ]; then
        echo "Error: Domain name is required"
        echo "Usage: $0 create-project <domain_name>"
        exit 1
    fi
    
    token=$(cat $tokenStore)
    domain_name="$1"
    
    echo ""
    echo "=== CREATING PROJECT/DOMAIN: $domain_name ==="
    
    result=$(curl -s -H "Authorization: Bearer $token" \
                  -X POST $endpoint/admin/domains \
                  -H "Content-Type: application/json" \
                  -d '{"name": "'$domain_name'"}')
    
    echo "$result" | jq '.'
    
    # Check if creation was successful
    if echo "$result" | jq -e '.message' > /dev/null; then
        echo ""
        echo "✓ Domain '$domain_name' created successfully!"
        echo "You can now use it in API calls like: https://kv.srv.signalwerk.ch/$domain_name/data"
    else
        echo ""
        echo "✗ Failed to create domain '$domain_name'"
    fi
}

# Function to add domain access to user
add_user_domain() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Error: User ID and domain name are required"
        echo "Usage: $0 add-user-domain <user_id> <domain_name>"
        exit 1
    fi
    
    token=$(cat $tokenStore)
    user_id="$1"
    domain_name="$2"
    
    echo ""
    echo "=== ADDING DOMAIN ACCESS: $domain_name to user $user_id ==="
    
    result=$(curl -s -H "Authorization: Bearer $token" \
                  -X POST $endpoint/admin/users/$user_id/domains \
                  -H "Content-Type: application/json" \
                  -d '{"domain": "'$domain_name'"}')
    
    echo "$result" | jq '.'
}

# Function to remove domain access from user
remove_user_domain() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Error: User ID and domain name are required"
        echo "Usage: $0 remove-user-domain <user_id> <domain_name>"
        exit 1
    fi
    
    token=$(cat $tokenStore)
    user_id="$1"
    domain_name="$2"
    
    echo ""
    echo "=== REMOVING DOMAIN ACCESS: $domain_name from user $user_id ==="
    
    result=$(curl -s -H "Authorization: Bearer $token" \
                  -X DELETE $endpoint/admin/users/$user_id/domains/$domain_name)
    
    echo "$result" | jq '.'
}

# Function to create a new user
create_user() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Error: Username and password are required"
        echo "Usage: $0 create-user <username> <password> [domain] [active] [admin]"
        exit 1
    fi
    
    token=$(cat $tokenStore)
    username="$1"
    password="$2"
    user_domain="${3:-}"
    is_active="${4:-false}"
    is_admin="${5:-false}"
    
    echo ""
    echo "=== CREATING USER: $username ==="
    
    # Build JSON payload
    json_payload='{"username": "'$username'", "password": "'$password'", "isActive": '$is_active', "isAdmin": '$is_admin
    if [ ! -z "$user_domain" ]; then
        json_payload=$json_payload', "domain": "'$user_domain'"'
    fi
    json_payload=$json_payload'}'
    
    result=$(curl -s -H "Authorization: Bearer $token" \
                  -X POST $endpoint/admin/users \
                  -H "Content-Type: application/json" \
                  -d "$json_payload")
    
    echo "$result" | jq '.'
    
    # Check if creation was successful
    if echo "$result" | jq -e '.message' > /dev/null; then
        user_id=$(echo "$result" | jq -r '.user.id')
        echo ""
        echo "✓ User '$username' created successfully! (ID: $user_id)"
    else
        echo ""
        echo "✗ Failed to create user '$username'"
    fi
}

# Function to delete a user
delete_user() {
    if [ -z "$1" ]; then
        echo "Error: User ID is required"
        echo "Usage: $0 delete-user <user_id>"
        exit 1
    fi
    
    token=$(cat $tokenStore)
    user_id="$1"
    
    echo ""
    echo "=== DELETING USER: $user_id ==="
    echo "Warning: This will soft-delete the user!"
    read -p "Are you sure? (y/N): " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Cancelled."
        exit 0
    fi
    
    result=$(curl -s -H "Authorization: Bearer $token" \
                  -X DELETE $endpoint/admin/users/$user_id)
    
    echo "$result" | jq '.'
    
    # Check if deletion was successful
    if echo "$result" | jq -e '.message' > /dev/null; then
        echo ""
        echo "✓ User ID $user_id deleted successfully!"
    else
        echo ""
        echo "✗ Failed to delete user ID $user_id"
    fi
}

# Function to show help
show_help() {
    echo "Usage: $0 [COMMAND] [ARGS]"
    echo ""
    echo "Commands:"
    echo "  users                        List all users"
    echo "  projects                     List all projects/domains"
    echo "  create-project               Create a new project/domain"
    echo "  create-user                  Create a new user"
    echo "  delete-user                  Delete a user (soft delete)"
    echo "  add-user-domain              Add domain access to user"
    echo "  remove-user-domain           Remove domain access from user"
    echo "  all                          List both users and projects"
    echo "  help                         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                       # List users and projects"
    echo "  $0 users                                 # List only users"
    echo "  $0 projects                              # List only projects"
    echo "  $0 create-project myproject              # Create new domain 'myproject'"
    echo "  $0 create-user john secret123            # Create user 'john' with password 'secret123'"
    echo "  $0 create-user jane pass456 editor true  # Create active user 'jane' with editor domain access"
    echo "  $0 delete-user 5                         # Delete user with ID 5"
    echo "  $0 add-user-domain 2 myproject           # Give user ID 2 access to 'myproject'"
    echo "  $0 remove-user-domain 2 myproject        # Remove user ID 2 access to 'myproject'"
    echo ""
    echo "Note: create-user parameters: <username> <password> [domain] [active:true/false] [admin:true/false]"
    echo "If no command is provided, help is shown."
}

# Clean up token file on exit
cleanup() {
    rm -f $tokenStore
}
trap cleanup EXIT

# Main logic
case "${1:-help}" in
    "users")
        login
        list_users
        ;;
    "projects")
        login
        list_projects
        ;;
    "create-project")
        login
        create_project "$2"
        ;;
    "create-user")
        login
        create_user "$2" "$3" "$4" "$5" "$6"
        ;;
    "delete-user")
        login
        delete_user "$2"
        ;;
    "add-user-domain")
        login
        add_user_domain "$2" "$3"
        ;;
    "remove-user-domain")
        login
        remove_user_domain "$2" "$3"
        ;;
    "all")
        login
        list_users
        list_projects
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac 