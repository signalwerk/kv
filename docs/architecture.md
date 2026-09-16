# Architecture

A single Express app (`src/index.js`) backed by SQLite and authenticated with JWT.

## Access control

- **Domains** separate projects. A domain must exist (and not be deleted) before it can be used.
- **Admin users** can access all domains.
- **Regular users** can only access the domains listed in their `users.domain` field.
- Admin and active status are **re-checked in the database** on every protected request, so disabling a user takes effect immediately even though their token is still valid.

### User domain field

`users.domain` is a comma-separated list of the domains a user can access:

- Single domain: `"editor"`
- Multiple domains: `"editor,project1,project2"`
- No domains: `null` (no access)

## Database

SQLite with three tables. The tables are created on first start (when `users` does not exist yet), together with the domain `editor` and the admin user `signalwerk` (password from `DB_USER_PASSWORD`). There are **no migrations**: a schema change needs manual handling on existing databases.

All deletes are **soft deletes** (`isDeleted = TRUE`). A soft-deleted domain still blocks creating a new domain with the same name.

### `users`
```sql
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL,              -- bcrypt hashed
    isActive BOOLEAN NOT NULL DEFAULT(FALSE),
    isAdmin BOOLEAN NOT NULL DEFAULT(FALSE),
    domain TEXT,                         -- comma-separated list of accessible domains
    isDeleted BOOLEAN NOT NULL DEFAULT(FALSE),
    createdAt DATETIME DEFAULT(CURRENT_TIMESTAMP),
    modifiedAt DATETIME DEFAULT(CURRENT_TIMESTAMP)
)
```

### `domain`
```sql
CREATE TABLE domain (
    name TEXT PRIMARY KEY,               -- domain identifier
    isDeleted BOOLEAN NOT NULL DEFAULT(FALSE),
    createdAt DATETIME DEFAULT(CURRENT_TIMESTAMP),
    modifiedAt DATETIME DEFAULT(CURRENT_TIMESTAMP)
)
```

### `store`
Key-value data, scoped by user and domain.
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
