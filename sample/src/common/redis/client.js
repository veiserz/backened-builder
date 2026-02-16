const redis = require('redis');
const redisConfig = require('../../config/redis.config');

let client = null;

const connectRedis = async () => {
  try {
    client = redis.createClient(redisConfig);
    
    client.on('error', (err) => console.error('❌ Redis Error:', err));
    client.on('connect', () => console.log('✅ Redis Connected'));
    
    await client.connect();
    return client;
  } catch (error) {
    console.error('❌ Redis Connection Error:', error.message);
  }
};

const getRedisClient = () => client;

module.exports = { connectRedis, getRedisClient };
