# HNG Stage 3 — Alert Runbook

## Alert Types & Actions

| Alert | Meaning | Action |
|------|--------|--------|
| **Failover Detected: blue → green** | Primary (`app_blue`) failed. Nginx switched to backup (`app_green`). | 1. `docker logs app_blue` → find crash<br>2. `docker restart app_blue`<br>3. Monitor recovery alert |
| **Recovery Detected: back to blue** | Primary is healthy again and serving traffic. | No action needed. Confirm `X-App-Pool: blue` in logs. |
| **High upstream error rate** | >2% 5xx responses in last 200 requests (e.g., 502s). | 1. Check `docker logs nginx_proxy \| grep upstream_status`<br>2. Inspect failing upstream (`app_blue` or `app_green`)<br>3. Consider manual toggle via `ACTIVE_POOL` in `.env` |
