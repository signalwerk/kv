# Administration

## Admin GUI

A minimal viewer/editor for admins.

- **https://kv.srv.signalwerk.ch/_/**: all domains and users. Create or delete domains; create users; change active/admin/deleted and domain access.
- **`/{domain}/_/`** (e.g. https://kv.srv.signalwerk.ch/editor/_/): only that domain. Your own keys in it, plus (for admins) the users with access: active, admin, remove access, grant access to another user. Non-admins can use this page for their own data.

Rows in the tables (users, domains, keys) change nothing until you click **save** on that row. The save sends the whole row: active, admin, deleted and domain access for users; value or delete for keys; delete for domains. Domain access in the users table is edited with the dropdown and `+`, and removed with `×`; those changes are also only stored on **save**. Changed rows are highlighted. You are warned before unsaved changes would be lost, whether by saving another row or by leaving the page. The forms below the tables (create domain, create user, add key, grant access) act when submitted.

To avoid locking yourself out, you cannot deactivate, delete or remove admin rights from your own user. The API enforces this, and the GUI disables those controls.

## `admin.sh`

A command-line wrapper around the admin API. It reads `DB_USER_PASSWORD` from `.env` and logs in as `signalwerk`. It needs `curl` and `jq`.

> The endpoint at the top of the script points to the **live service** (`https://kv.srv.signalwerk.ch`). Change it to `http://localhost:3000` for local use.

```bash
./admin.sh help                                  # show help (also the default)
./admin.sh all                                   # list users and domains
./admin.sh users                                 # list users
./admin.sh projects                              # list domains
./admin.sh create-project myproject              # create a domain
./admin.sh create-user <username> <password> [domain] [active] [admin]
./admin.sh delete-user 5
./admin.sh activate-user 5
./admin.sh deactivate-user 5
./admin.sh add-user-domain 2 myproject           # give user 2 access to myproject
./admin.sh remove-user-domain 2 myproject
```

## Common tasks

### Onboard a new project

1. Create the domain: `./admin.sh create-project project_name`
2. Create a user: `./admin.sh create-user username password project_name true false`
3. Or grant an existing user access: `./admin.sh add-user-domain user_id project_name`

The user can then log in and use `https://kv.srv.signalwerk.ch/project_name/data`.

### Using curl directly

```bash
TOKEN=$(curl -s -X POST https://kv.srv.signalwerk.ch/login \
  -H "Content-Type: application/json" \
  -d '{"username": "your_username", "password": "your_password"}' | jq -r '.token')

curl -H "Authorization: Bearer $TOKEN" \
     -X POST https://kv.srv.signalwerk.ch/admin/domains \
     -H "Content-Type: application/json" \
     -d '{"name": "project_name"}'
```

See the [API reference](api.md) for all endpoints.
