# Runbook for Blue/Green Deployment Alerts

This runbook explains alert types, their meanings, and operator actions for the blue/green deployment system. Alerts are sent to Slack via the configured webhook.

## Alert Types and Actions

### Failover Detected (e.g., Blue → Green)
- **Meaning**: The system switched from the primary pool to the backup pool due to healthcheck failures or errors (e.g., 5xx, timeouts) in the primary. Detected via Nginx logs showing a pool change.
- **Operator Actions**:
  1. Check primary container health: `docker logs app_blue` (or app_green if ACTIVE_POOL=green).
  2. Test health endpoint: `curl http://localhost:8080/healthz`.
  3. If caused by chaos injection, toggle it off: `curl http://localhost:8080/chaos`.
  4. Monitor for recovery alert. If none after 1-2 minutes, restart primary: `docker restart app_blue`.
  5. Inspect Nginx logs for errors: `docker logs nginx_proxy | grep upstream_status`.

### Recovery Detected (e.g., Green → Blue)
- **Meaning**: The system switched back to the primary pool (defined by ACTIVE_POOL in .env) after a failover, indicating the primary is healthy and serving traffic again.
- **Operator Actions**:
  1. Verify stability: `curl -s http://localhost:8080/version` multiple times and check `docker logs nginx_proxy`.
  2. If unexpected, investigate initial failover cause (logs, metrics).
  3. No immediate action if system is stable.

### High Error Rate
- **Meaning**: Upstream 5xx errors (e.g., 502, 503) exceed the threshold (default 2%) over the last WINDOW_SIZE requests (default 200). This may occur even with successful failovers if primary errors persist.
- **Operator Actions**:
  1. Check container logs: `docker logs app_blue` and `docker logs app_green`.
  2. Inspect Nginx logs for error details: `docker logs nginx_proxy | grep upstream_status`.
  3. Consider toggling pools (see below) to isolate faulty pool.
  4. Fix root cause (e.g., resource issues, app bugs).
  5. Alerts are rate-limited (default 300s cooldown); monitor for resolution.

## Suppressing Alerts During Maintenance
To avoid failover alerts during planned pool toggles:
1. Edit .env: Set `SUPPRESS_FAILOVER_ALERTS=true`.
2. Restart watcher: `docker compose restart alert_watcher`.
3. Toggle pool by editing ACTIVE_POOL (e.g., blue to green) and run `docker compose up -d --force-recreate nginx`.
4. After maintenance, set `SUPPRESS_FAILOVER_ALERTS=false` and restart watcher.

## General Troubleshooting
- **View Logs**:
  - Watcher: `docker logs alert_watcher`
  - Nginx: `docker logs nginx_proxy`
  - Apps: `docker logs app_blue` or `app_green`
- **Test Failover**: Inject chaos with `curl http://localhost:8080/chaos` or `docker stop app_blue`.
- **Test Error Rate**: Run `while true; do curl -s http://localhost:8080/version; sleep 0.1; done` during chaos to trigger 5xx errors.
- **No Alerts?**:
  - Verify ***REMOVED*** in .env.
  - Check Nginx logs in shared volume: `cat /var/log/nginx/access.log`.
  - Ensure log format matches watcher.py regex.
- **Contact**: Escalate to on-call engineer if unresolved.
