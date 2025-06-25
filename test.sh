#!/bin/bash

basePath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Load the .env file
source "$basePath/.env"

username="signalwerk"
password="$DB_USER_PASSWORD"
domain="testproject"

# File to store the JWT token
tokenStore="token.txt"

rm -rf $tokenStore

# login and store the token
curl -s -X POST http://localhost:3000/${domain}/login \
     -H "Content-Type: application/json" \
     -d '{"username": "'${username}'", "password": "'${password}'"}' | jq -r '.token' > $tokenStore

# Read the token for subsequent requests
token=$(cat $tokenStore)

# Check login status using the token
curl -s -H "Authorization: Bearer $token" -X GET http://localhost:3000/${domain}/users/me > ./data/011-status.json

# Define a function to filter out createdAt and modifiedAt
filterDataItems() {
  jq 'del(.data[].createdAt, .data[].modifiedAt)'
}

filterDataItem() {
  jq 'del(.data.createdAt, .data.modifiedAt)'
}

# Delete the data
curl -s -H "Authorization: Bearer $token" -X DELETE http://localhost:3000/${domain}/data/test---key1 > ./data/050-delete-key.json

# Fetch Data
curl -s -H "Authorization: Bearer $token" -X GET http://localhost:3000/${domain}/data | filterDataItems > ./data/051-get-data.json

# Add Data
curl -s -H "Authorization: Bearer $token" -X POST http://localhost:3000/${domain}/data \
     -H "Content-Type: application/json" \
     -d '{"key": "test---key1", "value": "hello world"}' | filterDataItem > ./data/100-post-data.json

# Get all Data after addition
curl -s -H "Authorization: Bearer $token" -X GET http://localhost:3000/${domain}/data | filterDataItems > ./data/101-get-data.json

# Get key after addition
curl -s -H "Authorization: Bearer $token" -X GET http://localhost:3000/${domain}/data/test---key1 | filterDataItem > ./data/110-get-data.json

# Update Data
curl -s -H "Authorization: Bearer $token" -X PUT http://localhost:3000/${domain}/data/test---key1 \
     -H "Content-Type: application/json" \
     -d '{"value": "new value"}' | filterDataItem > ./data/200-put-data.json

# Get Data after update
curl -s -H "Authorization: Bearer $token" -X GET http://localhost:3000/${domain}/data | filterDataItems > ./data/201-get-data.json

# Uncomment and modify the following lines as needed for registering new users, getting users, and updating user information.
# Remember to include the Authorization header with the Bearer token for these requests.

# Register
# curl -s -H "Authorization: Bearer $token" -X POST http://localhost:3000/${domain}/register \
#      -H "Content-Type: application/json" \
#      -d '{"username": "[USERNAME]", "password": "[PASSWORD]"}'

# Get Users
# curl -s -H "Authorization: Bearer $token" -X GET http://localhost:3000/${domain}/users

# Update User
# curl -s -H "Authorization: Bearer $token" -X PUT http://localhost:3000/${domain}/users/[USER_ID] \
#      -H "Content-Type: application/json" \
#      -d '{"isActive": [TRUE_OR_FALSE]}'
