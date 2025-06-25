#!/bin/bash

# Test script for domain access control
set -e

domain="editor"
test_domain="testproject"
base_url="http://localhost:3000"

echo "🧪 Testing Domain Access Control"
echo "================================="

# Start by creating a test domain as admin
echo "1. Getting admin token..."
admin_token=$(curl -s -X POST $base_url/$domain/login \
             -H "Content-Type: application/json" \
             -d '{"username": "signalwerk", "password": "'$DB_USER_PASSWORD'"}' \
             | jq -r '.token')

if [ "$admin_token" = "null" ] || [ -z "$admin_token" ]; then
    echo "❌ Failed to get admin token"
    exit 1
fi
echo "✅ Admin token acquired"

# Create test domain
echo "2. Creating test domain '$test_domain'..."
curl -s -H "Authorization: Bearer $admin_token" \
     -X POST $base_url/admin/domains \
     -H "Content-Type: application/json" \
     -d "{\"name\": \"$test_domain\"}" > /dev/null
echo "✅ Test domain created"

# Register a new test user
echo "3. Registering test user..."
register_response=$(curl -s -X POST $base_url/$domain/register \
                   -H "Content-Type: application/json" \
                   -d '{"username": "testuser", "password": "testpass"}')
echo "✅ Test user registered: $register_response"

# Login as test user
echo "4. Logging in as test user..."
user_token=$(curl -s -X POST $base_url/$domain/login \
            -H "Content-Type: application/json" \
            -d '{"username": "testuser", "password": "testpass"}' \
            | jq -r '.token')

if [ "$user_token" = "null" ] || [ -z "$user_token" ]; then
    echo "❌ Failed to get user token"
    exit 1
fi
echo "✅ User token acquired"

# Test 1: User should have access to editor domain (where they registered)
echo "5. Testing access to editor domain (should work)..."
response=$(curl -s -w "%{http_code}" -o /dev/null \
          -H "Authorization: Bearer $user_token" \
          -X GET $base_url/$domain/data)

if [ "$response" = "200" ]; then
    echo "✅ User can access editor domain"
else
    echo "❌ User cannot access editor domain (got $response)"
fi

# Test 2: User should NOT have access to test domain (they weren't granted access)
echo "6. Testing access to test domain (should fail)..."
response=$(curl -s -w "%{http_code}" -o /dev/null \
          -H "Authorization: Bearer $user_token" \
          -X GET $base_url/$test_domain/data)

if [ "$response" = "403" ]; then
    echo "✅ User correctly denied access to test domain"
else
    echo "❌ User should not have access to test domain (got $response)"
fi

# Test 3: Admin grants user access to test domain
echo "7. Admin granting user access to test domain..."
# First get the user ID
user_id=$(curl -s -H "Authorization: Bearer $admin_token" \
         -X GET $base_url/$domain/users | jq -r '.users[] | select(.username=="testuser") | .id')

curl -s -H "Authorization: Bearer $admin_token" \
     -X POST $base_url/admin/users/$user_id/domains \
     -H "Content-Type: application/json" \
     -d "{\"domain\": \"$test_domain\"}" > /dev/null
echo "✅ Domain access granted"

# Test 4: User should now have access to test domain
echo "8. Testing access to test domain after grant (should work)..."
response=$(curl -s -w "%{http_code}" -o /dev/null \
          -H "Authorization: Bearer $user_token" \
          -X GET $base_url/$test_domain/data)

if [ "$response" = "200" ]; then
    echo "✅ User can now access test domain"
else
    echo "❌ User still cannot access test domain (got $response)"
fi

# Test 5: Admin should always have access to all domains
echo "9. Testing admin access to test domain (should work)..."
response=$(curl -s -w "%{http_code}" -o /dev/null \
          -H "Authorization: Bearer $admin_token" \
          -X GET $base_url/$test_domain/data)

if [ "$response" = "200" ]; then
    echo "✅ Admin can access test domain"
else
    echo "❌ Admin cannot access test domain (got $response)"
fi

# Cleanup
echo "10. Cleaning up..."
curl -s -H "Authorization: Bearer $admin_token" \
     -X DELETE $base_url/admin/domains/$test_domain > /dev/null
echo "✅ Test domain deleted"

echo ""
echo "🎉 Domain access control tests completed!" 