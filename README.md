# Key-Value Store Service

A simple REST API service for storing key-value pairs with user authentication and domain-based project separation.

**Live Service:** https://kv.srv.signalwerk.ch/

## Features

- JWT-based authentication
- Domain-based project separation
- Key-value storage with CRUD operations
- User management (admin features)
- SQLite database

## Database Structure

The service uses SQLite with three main tables:

### `users` Table
Stores user account information and permissions.
```sql
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL,              -- bcrypt hashed
    isActive BOOLEAN NOT NULL DEFAULT(FALSE),
    isAdmin BOOLEAN NOT NULL DEFAULT(FALSE),
    domain TEXT,                         -- default domain for user
    isDeleted BOOLEAN NOT NULL DEFAULT(FALSE),
    createdAt DATETIME DEFAULT(CURRENT_TIMESTAMP),
    modifiedAt DATETIME DEFAULT(CURRENT_TIMESTAMP)
)
```

### `domain` Table
Manages available projects/domains for data separation.
```sql
CREATE TABLE domain (
    name TEXT PRIMARY KEY,               -- domain identifier
    isDeleted BOOLEAN NOT NULL DEFAULT(FALSE),
    createdAt DATETIME DEFAULT(CURRENT_TIMESTAMP),
    modifiedAt DATETIME DEFAULT(CURRENT_TIMESTAMP)
)
```

### `store` Table
Contains the actual key-value data, scoped by user and domain.
```sql
CREATE TABLE store (
    userId INTEGER NOT NULL,
    domain TEXT NOT NULL,
    key TEXT NOT NULL,
    value TEXT,                          -- JSON or plain text values
    isDeleted BOOLEAN NOT NULL DEFAULT(FALSE),
    createdAt DATETIME DEFAULT(CURRENT_TIMESTAMP),
    modifiedAt DATETIME DEFAULT(CURRENT_TIMESTAMP),
    FOREIGN KEY(userId) REFERENCES users(id),
    UNIQUE(userId, domain, key)
)
```

## Admin Scripts

### `admin.sh` - List Users and Projects
```bash
# List all users and projects
./admin.sh

# List only users
./admin.sh users

# List only projects/domains
./admin.sh projects

# Create a new project/domain
./admin.sh create-project myproject

# Show help
./admin.sh help
```

### `test.sh` - API Testing
Comprehensive test script that demonstrates all API endpoints with sample data.

## Adding New Domains/Projects

To add a new domain/project, you have several options:

### Option 1: Using the admin script (recommended)
```bash
./admin.sh create-project your-project-name
```

### Option 2: Using curl directly
```bash
# 1. Get admin token
TOKEN=$(curl -s -X POST http://localhost:3000/editor/login \
             -H "Content-Type: application/json" \
             -d '{"username": "signalwerk", "password": "YOUR_PASSWORD"}' \
             | jq -r '.token')

# 2. Create domain
curl -H "Authorization: Bearer $TOKEN" \
     -X POST http://localhost:3000/admin/domains \
     -H "Content-Type: application/json" \
     -d '{"name": "your-project-name"}'
```

### Option 3: For live service
```bash
# Replace localhost:3000 with https://kv.srv.signalwerk.ch
curl -H "Authorization: Bearer $TOKEN" \
     -X POST https://kv.srv.signalwerk.ch/admin/domains \
     -H "Content-Type: application/json" \
     -d '{"name": "your-project-name"}'
```

Once created, you can immediately start using the new domain:
- `https://kv.srv.signalwerk.ch/your-project-name/data`
- `https://kv.srv.signalwerk.ch/your-project-name/login`

## API Endpoints

### Authentication

#### Login
```
POST /{domain}/login
Content-Type: application/json

{
  "username": "your_username",
  "password": "your_password"
}
```

#### Check Login Status
```
GET /{domain}/users/me
Authorization: Bearer {token}
```

### Data Operations

#### Get All Data
```
GET /{domain}/data
Authorization: Bearer {token}
```

#### Get Single Key
```
GET /{domain}/data/{key}
Authorization: Bearer {token}
```

#### Create/Update Data
```
POST /{domain}/data
Authorization: Bearer {token}
Content-Type: application/json

{
  "key": "your_key",
  "value": "your_value"
}
```

#### Update Data
```
PUT /{domain}/data/{key}
Authorization: Bearer {token}
Content-Type: application/json

{
  "value": "new_value"
}
```

#### Delete Key
```
DELETE /{domain}/data/{key}
Authorization: Bearer {token}
```

### User Management (Admin Only)

#### List Users
```
GET /{domain}/users
Authorization: Bearer {token}
```

#### Update User Status
```
PUT /{domain}/users/{userId}
Authorization: Bearer {token}
Content-Type: application/json

{
  "isActive": true
}
```

### Domain Management (Admin Only)

#### List Domains
```
GET /admin/domains
Authorization: Bearer {token}
```

#### Create Domain
```
POST /admin/domains
Authorization: Bearer {token}
Content-Type: application/json

{
  "name": "project_name"
}
```

#### Delete Domain
```
DELETE /admin/domains/{domain}
Authorization: Bearer {token}
```

## Getting Started

1. Install dependencies:
   ```bash
   npm install
   ```

2. Create a `.env` file:
   ```
   DB_USER_PASSWORD=your_admin_password
   JWT_SECRET=your_jwt_secret
   PORT=3000
   DB_PATH=/path/to/database.db
   ```

3. Start the server:
   ```bash
   npm start
   ```

4. For development:
   ```bash
   npm run dev
   ```

## Default Setup

- Default admin user: `signalwerk`
- Default domain: `editor`
- Admin user has access to all domains and user management features

## Environment Variables

- `DB_USER_PASSWORD`: Password for the default admin user
- `JWT_SECRET`: Secret key for JWT token signing
- `PORT`: Server port (default: 3000)
- `DB_PATH`: Path to SQLite database file 