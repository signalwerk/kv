# Administration

## Admin GUI

A minimal viewer/editor is served at https://kv.srv.signalwerk.ch/_/ (users and domains) and at `/{domain}/_/`, for example https://kv.srv.signalwerk.ch/editor/_/ (also shows your data in that domain).

- Every user can log in and view or edit their own keys in that domain.
- Admins can also manage all users (active/deleted flags, domain access, creating users) and domains.

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
