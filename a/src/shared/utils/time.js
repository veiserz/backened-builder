'use strict';

function now() {
  return new Date();
}

function toISOString(date = new Date()) {
  return date instanceof Date ? date.toISOString() : new Date(date).toISOString();
}

function addSeconds(date, seconds) {
  return new Date(date.getTime() + seconds * 1000);
}

module.exports = { now, toISOString, addSeconds };
