const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const config = require('./config');
const logger = require('./common/middlewares/logger');
const { errorHandler, notFoundHandler } = require('./common/middlewares/error');
const moduleRoutes = require('./modules');

const app = express();

// Security & Parsing
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Logging
if (config.server.env === 'development') {
  app.use(logger);
}

// API Routes
app.use(config.server.apiPrefix, moduleRoutes);

// Error Handling
app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;
