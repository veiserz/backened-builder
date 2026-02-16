require('dotenv').config();

module.exports = {
  server: {
    port: process.env.PORT || 3000,
    env: process.env.NODE_ENV || 'development',
    apiPrefix: process.env.API_PREFIX || '/api/v1'
  },
  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || '7d'
  }
};
