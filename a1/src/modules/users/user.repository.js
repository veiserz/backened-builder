"use strict";

const QUERIES = {
  FIND_BY_ID: `
    SELECT *
    FROM   users
    WHERE  id = $1
    LIMIT  1
  `,

  FIND_BY_EMAIL: `
    SELECT *
    FROM   users
    WHERE  email = $1
    LIMIT  1
  `,

  FIND_ALL: `
    SELECT *
    FROM   users
    ORDER  BY created_at DESC
    LIMIT  $1
    OFFSET $2
  `,

  COUNT: `
    SELECT COUNT(*)::int AS total
    FROM   users
  `,

  CREATE: `
    INSERT INTO users
      (id, name, email, password_hash, role, created_at, updated_at)
    VALUES
      ($1, $2, $3, $4, $5, $6, $7)
    RETURNING *
  `,

  UPDATE: `
    UPDATE users
    SET
      name          = COALESCE($1, name),
      password_hash = COALESCE($2, password_hash),
      role          = COALESCE($3, role),
      updated_at    = $4
    WHERE id = $5
    RETURNING *
  `,

  DELETE: `
    DELETE FROM users
    WHERE  id = $1
  `,

  EXISTS_BY_EMAIL: `
    SELECT 1
    FROM   users
    WHERE  email = $1
    LIMIT  1
  `,

  EXISTS_BY_ID: `
    SELECT 1
    FROM   users
    WHERE  id = $1
    LIMIT  1
  `,
};

module.exports = { QUERIES };
