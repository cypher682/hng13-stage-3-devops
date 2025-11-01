
# HNG Stage 3 DevOps — Blue-Green with Alerting

**Live Demo**: `http://<your-ec2-ip>:8080/version`  
**Repo**: https://github.com/cypher682/hng13-stage-3-devops

---

## Features
- Blue-Green deployment with Nginx failover
- Structured logs: `pool`, `release`, `upstream_status`, `latency`, `addr`
- Real-time Python log watcher → Slack alerts
- Failover, recovery, and error-rate detection
- Configurable via `.env`

---

## Setup

```bash
git clone https://github.com/cypher682/hng13-stage-3-devops.git
cd hng13-stage-3-devops
cp .env.example .env
# Edit .env → add your SLACK_WEBHOOK_URL
docker compose up -d
