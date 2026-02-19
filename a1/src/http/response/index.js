'use strict';

/**
 * Standardised JSON envelope:
 *   { success, data, error, meta }
 */

function ok(res, data = null, meta = {}) {
  return res.status(200).json({ success: true, data, meta });
}

function created(res, data = null) {
  return res.status(201).json({ success: true, data, meta: {} });
}

function noContent(res) {
  return res.status(204).send();
}

function paginated(res, { items, total, page, limit }) {
  return res.status(200).json({
    success: true,
    data:    items,
    meta:    { total, page, limit, pages: Math.ceil(total / limit) },
  });
}

function fail(res, status, message, details = null) {
  const body = { success: false, error: { message } };
  if (details) body.error.details = details;
  return res.status(status).json(body);
}

module.exports = { ok, created, noContent, paginated, fail };
