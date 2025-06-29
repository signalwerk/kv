require("dotenv").config();
const express = require("express");
const bcrypt = require("bcryptjs");
const sqlite3 = require("sqlite3").verbose();
const jwt = require("jsonwebtoken"); // Added for JWT

const PORT = process.env.PORT || 3000; // Use port from .env or default to 3000

if (!process.env.JWT_SECRET) {
  console.error("JWT_SECRET not set. Exit.");
  process.exit(1);
}

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
            },
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
            },
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
                      err.message,
                    );
                  }
                },
              );
            },
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
                },
              );
            },
          );
        });
      }
    },
  );
});

// Express application setup
const app = express();
app.use(express.json());

app.set("json spaces", 2);

// Custom middleware to allow CORS from everywhere
app.use((req, res, next) => {
  const origin = req.headers.origin;

  res.header("Access-Control-Allow-Origin", origin); // Allow any origin or specify your allowed origins
  res.header(
    "Access-Control-Allow-Headers",
    "Origin, X-Requested-With, Content-Type, Accept, Authorization", // Add Authorization here
  );
  res.header("Access-Control-Allow-Credentials", true);

  if (req.method === "OPTIONS") {
    res.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE");
    return res.status(200).json({});
  }

  next();
});

// Helper function to generate JWT
function generateToken(user) {
  return jwt.sign(
    { id: user.id, username: user.username, isAdmin: user.isAdmin },
    process.env.JWT_SECRET,
    {
      expiresIn: "90d",
    },
  );
}

// Helper function to verify JWT
function verifyToken(req, res, next) {
  const token = req.headers.authorization?.split(" ")[1];
  if (!token) {
    return res.status(401).json({ error: "Unauthorized, no token provided" });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    res.status(401).json({ error: "Unauthorized, invalid token" });
  }
}

// Helper function to check if user is admin (SECURE VERSION - checks database)
function isAdmin(req, res, next) {
  if (!req.user || !req.user.id) {
    return res.status(403).json({ error: "Access denied" });
  }

  // Always check current admin status from database for security
  db.get(
    "SELECT isAdmin, isActive FROM users WHERE id = ? AND isDeleted = FALSE",
    [req.user.id],
    (err, user) => {
      if (err) {
        return res.status(500).json({ error: err.message });
      }

      if (!user || !user.isActive || !user.isAdmin) {
        return res
          .status(403)
          .json({ error: "Access denied. Admin privileges required." });
      }

      next();
    },
  );
}

// Helper function to check if user has access to a domain
function checkUserDomainAccess(req, res, next) {
  const requestedDomain = req.params.domain;
  const userId = req.user.id;

  // Get user's current status including admin status and domain access
  db.get(
    "SELECT domain, isAdmin, isActive FROM users WHERE id = ? AND isDeleted = FALSE",
    [userId],
    (err, row) => {
      if (err) {
        return res.status(500).json({ error: err.message });
      }

      if (!row || !row.isActive) {
        return res.status(404).json({ error: "User not found or inactive" });
      }

      // Admin users have access to all domains (check DB, not JWT)
      if (row.isAdmin) {
        return next();
      }

      // Parse comma-separated domains
      const userDomains = row.domain
        ? row.domain.split(",").map((d) => d.trim())
        : [];

      if (userDomains.includes(requestedDomain)) {
        next();
      } else {
        res.status(403).json({ error: "Access denied to this domain" });
      }
    },
  );
}

// Middleware to check domain exists and user has access
function checkDomainAndAccess(req, res, next) {
  const domain = req.params.domain;

  // First check if domain exists
  db.get(
    "SELECT name FROM domain WHERE name = ? AND isDeleted = FALSE",
    [domain],
    (err, row) => {
      if (err) {
        return res.status(500).json({ error: err.message });
      }
      if (!row) {
        return res.status(404).json({ error: "Domain not found" });
      }

      // Domain exists, now check user access
      checkUserDomainAccess(req, res, next);
    },
  );
}

// Middleware to check domain exists (for login/register - no auth required)
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
    },
  );
}

// Admin routes (must be before domain-specific routes)
app.get("/admin/domains", verifyToken, isAdmin, (req, res) => {
  db.all(
    "SELECT name, createdAt, modifiedAt FROM domain WHERE isDeleted = FALSE ORDER BY name",
    [],
    (err, rows) => {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      res.json({ domains: rows });
    },
  );
});

// Admin route to list ALL users (not domain-specific)
app.get("/admin/users", verifyToken, isAdmin, (req, res) => {
  db.all(
    "SELECT id, username, isActive, isAdmin, isDeleted, domain, createdAt, modifiedAt FROM users ORDER BY username",
    [],
    (err, rows) => {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      res.json({ users: rows });
    },
  );
});

// Admin endpoint to update user status (activate/deactivate)
app.put("/admin/users/:userId", verifyToken, isAdmin, (req, res) => {
  const { isActive, isDeleted } = req.body;
  const userId = req.params.userId;

  db.run(
    "UPDATE users SET isActive = ?, modifiedAt = CURRENT_TIMESTAMP, isDeleted = ? WHERE id = ?",
    [isActive, isDeleted || false, userId],
    function (err) {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      res.json({ message: "User updated", changes: this.changes });
    },
  );
});

