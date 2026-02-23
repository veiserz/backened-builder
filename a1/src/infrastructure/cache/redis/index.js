"use strict";

/**
 * Redis infrastructure module.
 *
 * Exports:
 *   connectRedis()    – create & connect the shared Redis instance (call once at bootstrap)
 *   disconnectRedis() – gracefully close the connection (call at shutdown)
 *   getRedis()        – return the raw ioredis instance
 *   redisClient       – high-level helper (get/set/del/exists/expire/ttl/mget/mset,
 *                       incr/incrby/decr/decrby, hget/hset/hdel/hgetall/hincrby, flush)
 */
module.exports = {
  ...require("./connection"),
  ...require("./client"),
};
