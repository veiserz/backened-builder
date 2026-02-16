const qry = {
  findAll: `SELECT * FROM auths ORDER BY created_at DESC LIMIT $1 OFFSET $2`,
  findById: `SELECT * FROM auths WHERE id = $1`,
  create: `INSERT INTO auths (title, description, status) VALUES ($1, $2, $3) RETURNING *`,
  update: `UPDATE auths SET title = $1, description = $2, status = $3, updated_at = NOW() WHERE id = $4 RETURNING *`,
  delete: `DELETE FROM auths WHERE id = $1 RETURNING *`,
  exists: `SELECT EXISTS(SELECT 1 FROM auths WHERE title = $1)`,
  count: `SELECT COUNT(*) as total FROM auths`,
};

module.exports = qry;
