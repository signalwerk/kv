#!/bin/bash


basePath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Load the .env file
source "$basePath/.env"

username="signalwerk"
password="$DB_USER_PASSWORD"
domain="editor"

cookieStore="cookie.txt"

rm -rf $cookieStore


# login
curl -X GET http://localhost:3000/${domain}/users/me > ./data/000-status.json

# login
curl -c $cookieStore -X POST http://localhost:3000/${domain}/login \
     -H "Content-Type: application/json" \
     -d '{"username": "'${username}'", "password": "'${password}'"}' > ./data/010-status.json
curl -b $cookieStore -X GET http://localhost:3000/${domain}/users/me > ./data/011-status.json


# delete the data
curl -b $cookieStore -X DELETE http://localhost:3000/${domain}/data/test---key1 > ./data/050-delete-key.json

# Fetch Data
curl -b $cookieStore -X GET http://localhost:3000/${domain}/data > ./data/051-get-data.json

# Add Data
curl -b $cookieStore -X POST http://localhost:3000/${domain}/data \
     -H "Content-Type: application/json" \
     -d '{"key": "test---key1", "value": "hello world"}' > ./data/100-post-data.json

curl -b $cookieStore -X GET http://localhost:3000/${domain}/data > ./data/101-get-data.json


# Update Data
curl -b $cookieStore -X PUT http://localhost:3000/${domain}/data/test---key1 \
     -H "Content-Type: application/json" \
     -d '{"value": "new value"}' > ./data/200-put-data.json
curl -b $cookieStore -X GET http://localhost:3000/${domain}/data > ./data/201-get-data.json


# Register
# curl -X POST http://localhost:3000/${domain}/register -d "username=[USERNAME]&password=[PASSWORD]"

# Get Users
# curl -b $cookieStore -X GET http://localhost:3000/${domain}/users

# Update User
# curl -b $cookieStore -X PUT http://localhost:3000/${domain}/users/[USER_ID] -d "isActive=[TRUE_OR_FALSE]"
