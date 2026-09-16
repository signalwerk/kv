# API Reference

Base URL: `https://kv.srv.signalwerk.ch` (locally `http://localhost:3000`).

All endpoints except `POST /login` need the header `Authorization: Bearer {token}`. Errors are returned as `{ "error": "..." }` with a matching HTTP status.

## Authentication

### Login
```
POST /login
Content-Type: application/json

{ "username": "your_username", "password": "your_password" }
```
Returns `{ "message": "...", "token": "..." }`. Tokens are valid for 90 days.

There is no registration endpoint. Administrators create users (see [Admin: Users](#users)).

### Check login status
```
GET /users/me
```
Returns `{ "isLoggedIn": true, "user": { "id", "username", "isAdmin" } }`.

## Data

Data is scoped to the **logged-in user** and the **domain**. You only ever see your own keys. You need access to the domain (see [Architecture](architecture.md#access-control)).

### Get all keys
```
GET /{domain}/data
```

### Get a single key
```
GET /{domain}/data/{key}
```

### Create or overwrite a key
```
POST /{domain}/data
Content-Type: application/json

{ "key": "your_key", "value": "your_value" }
```

### Update an existing key
```
PUT /{domain}/data/{key}
Content-Type: application/json

{ "value": "new_value" }
```
Returns 404 if the key does not exist.

### Delete a key (soft delete)
```
DELETE /{domain}/data/{key}
```

## Admin

All routes below need an active admin user.

### Users

#### List all users (including deleted ones)
```
GET /admin/users
```

#### Create a user
```
POST /admin/users
Content-Type: application/json

{
  "username": "new_username",
  "password": "password",
  "domain": "project_name",
  "isActive": true,
  "isAdmin": false
}
```
`domain` is optional and can be a comma-separated list. `isActive` defaults to `true` and `isAdmin` to `false`.

#### Update a user's status
```
PUT /admin/users/{userId}
Content-Type: application/json

{ "isActive": true, "isDeleted": false }
```
Send both fields. A missing `isDeleted` is treated as `false`.

#### Delete a user (soft delete)
```
DELETE /admin/users/{userId}
```

#### Grant domain access to a user
```
POST /admin/users/{userId}/domains
Content-Type: application/json

{ "domain": "project_name" }
```

#### Remove domain access from a user
```
DELETE /admin/users/{userId}/domains/{domain}
```

### Domains

#### List domains
```
GET /admin/domains
```

#### Create a domain
```
POST /admin/domains
Content-Type: application/json

{ "name": "project_name" }
```
The name is trimmed and lowercased.

#### Delete a domain (soft delete)
```
DELETE /admin/domains/{domain}
```

### Domain-scoped user routes

These also require access to `{domain}`.

#### List users with access to a domain
```
GET /{domain}/users
```

#### Activate or deactivate a user
```
PUT /{domain}/users/{userId}
Content-Type: application/json

{ "isActive": true }
```

## GUI

```
GET /_/
GET /{domain}/_/
```
Serves the minimal admin GUI (see [Administration](administration.md#admin-gui)).
