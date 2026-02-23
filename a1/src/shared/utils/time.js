"use strict";

/** Return the current date/time as a Date object. */
function now() {
  return new Date();
}

/**
 * Serialise a date to an ISO-8601 string.
 * @param {Date|string|number} [date]
 * @returns {string}
 */
function toISOString(date = new Date()) {
  return date instanceof Date
    ? date.toISOString()
    : new Date(date).toISOString();
}

/**
 * Add `seconds` to `date` and return a new Date.
 * @param {Date} date
 * @param {number} seconds
 * @returns {Date}
 */
function addSeconds(date, seconds) {
  return new Date(date.getTime() + seconds * 1_000);
}

/**
 * Add `minutes` to `date` and return a new Date.
 * @param {Date} date
 * @param {number} minutes
 * @returns {Date}
 */
function addMinutes(date, minutes) {
  return new Date(date.getTime() + minutes * 60_000);
}

/**
 * Add `days` to `date` and return a new Date.
 * @param {Date} date
 * @param {number} days
 * @returns {Date}
 */
function addDays(date, days) {
  return new Date(date.getTime() + days * 86_400_000);
}

/**
 * Return true if `date` is in the past relative to now.
 * @param {Date|string|number} date
 * @returns {boolean}
 */
function isExpired(date) {
  return new Date(date).getTime() < Date.now();
}

/**
 * Return the difference between two dates in whole seconds (a - b).
 * A positive value means `a` is later than `b`.
 * @param {Date|string|number} a
 * @param {Date|string|number} b
 * @returns {number}
 */
function diffSeconds(a, b) {
  return Math.floor((new Date(a).getTime() - new Date(b).getTime()) / 1_000);
}

module.exports = {
  now,
  toISOString,
  addSeconds,
  addMinutes,
  addDays,
  isExpired,
  diffSeconds,
};
