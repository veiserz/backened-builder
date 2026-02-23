"use strict";

/**
 * Application configuration barrel.
 * Exports: features, policies, can
 */
module.exports = {
  ...require("./features"),
  ...require("./policies"),
};
