# KV API - timetracker

Base URL: `https://kv.srv.signalwerk.ch/timetracker`

## Auth
```bash
# Login
POST /login
{"username": "user", "password": "pass"}
→ {"token": "jwt_token"}

# Use token in header: Authorization: Bearer <token>
```

## Data Operations
```bash
# Get all keys
GET /data
→ {"data": [{"key": "k1", "value": "v1", ...}, ...]}

# Get key
GET /data/:key
→ {"data": {"key": "k1", "value": "v1", ...}}

# Set key
POST /data
{"key": "k1", "value": "v1"}
→ {"data": {"key": "k1", "value": "v1", ...}}

# Update key
PUT /data/:key
{"value": "new_value"}
→ {"data": {"key": "k1", "value": "new_value", ...}}

# Delete key
DELETE /data/:key
→ {"message": "Key deleted"}
```

All data endpoints require `Authorization: Bearer <token>` header. 