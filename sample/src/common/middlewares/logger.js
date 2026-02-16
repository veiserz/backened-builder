const morgan = require('morgan');

const logger = morgan(':method :url :status :res[content-length] - :response-time ms');

module.exports = logger;
