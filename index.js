require("dotenv").config();
const express = require("express");
const session = require("express-session");
const passport = require("passport");
const LocalStrategy = require("passport-local").Strategy;
const bcrypt = require("bcryptjs");
const sqlite3 = require("sqlite3").verbose();

const PORT = process.env.PORT || 3000; // Use port from .env or default to 3000

// Initialize SQLite database

const dbPath = process.env.DB_PATH || "/DATA/db/data.db";

const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error("Error opening database:", err.message);
    return;
  }
  console.log("Connected to the SQLite database.");

  db.get(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='users'",
    (err, table) => {
      if (err) {
        console.error("Error checking users table:", err.message);
        return;
      }

      if (!table) {
        db.serialize(() => {
          db.run(
            `CREATE TABLE users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL UNIQUE,
                password TEXT NOT NULL,
                isActive BOOLEAN NOT NULL DEFAULT(FALSE),
                isAdmin BOOLEAN NOT NULL DEFAULT(FALSE),
                domain TEXT,
                isDeleted BOOLEAN NOT NULL DEFAULT(FALSE),
                createdAt DATETIME DEFAULT(CURRENT_TIMESTAMP),
                modifiedAt DATETIME DEFAULT(CURRENT_TIMESTAMP)
            )`,
            (err) => {
              if (err) {
                console.error("Error creating users table:", err.message);
                return;
              }
            }
          );

          db.run(
            `CREATE TABLE store (
                  userId INTEGER NOT NULL,
                  domain TEXT NOT NULL,
                  key TEXT NOT NULL,
                  value TEXT,
                  isDeleted BOOLEAN NOT NULL DEFAULT(FALSE),
                  createdAt DATETIME DEFAULT(CURRENT_TIMESTAMP),
                  modifiedAt DATETIME DEFAULT(CURRENT_TIMESTAMP),
                  FOREIGN KEY(userId) REFERENCES users(id),
                  UNIQUE(userId, domain, key)
              )`,
            (err) => {
              if (err) {
                console.error("Error creating store table:", err.message);
                return;
              }
            }
          );

          db.run(
            `CREATE TABLE domain (
                  name TEXT PRIMARY KEY,
                  isDeleted BOOLEAN NOT NULL DEFAULT(FALSE),
                  createdAt DATETIME DEFAULT(CURRENT_TIMESTAMP),
                  modifiedAt DATETIME DEFAULT(CURRENT_TIMESTAMP)
              )`,
            (err) => {
              if (err) {
                console.error("Error creating domain table:", err.message);
                return;
              }
              db.run(
                `INSERT OR IGNORE INTO domain (name) VALUES ('editor')`,
                (err) => {
                  if (err) {
                    console.error(
                      "Error inserting into domain table:",
                      err.message
                    );
                  }
                }
              );
            }
          );

          // Add default user
          bcrypt.hash(
            process.env.DB_USER_PASSWORD,
            10,
            (err, hashedPassword) => {
              if (err) {
                console.error("Error hashing password:", err.message);
                return;
              }
              db.run(
                `INSERT INTO users (username, password, isActive, isAdmin, domain) VALUES ('signalwerk', ?, TRUE, TRUE, 'editor')`,
                hashedPassword,
                (err) => {
                  if (err) {
                    console.error("Error inserting default user:", err.message);
                  }
                }
              );
            }
          );
        });
      }
    }
  );
});

// Express application setup
const app = express();
app.use(express.json());
app.use(
  session({
    secret: "secret",
    resave: false,
    saveUninitialized: false,
    cookie: { maxAge: 90 * 24 * 60 * 60 * 1000 }, // 3 months
  })
);

app.use(passport.initialize());
app.use(passport.session());
app.set("json spaces", 2);

