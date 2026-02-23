# Centralized Logging Stack

```
stdout → Docker json-file → Fluent Bit → Loki → Grafana
                                 ↓ (on Loki unavailability)
                        filesystem buffer (Fluent Bit storage)
```

## Directory Structure

```
logging/
├── docker-compose.logging.yml     # Compose: Loki + Grafana + Fluent Bit
├── .env.example                   # Required env vars (copy to .env)
├── src/
│   └── logger.ts                  # pino logger for your Node.js app
└── config/
    ├── loki/
    │   ├── loki.yml               # Loki server config (retention, limits, ruler)
    │   └── rules/
    │       └── fake/
    │           └── app-alerts.yml # LogQL alerting rules
    ├── fluent-bit/
    │   ├── fluent-bit.conf        # Collector pipeline config
    │   └── parsers.conf           # Docker + JSON + nginx parsers
    └── grafana/
        └── provisioning/
            ├── datasources/
            │   └── loki.yml       # Auto-provisions Loki as default datasource
            └── alerting/
                └── contact-points.yml  # Slack + email alert routing
```

## Deployment

```bash
cp .env.example .env
# Fill in GRAFANA_ADMIN_PASSWORD, SLACK_WEBHOOK_URL, etc.

# Create Fluent Bit filesystem buffer dir on host
mkdir -p /var/log/flb-storage

# Start logging stack alongside your app
docker compose -f docker-compose.yml -f docker-compose.logging.yml up -d

# Verify Loki is healthy
curl http://localhost:3100/ready

# Verify Fluent Bit HTTP server
curl http://localhost:2020/api/v1/health
```

## Node.js App Labels (required for routing in Fluent Bit)

Add to your app service in `docker-compose.yml`:

```yaml
labels:
  logging: "enabled"
  app: "myapp" # → Loki label: app="myapp"
  env: "production" # → Loki label: env="production"
logging:
  driver: json-file
  options:
    max-size: "50m"
    max-file: "5"
    compress: "true"
```

## Key LogQL Queries

```logql
# All errors from your app in the last hour
{job="docker", app="myapp", level="error"} | json

# Error rate over time
sum(rate({job="docker", app="myapp"} | json | level="error" [5m]))

# Slow requests (>2s)
{job="docker", app="myapp"} | json | responseTime > 2000

# Specific user's activity
{job="docker", app="myapp"} | json | userId="abc-123"

# 5xx errors
{job="docker", app="myapp"} | json | status >= 500 | line_format "{{.msg}} status={{.status}}"

# Log volume by container
sum by (app) (rate({job="docker"} [5m]))
```

## npm Dependencies

```bash
npm install pino pino-http
npm install -D pino-pretty @types/pino
```

## Operational Notes

### Backpressure

- Fluent Bit `storage.type=filesystem` on the INPUT spills to disk when Loki is slow/down.
- `Mem_Buf_Limit 50MB` controls in-memory buffer per input before overflow to disk.
- `storage.max_chunks_up=256` caps total filesystem usage.
- `Retry_Limit=5` with exponential backoff before a chunk is dropped.

### Loki Temporarily Unavailable

1. Fluent Bit detects failed HTTP request to Loki.
2. Chunk is marked for retry and stored on filesystem (`storage.path`).
3. Retries occur with backoff (1s → 2s → 4s → 8s → 16s).
4. After `Retry_Limit=5` failures, the chunk is dropped and a warning is logged.
5. Docker's own `json-file` driver continues to buffer logs on disk independently.

### Log Volume Control

- Set `LOG_LEVEL=info` in production (never `debug`/`trace`).
- Filter noisy health-check routes in both pino-http and Fluent Bit.
- Use `per_stream_rate_limit` in Loki to throttle abusive streams.
- Monitor volume with: `sum by (app) (rate({job="docker"} [5m]))`

### Retention

- **31 days** is the default (`retention_period: 744h` in `loki.yml`).
- Regulatory baseline: 90 days for most compliance frameworks.
- Adjust to your disk capacity: ~1–5 GB/day for a moderate-traffic API.
- Compactor enforces retention; `retention_delete_delay=2h` is the lag.

### Security Checklist

- [ ] Loki bound to `127.0.0.1:3100` — never public internet
- [ ] Grafana behind TLS reverse proxy (Nginx/Caddy) with strong password
- [ ] `GF_USERS_ALLOW_SIGN_UP=false` — no self-registration
- [ ] Sensitive fields in `REDACTED_PATHS` array in `logger.ts`
- [ ] `.env` in `.gitignore` — never commit credentials
- [ ] Fluent Bit `/var/run/docker.sock` — restrict to trusted hosts
