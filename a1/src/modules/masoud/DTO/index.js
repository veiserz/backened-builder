'use strict';

module.exports = {
  ...require('./create.dto'),
  ...require('./update.dto'),
  ...require('./param.dto'),
  ...require('./query.dto'),
  validate: require('./validate').validate,
};
