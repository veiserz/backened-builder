'use strict';

// TODO: verify TABLE matches your migration file
const TABLE = 'stores';

const QUERIES = {
  FIND_BY_ID: 'SELECT * FROM ' + TABLE + ' WHERE id = $1 LIMIT 1',
  FIND_ALL:   'SELECT * FROM ' + TABLE + ' ORDER BY created_at DESC LIMIT $1 OFFSET $2',
  COUNT:      'SELECT COUNT(*)::int AS total FROM ' + TABLE,
  CREATE:     'INSERT INTO ' + TABLE + ' (id, name, created_at, updated_at) VALUES ($1, $2, $3, $4) RETURNING *',
  UPDATE:     'UPDATE '     + TABLE + ' SET name = COALESCE($1, name), updated_at = $2 WHERE id = $3 RETURNING *',
  DELETE:     'DELETE FROM ' + TABLE + ' WHERE id = $1',
};

module.exports = { QUERIES };