app.post("/admin/domains", verifyToken, isAdmin, (req, res) => {
  const { name } = req.body;

  if (!name || typeof name !== "string" || name.trim().length === 0) {
    return res.status(400).json({ error: "Domain name is required" });
  }

  const domainName = name.trim().toLowerCase();

  db.run("INSERT INTO domain (name) VALUES (?)", [domainName], function (err) {
    if (err) {
      if (err.message.includes("UNIQUE constraint failed")) {
        res.status(409).json({ error: "Domain already exists" });
      } else {
        res.status(500).json({ error: err.message });
      }
      return;
    }
    res.status(201).json({
      message: "Domain created successfully",
      domain: { name: domainName },
    });
  });
});

app.delete("/admin/domains/:domain", verifyToken, isAdmin, (req, res) => {
  const domainName = req.params.domain;

  // Check if domain exists and is not already deleted
  db.get(
    "SELECT name FROM domain WHERE name = ? AND isDeleted = FALSE",
    [domainName],
    (err, row) => {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }

      if (!row) {
        res.status(404).json({ error: "Domain not found" });
        return;
      }

      // Soft delete the domain
      db.run(
        "UPDATE domain SET isDeleted = TRUE, modifiedAt = CURRENT_TIMESTAMP WHERE name = ?",
        [domainName],
        function (err) {
          if (err) {
            res.status(500).json({ error: err.message });
            return;
          }
          res.json({ message: "Domain deleted successfully" });
        },
      );
    },
  );
});

// Admin endpoint to manage user domains
app.post("/admin/users/:userId/domains", verifyToken, isAdmin, (req, res) => {
  const { userId } = req.params;
  const { domain } = req.body;

  if (!domain) {
    return res.status(400).json({ error: "Domain is required" });
  }

  // First check if domain exists
  db.get(
    "SELECT name FROM domain WHERE name = ? AND isDeleted = FALSE",
    [domain],
    (err, row) => {
      if (err) {
        return res.status(500).json({ error: err.message });
      }

      if (!row) {
        return res.status(404).json({ error: "Domain not found" });
      }

      addDomainToUser(userId, domain, (err, result) => {
        if (err) {
          return res.status(500).json({ error: err.message });
        }
        res.json(result);
      });
    },
  );
});

app.delete(
  "/admin/users/:userId/domains/:domain",
  verifyToken,
  isAdmin,
  (req, res) => {
    const { userId, domain } = req.params;

    removeDomainFromUser(userId, domain, (err, result) => {
      if (err) {
        return res.status(500).json({ error: err.message });
      }
      res.json(result);
    });
  },
);

// Admin endpoint to create new user
app.post("/admin/users", verifyToken, isAdmin, (req, res) => {
  const {
    username,
    password,
    domain,
    isActive = true,
    isAdmin = false,
  } = req.body;

  if (!username || !password) {
    return res
      .status(400)
      .json({ error: "Username and password are required" });
  }

  bcrypt.hash(password, 10, (err, hashedPassword) => {
    if (err) {
      return res.status(500).json({ error: "Error hashing password" });
    }

    db.run(
      "INSERT INTO users (username, password, domain, isActive, isAdmin) VALUES (?, ?, ?, ?, ?)",
      [username, hashedPassword, domain || null, isActive, isAdmin],
      function (err) {
        if (err) {
          if (err.message.includes("UNIQUE constraint failed")) {
            res.status(409).json({ error: "Username already exists" });
          } else {
            res.status(500).json({ error: err.message });
          }
          return;
        }
        res.status(201).json({
          message: "User created successfully",
          user: {
            id: this.lastID,
            username: username,
            isActive: isActive,
            isAdmin: isAdmin,
            domain: domain,
          },
        });
      },
    );
  });
});

// Admin endpoint to delete user (soft delete)
app.delete("/admin/users/:userId", verifyToken, isAdmin, (req, res) => {
  const { userId } = req.params;

  // Check if user exists and is not already deleted
  db.get(
    "SELECT id, username FROM users WHERE id = ? AND isDeleted = FALSE",
    [userId],
    (err, row) => {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }

      if (!row) {
        res.status(404).json({ error: "User not found" });
        return;
      }

      // Soft delete the user
      db.run(
        "UPDATE users SET isDeleted = TRUE, modifiedAt = CURRENT_TIMESTAMP WHERE id = ?",
        [userId],
        function (err) {
          if (err) {
            res.status(500).json({ error: err.message });
            return;
          }
          res.json({ message: "User deleted successfully" });
        },
      );
    },
  );
});

// Routes
app.post("/login", async (req, res) => {
  // ... existing login code, replace session handling with JWT ...
  const { username, password } = req.body;

  db.get(
    "SELECT id, username, password, isActive, isAdmin FROM users WHERE username = ? AND isDeleted = FALSE",
    [username],
    (err, user) => {
      if (err) {
        return res.status(500).json({ error: err.message });
      }
      if (!user || !user.isActive) {
        return res
          .status(401)
          .json({ error: "Incorrect username or user not active." });
      }

      bcrypt.compare(password, user.password, (err, result) => {
        if (result) {
          const token = generateToken(user);
          res.json({ message: "Logged in successfully", token });
        } else {
          res.status(401).json({ error: "Incorrect password." });
        }
      });
    },
  );
});

