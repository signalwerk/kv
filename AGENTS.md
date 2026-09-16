# AGENTS.md

Working notes for coding agents on this repo. **Every agent must update this file** whenever it makes meaningful changes, clarifies an assumption, or discovers new project context. Keep it short and accurate: fix or remove stale entries instead of appending contradictions.

## What this is

A small key-value store REST API (Express + SQLite + JWT). Data is split by **domain** (project) and scoped per user. Live at https://kv.srv.signalwerk.ch/. [README.md](README.md) is a short overview. Technical docs are in [docs/](docs/): `api.md`, `architecture.md`, `administration.md`, `development.md`. [api.md](api.md) at the root is a short client reference for the `timetracker` domain.

## Structure

- `src/index.js`: the whole server in one file (DB init, middleware, all routes). Exports `app`, and only calls `listen` when `NODE_ENV !== "test"`.
- `src/gui.html`: minimal admin GUI (vanilla JS, no build), served at `/_/` (admin overview) and `/{domain}/_/` (also shows own data in that domain).
- `src/index.spec.js`: Jest/supertest spec (mostly placeholders).
- `test.sh` + `tests/*.sh`: the real integration tests (bash + curl + jq) against a running server.
- `admin.sh`: admin CLI. Hits the **live** endpoint by default (`endpoint=` at the top).
- `data/`: JSON output written by the test scripts. Not app data.
- `data.db`: local SQLite DB (gitignored).
- `docs/`: technical documentation. Update it when routes, schema, env vars or workflows change.

Only `src/` and `package*.json` go into the Docker image. Keep runtime code in `src/`.

## Commands

```bash
npm install
npm run dev      # nodemon, watches src/
npm start        # node src/index.js
./test.sh        # integration tests; needs server on http://localhost:3000, plus jq and sqlite3
./test.sh --suite auth|data|admin|domain-access
npm test         # jest (placeholder spec, not meaningful coverage)
docker compose up --build   # port 5060, DB volume /DATA/key-value/db -> /DATA/db
```

## Environment (`.env`, loaded via dotenv from the working directory)

- `JWT_SECRET`: required, or the process exits.
- `DB_PATH`: SQLite file. Default `/DATA/db/data.db` (the container path), so set it for local dev.
- `DB_USER_PASSWORD`: password for the seeded admin `signalwerk`. Also used by `admin.sh` and the tests.
- `PORT`: default 3000. Docker uses 5060.

Never copy `.env` or `*.db` into the image (see `.dockerignore`).

## Data model & key decisions

- Tables: `users`, `domain`, `store`. They are created only if the `users` table doesn't exist yet. **There are no migrations.** Schema changes need manual handling for existing DBs.
- First init seeds the domain `editor` and the admin user `signalwerk`.
- **Soft deletes everywhere** (`isDeleted`). Queries must filter `isDeleted = FALSE` where appropriate. `POST /admin/domains` fails with UNIQUE if a soft-deleted domain has the same name (the tests hard-delete test rows via sqlite3 for this reason).
- `users.domain` is a **comma-separated list** of the domains a user may access. Admins can access all domains.
- `store` is unique on `(userId, domain, key)`. The data routes only ever return the **caller's own** keys. There is no route to read other users' data.
- There is no registration route. Admins create users (`POST /admin/users`).
- JWTs last 90 days. `isAdmin`/`isActive` are re-checked against the DB on each protected request, not trusted from the token.
- CORS reflects any Origin with credentials.

## Routing gotchas

- `/admin/*` routes must be registered **before** the `/:domain/*` routes, or `admin` gets treated as a domain.
- `POST /login` and `GET /users/me` are not domain-scoped.
- `/_` and `/:domain/_` (GUI) redirect to the trailing-slash form. The page reads the domain from `location.pathname` and calls the API with absolute paths, so it assumes the app is served at the root path.

## Conventions

- CommonJS, callback-style `sqlite3`, 2-space indent, double quotes, trailing commas.
- Errors are returned as `{ error: message }` JSON with a matching status.
- Keep the admin GUI minimal: one HTML file, no framework, no build step. It should only use existing API routes. It must cover everything `admin.sh` can do: when adding an admin route or `admin.sh` command, add it to the GUI too.
- Commit messages are prefixed `MOD:`, `FIX:` or `ADD:`.
