## ---Implementation Decisions

## --Architecture
- I Used Nginx `backup` directive for true Blue/Green (not load balancing)
- Set `max_fails=1` and `fail_timeout=5s` for fast failover detection
- Applied 2-3 second timeouts for quick failure response

## Failover Mechanism
- `proxy_next_upstream` retries failed requests to Green within same client request
- Ensures zero failed responses to clients during failover
- Blue marked as failed after first error, all traffic routes to Green

## Configuration
- Fully parameterized via `.env` file
- Template processing with `envsubst` for dynamic Nginx config
- Same image (yimikaade/wonderful:latest) for both instances, differentiated by environment variables

## Testing
- Verified by triggering chaos on Blue via POST to port 8081
- Observed automatic failover to Green with zero client-facing errors
- Headers (X-App-Pool, X-Release-Id) forwarded correctly through Nginx

## Deployment
- Runs on EC2 instance at http://52.72.101.160:8080
- Custom HTML interface shows active instance in real-time
- Auto-refreshes every 2 seconds to display current pool status