app.post("/register", async (req, res) => {
  const { username, password } = req.body;
  const hashedPassword = await bcrypt.hash(password, 10);

  db.run(
    "INSERT INTO users (username, password, isActive) VALUES (?, ?, FALSE)",
    [username, hashedPassword],
    function (err) {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      res.status(201).json({ message: "User created", id: this.lastID });
    },
  );
});

app.get("/:domain/data", verifyToken, checkDomainAndAccess, (req, res) => {
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
    },
  );
});

app.post("/:domain/data", verifyToken, checkDomainAndAccess, (req, res) => {
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
        },
      );
    },
  );
});

app.get("/:domain/data/:key", verifyToken, checkDomainAndAccess, (req, res) => {
  const userId = req.user.id;
  const domain = req.params.domain;
  const key = req.params.key;
  db.get(
    "SELECT * FROM store WHERE userId = ? AND domain = ? AND key = ? AND isDeleted = FALSE LIMIT 1",
    [userId, domain, key],
    (err, row) => {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      if (row) {
        const { userId, domain, ...data } = row;
        res.json({ data }); // Return the single row as an object
      } else {
        res.status(404).json({ error: "No data found" }); // Handle case where no row is found
      }
    },
  );
});

app.delete(
  "/:domain/data/:key",
  verifyToken,
  checkDomainAndAccess,
  (req, res) => {
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
      },
    );
  },
);

app.put("/:domain/data/:key", verifyToken, checkDomainAndAccess, (req, res) => {
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
        res.status(404).json({ message: "Key not found or no update needed." });
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
          },
        );
      }
    },
  );
});

app.get(
  "/:domain/users",
  verifyToken,
  checkDomainAndAccess,
  isAdmin,
  (req, res) => {
    const domain = req.params.domain;

    db.all(
      "SELECT id, username, isActive, isAdmin, domain FROM users WHERE (domain LIKE ? OR domain LIKE ? OR domain LIKE ? OR domain = ?) AND isDeleted = FALSE",
      [`%,${domain},%`, `${domain},%`, `%,${domain}`, domain],
      (err, rows) => {
        if (err) {
          res.status(500).json({ error: err.message });
          return;
        }
        res.json({ users: rows });
      },
    );
  },
);

app.put(
  "/:domain/users/:userId",
  verifyToken,
  checkDomainAndAccess,
  isAdmin,
  (req, res) => {
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
      },
    );
  },
);

// Route to check if the user is logged in
app.get("/users/me", verifyToken, (req, res) => {
  // Token is already verified by verifyToken middleware
  res.json({
    isLoggedIn: true,
    user: {
      id: req.user.id,
      username: req.user.username,
      isAdmin: req.user.isAdmin,
    },
  });
});

// Helper functions for domain management
function addDomainToUser(userId, newDomain, callback) {
  db.get(
    "SELECT domain FROM users WHERE id = ? AND isDeleted = FALSE",
    [userId],
    (err, row) => {
      if (err) {
        return callback(err);
      }

      if (!row) {
        return callback(new Error("User not found"));
      }

      const currentDomains = row.domain
        ? row.domain.split(",").map((d) => d.trim())
        : [];

      if (currentDomains.includes(newDomain)) {
        return callback(null, {
          message: "User already has access to this domain",
        });
      }

      currentDomains.push(newDomain);
      const updatedDomains = currentDomains.join(",");

      db.run(
        "UPDATE users SET domain = ?, modifiedAt = CURRENT_TIMESTAMP WHERE id = ?",
        [updatedDomains, userId],
        function (err) {
          if (err) {
            return callback(err);
          }
          callback(null, { message: "Domain added to user successfully" });
        },
      );
    },
  );
}

function removeDomainFromUser(userId, domainToRemove, callback) {
  db.get(
    "SELECT domain FROM users WHERE id = ? AND isDeleted = FALSE",
    [userId],
    (err, row) => {
      if (err) {
        return callback(err);
      }

      if (!row) {
        return callback(new Error("User not found"));
      }

      const currentDomains = row.domain
        ? row.domain.split(",").map((d) => d.trim())
        : [];
      const updatedDomains = currentDomains.filter((d) => d !== domainToRemove);

      const newDomainString =
        updatedDomains.length > 0 ? updatedDomains.join(",") : null;

      db.run(
        "UPDATE users SET domain = ?, modifiedAt = CURRENT_TIMESTAMP WHERE id = ?",
        [newDomainString, userId],
        function (err) {
          if (err) {
            return callback(err);
          }
          callback(null, { message: "Domain removed from user successfully" });
        },
      );
    },
  );
}

// Start server if not running tests
if (process.env.NODE_ENV !== "test") {
  app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

module.exports = app; // Export for testing
