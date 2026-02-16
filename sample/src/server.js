const app = require('./app');
const config = require('./config');
const connectDB = require('./common/database/mongoose');
const { connectRedis } = require('./common/redis/client');

const startServer = async () => {
  try {
    // Connect to Database
    await connectDB();
    
    // Connect to Redis (Optional)
    try {
      await connectRedis();
    } catch (error) {
      console.warn('⚠️  Redis not connected, continuing without cache...');
    }

    // Start Server
    const PORT = config.server.port;
    app.listen(PORT, () => {
      console.log(`🚀 Server running on port ${PORT}`);
      console.log(`📡 Environment: ${config.server.env}`);
      console.log(`🔗 API Base: ${config.server.apiPrefix}`);
    });

  } catch (error) {
    console.error('❌ Failed to start server:', error);
    process.exit(1);
  }
};

// Handle Unhandled Rejection
process.on('unhandledRejection', (err) => {
  console.error('💥 Unhandled Rejection:', err);
  process.exit(1);
});

startServer();
