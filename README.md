# HNG DevOps Stage 3 - Blue/Green Deployment with Alerts

This project extends a blue/green deployment (Stage 2) with operational visibility via Nginx logs and Slack alerts for failover events and high error rates.

## Setup Instructions
1. Clone the repo: `git clone <your-repo-url>`
2. Copy .env.example: `cp .env.example .env`
3. Edit .env: Set `SLACK_WEBHOOK_URL` to your Slack webhook (keep secret).
4. Start services: `docker compose up -d`
5. Verify:
   - Nginx: `curl http://localhost:8080/version`
   - Logs: `docker logs nginx_proxy`
   - Watcher: `docker logs alert_watcher`

## Testing Failover and Alerts
- **Trigger Failover**:
  1. Inject chaos: `curl http://localhost:8080/chaos` (toggles app failure).
  2. Send requests: `while true; do curl -s http://localhost:8080/version; sleep 0.1; done`
  3. Check Slack for failover alert (Blue→Green or reverse).
  4. Toggle chaos again to recover; expect recovery alert.
- **Trigger Error Rate Alert**:
  1. During chaos, run the above loop to generate 5xx errors.
  2. Check Slack for high error rate alert (>2% over 200 requests).
- **View Logs**: `docker logs nginx_proxy | grep pool` for structured logs.
- **Toggle Pools**:
  1. Edit .env: Set `ACTIVE_POOL=green` and `SUPPRESS_FAILOVER_ALERTS=true`.
  2. Recreate Nginx: `docker compose up -d --force-recreate nginx`.
  3. Reset `SUPPRESS_FAILOVER_ALERTS=false` and restart watcher: `docker compose restart alert_watcher`.

## Verifying Slack Alerts
- Check your Slack channel for alerts.
- See screenshots:
  - `screenshots/slack-failover.png`: Failover alert (Blue→Green).
  - `screenshots/slack-recovery.png`: Recovery alert (Green→Blue).
  - `screenshots/slack-error-rate.png`: High error rate alert.
  - `screenshots/nginx-logs.png`: Nginx log with pool, release, upstream_status, etc.

## Runbook
See `runbook.md` for alert meanings and operator actions.

## Notes
- No app image modifications; all logic in Nginx, Docker Compose, and watcher.py.
- Alerts use shared nginx_logs volume and SLACK_WEBHOOK_URL from .env.
- Stage 2 tests (baseline, chaos, failover) remain valid.
