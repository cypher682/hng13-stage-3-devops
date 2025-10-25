# Blue / Green deployment with nginx

zero downtime deployment system using nginx reverse proxy with automatic failover

# Name : ABDULRAHMAN SULEIMAN
# SLACk : Suleiman_cipher
# github: github.com/cypher682/blue-green-deployment

    Live Demo
url: http:// :8080
blue: http:// :8081
green: http:// :8082

# quick start

docker and docker compose
ubuntu or ec instance

# Setup

clone repo: git clone https://github.com/cypher682/blue-green-deployment.git
cd blue-green-deployment

cp .env.example .env

make entrypoint execute : chmod 700 entrypoint.sh

Start service with : docker compose up -d


### Test Failover
```bash
# Normal operation (Blue active)
curl http://ip:8080/version

# Trigger chaos on Blue
curl -X POST "http://ip:8081/chaos/start?mode=error"

# Verify failover to Green
curl http://ip:8080/version
```

Architecture
- **Nginx:** Reverse proxy with automatic failover
- **Blue Instance:** Primary service (port 8081)
- **Green Instance:** Backup service (port 8082)
- **Failover:** Automatic retry on error/timeout with zero client failures
How this  Works
1. All traffic goes to Blue by default
2. When Blue fails, Nginx detects error in 2-3 seconds
3. Nginx automatically retries request to Green
4. Client receives 200 OK (never sees Blue's failure)
5. Subsequent requests route directly to Green