// Custom middleware to allow CORS from everywhere
app.use((req, res, next) => {
  // const allowedOrigins = ['http://editor.localhost.signalwerk.ch:3001', 'https://anotherdomain.com']; // Add allowed domains here
  const origin = req.headers.origin;
  // if (allowedOrigins.includes(origin)) {
  res.header("Access-Control-Allow-Origin", origin);
  // }
  res.header(
    "Access-Control-Allow-Headers",
    "Origin, X-Requested-With, Content-Type, Accept"
  );
  res.header("Access-Control-Allow-Credentials", true);
  if (req.method === "OPTIONS") {
    res.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE");
    return res.status(200).json({});
  }
  next();
});

// Passport Local Strategy
passport.use(
  new LocalStrategy((username, password, done) => {
    db.get(
      "SELECT id, username, password, isActive FROM users WHERE username = ? AND isDeleted = FALSE",
      [username],
      (err, row) => {
        if (err) {
          return done(err);
        }
        if (!row) {
          return done(null, false, { message: "Incorrect username." });
        }
        if (!row.isActive) {
          return done(null, false, { message: "User not active." });
        }

        bcrypt.compare(password, row.password, (err, res) => {
          if (res) {
            return done(null, row); // passwords match
          } else {
            return done(null, false, { message: "Incorrect password." }); // passwords do not match
          }
        });
      }
    );
  })
);

passport.serializeUser((user, done) => {
  done(null, user.id);
});

passport.deserializeUser((id, done) => {
  db.get(
    "SELECT id, username, isActive, isAdmin FROM users WHERE id = ? AND isDeleted = FALSE",
    [id],
    (err, row) => {
      if (!err) done(null, row);
      else done(err, null);
    }
  );
});

// Middleware to check domain
function checkDomain(req, res, next) {
  const domain = req.params.domain;
  db.get(
    "SELECT name FROM domain WHERE name = ? AND isDeleted = FALSE",
    [domain],
    (err, row) => {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      if (row) {
        next();
      } else {
        res.status(404).json({ error: "Domain not found" });
      }
    }
  );
}

// Helper function to check if user is admin
function isAdmin(req, res, next) {
  if (req.isAuthenticated() && req.user.isAdmin) {
    next();
  } else {
    res.status(403).json({ error: "Access denied" });
  }
}

// Routes
app.post("/:domain/login", checkDomain, (req, res, next) => {
  passport.authenticate("local", (err, user, info) => {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    if (!user) {
      return res.status(401).json({ error: info.message });
    }
    req.logIn(user, (err) => {
      if (err) {
        return res.status(500).json({ error: err.message });
      }
      // The user is successfully authenticated, send a response
      return res.status(200).json({ message: "Logged in successfully" });
    });
  })(req, res, next);
});

app.post("/:domain/register", checkDomain, async (req, res) => {
  const { username, password } = req.body;
  const domain = req.params.domain;
  const hashedPassword = await bcrypt.hash(password, 10);

  db.run(
    "INSERT INTO users (username, password, domain) VALUES (?, ?, ?)",
    [username, hashedPassword, domain],
    function (err) {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      res.status(201).json({ message: "User created", id: this.lastID });
    }
  );
});

app.get("/:domain/data", checkDomain, (req, res) => {
  if (req.isAuthenticated()) {
    const userId = req.user.id;
    const domain = req.params.domain;
    db.all(
      "SELECT key, value, isDeleted, createdAt, modifiedAt FROM store WHERE userId = ? AND domain = ? AND isDeleted = FALSE",
      [userId, domain],
      (err, rows) => {
        if (err) {
          res.status(500).json({ error: err.message });
          return;
        }
        if (rows) {
          res.json({ data: rows }); // Return the single row as an object
        } else {
          res.status(404).json({ error: "No data found" }); // Handle case where no row is found
        }
      }
    );
  } else {
    res.status(401).json({ error: "Unauthorized" });
  }
});

