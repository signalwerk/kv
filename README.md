# Key-Value Store Service

A simple REST API for storing key-value pairs, with user authentication and data separated by project (domain).

**Live service:** https://kv.srv.signalwerk.ch/
**Admin:** https://kv.srv.signalwerk.ch/_/

## Features

- Key-value storage per user and domain
- JWT authentication
- Access control per domain, and users can access several domains
- User and domain management for admins
- Minimal admin GUI at `/_/` and `/{domain}/_/`
- SQLite database

## Quick start

User accounts are created by an administrator. Once you have one and access to a domain:

```bash
TOKEN=$(curl -s -X POST https://kv.srv.signalwerk.ch/login \
  -H "Content-Type: application/json" \
  -d '{"username": "your_username", "password": "your_password"}' | jq -r '.token')

# store a value
curl -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -X POST https://kv.srv.signalwerk.ch/your-project/data \
  -d '{"key": "hello", "value": "world"}'

# read all values
curl -H "Authorization: Bearer $TOKEN" https://kv.srv.signalwerk.ch/your-project/data
```

## Run locally

```bash
npm install
npm run dev
```

Set `JWT_SECRET`, `DB_PATH` and `DB_USER_PASSWORD` in `.env` first (see [Development](docs/development.md)).

## Documentation

- [API reference](docs/api.md)
- [Architecture](docs/architecture.md): access control and database
- [Administration](docs/administration.md): admin GUI, `admin.sh`, onboarding projects
- [Development](docs/development.md): setup, tests, Docker
