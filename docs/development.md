# Development

## Setup

```bash
npm install
npm run dev            # nodemon, restarts on changes in src/
```

## Environment

Loaded from `.env` in the working directory.

| Variable           | Description                                                                  |
| ------------------ | ---------------------------------------------------------------------------- |
| `JWT_SECRET`       | **Required.** The server exits if it is not set.                             |
| `DB_PATH`          | SQLite file. Defaults to `/DATA/db/data.db` (the container path), so set it locally, e.g. `data.db`. |
| `DB_USER_PASSWORD` | Password for the admin user `signalwerk` created on first start. Also used by `admin.sh` and the tests. |
| `PORT`             | Defaults to `3000`.                                                          |

## Project structure

```
src/
  index.js        server: DB init, middleware, all routes
  gui.html        admin GUI served at /_/ and /{domain}/_/
  index.spec.js   jest spec (mostly placeholders)
tests/            bash integration test suites
test.sh           test runner
admin.sh          admin CLI
data/             JSON responses written by the tests
docs/             documentation
```

Admin routes (`/admin/*`) must be registered before the `/:domain/*` routes, otherwise `admin` would be treated as a domain.

## Tests

The integration tests call a running server on `http://localhost:3000` with `curl` and `jq`, and use `sqlite3` to clean up test data.

```bash
npm run dev                     # in one terminal
./test.sh                       # all suites
./test.sh --suite auth          # auth | data | admin | domain-access
./test.sh --list
```

Responses are saved as JSON in `data/`. See [tests/README.md](../tests/README.md) for details.

`npm test` runs jest on `src/index.spec.js`. That spec is mostly placeholders.

## Docker

```bash
docker compose up --build
```

- Only `package*.json` and `src/` are copied into the image, and only production dependencies are installed.
- The app listens on port `5060`.
- The database lives in the volume `/DATA/key-value/db` (mounted to `/DATA/db` in the container).
- `JWT_SECRET` and `DB_USER_PASSWORD` are not set in `docker-compose.yml`. Provide them to the container another way, e.g. with `env_file`.