app.post("/:domain/data", checkDomain, (req, res) => {
  if (req.isAuthenticated()) {
    console.log("posting data");
    const userId = req.user.id;
    const domain = req.params.domain;
    const { key, value } = req.body;
    db.run(
      `INSERT INTO store(userId, domain, key, value, isDeleted) 
        VALUES(?, ?, ?, ?, FALSE)
        ON CONFLICT(userId, domain, key)
        DO UPDATE SET value = excluded.value, isDeleted = FALSE, modifiedAt = CURRENT_TIMESTAMP`,
      [userId, domain, key, value],
      function (err) {
        if (err) {
          res.status(500).json({ error: err.message });
          return;
        }
        const lastId = this.lastID;
        db.get(
          "SELECT * FROM store WHERE userId = ? AND domain = ? AND isDeleted = FALSE",
          [userId, domain],
          (err, row) => {
            if (err) {
              res.status(500).json({ error: err.message });
            } else {
              const { userId, domain, ...data } = row;
              res.status(201).json({ data });
            }
          }
        );
      }
    );
  } else {
    res.status(401).json({ error: "Unauthorized" });
  }
});

app.delete("/:domain/data/:key", checkDomain, (req, res) => {
  if (req.isAuthenticated()) {
    const userId = req.user.id;
    const domain = req.params.domain;
    const key = req.params.key;

    db.run(
      "UPDATE store SET isDeleted = TRUE, modifiedAt = CURRENT_TIMESTAMP WHERE userId = ? AND domain = ? AND key = ? AND isDeleted = FALSE",
      [userId, domain, key],
      function (err) {
        if (err) {
          res.status(500).json({ error: err.message });
          return;
        }
        if (this.changes === 0) {
          res.status(404).json({ message: "Key not found." });
        } else {
          res.json({ message: "Key deleted" });
        }
      }
    );
  } else {
    res.status(401).json({ error: "Unauthorized" });
  }
});

app.put("/:domain/data/:key", checkDomain, (req, res) => {
  if (req.isAuthenticated()) {
    const userId = req.user.id;
    const domain = req.params.domain;
    const key = req.params.key;
    const { value } = req.body; // New value for the key

    db.run(
      "UPDATE store SET value = ?, modifiedAt = CURRENT_TIMESTAMP WHERE userId = ? AND domain = ? AND key = ? AND isDeleted = FALSE",
      [value, userId, domain, key],
      function (err) {
        if (err) {
          res.status(500).json({ error: err.message });
          return;
        }
        if (this.changes === 0) {
          res
            .status(404)
            .json({ message: "Key not found or no update needed." });
        } else {
          db.get(
            "SELECT * FROM store WHERE userId = ? AND domain = ? AND isDeleted = FALSE",
            [userId, domain],
            (err, row) => {
              if (err) {
                res.status(500).json({ error: err.message });
              } else {
                const { userId, domain, ...data } = row;
                res.json({ data });
              }
            }
          );
        }
      }
    );
  } else {
    res.status(401).json({ error: "Unauthorized" });
  }
});

app.get("/:domain/users", checkDomain, isAdmin, (req, res) => {
  const domain = req.params.domain;

  db.all(
    "SELECT id, username, isActive FROM users WHERE domain = ? AND isDeleted = FALSE",
    [domain],
    (err, rows) => {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      res.json({ users: rows });
    }
  );
});

app.put("/:domain/users/:userId", checkDomain, isAdmin, (req, res) => {
  const { isActive } = req.body;
  const userId = req.params.userId;

  db.run(
    "UPDATE users SET isActive = ? WHERE id = ? AND isDeleted = FALSE",
    [isActive, userId],
    function (err) {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      res.json({ message: "User updated", changes: this.changes });
    }
  );
});

// Route to check if the user is logged in
app.get("/:domain/users/me", checkDomain, (req, res) => {
  if (req.isAuthenticated()) {
    // User is logged in
    res.json({
      isLoggedIn: true,
      user: {
        id: req.user.id,
        username: req.user.username,
        isActive: req.user.isActive,
        isAdmin: req.user.isAdmin,
      },
    });
  } else {
    // User is not logged in
    res.json({ isLoggedIn: false });
  }
});

// Start server if not running tests
if (process.env.NODE_ENV !== "test") {
  app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

module.exports = app; // Export for testing
