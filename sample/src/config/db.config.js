module.exports = {
  uri: process.env.DB_URI,
  options: {
    maxPoolSize: parseInt(process.env.DB_POOL_SIZE) || 10,
    minPoolSize: 2,
    serverSelectionTimeoutMS: 5000,
    socketTimeoutMS: 45000,
  }
};
