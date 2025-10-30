#!/usr/bin/env python3
"""
HNG DevOps Stage 3 - Blue/Green Log Watcher
Monitors Nginx logs for failover events and upstream error rates
"""
import os
import re
import time
import requests
from collections import deque
from datetime import datetime

# Environment configuration
***REMOVED*** = os.getenv('***REMOVED***')
ACTIVE_POOL = os.getenv('ACTIVE_POOL', 'blue')
ERROR_RATE_THRESHOLD = float(os.getenv('ERROR_RATE_THRESHOLD', '2'))
WINDOW_SIZE = int(os.getenv('WINDOW_SIZE', '200'))
ALERT_COOLDOWN_SEC = int(os.getenv('ALERT_COOLDOWN_SEC', '300'))
ALERT_IDENTIFIER = os.getenv('ALERT_IDENTIFIER', 'HNG-Stage3')
SUPPRESS_FAILOVER_ALERTS = os.getenv('SUPPRESS_FAILOVER_ALERTS', 'false').lower() == 'true'
LOG_FILE = '/var/log/nginx/access.log'

class AlertWatcher:
    def __init__(self):
        # Track current pool state
        self.current_pool = ACTIVE_POOL
        self.last_alerted_pool = ACTIVE_POOL

        # Rolling window for error rate calculation
        self.request_window = deque(maxlen=WINDOW_SIZE)

        # Cooldown timers
        self.last_failover_alert_time = 0
        self.last_error_alert_time = 0

        # Context tracking for rich alerts
        self.last_pool = None
        self.last_release = None
        self.last_upstream = None
        self.last_request_time = None

        print(f"[INIT] Watcher starting")
        print(f"[INIT] Active pool: {ACTIVE_POOL}")
        print(f"[INIT] Suppress failover alerts: {SUPPRESS_FAILOVER_ALERTS}")
        print(f"[INIT] Error threshold: {ERROR_RATE_THRESHOLD}%")
        print(f"[INIT] Window size: {WINDOW_SIZE} requests")
        print(f"[INIT] Cooldown: {ALERT_COOLDOWN_SEC}s")
        print(f"[INIT] Identifier: {ALERT_IDENTIFIER}")

    def send_slack_alert(self, message):
        """Send alert to Slack webhook"""
        if not ***REMOVED***:
            print(f"[ALERT-NO-WEBHOOK]\n{message}\n")
            return False

        try:
            response = requests.post(
                ***REMOVED***,
                json={"text": message},
                headers={'Content-Type': 'application/json'},
                timeout=10
            )
            if response.status_code == 200:
                print(f"[SLACK] ✓ Alert sent successfully")
                return True
            else:
                print(f"[SLACK-ERROR] Status {response.status_code}: {response.text}")
                return False
        except requests.exceptions.Timeout:
            print(f"[SLACK-ERROR] Request timeout")
            return False
        except Exception as e:
            print(f"[SLACK-ERROR] {type(e).__name__}: {e}")
            return False

    def parse_nginx_log(self, line):
        """Extract structured data from Nginx log line"""
        data = {}
        # Extract pool (X-App-Pool header)
        pool_match = re.search(r'pool=(\w+)', line)
        if pool_match and pool_match.group(1) != '-':
            data['pool'] = pool_match.group(1)

        # Extract release (X-Release-Id header)
        release_match = re.search(r'release=([\w.-]+)', line)
        if release_match and release_match.group(1) != '-':
            data['release'] = release_match.group(1)

        # Extract upstream_status (can be comma-separated if retries)
        status_match = re.search(r'upstream_status=([\d,\s]+)', line)
        if status_match:
            statuses_str = status_match.group(1)
            statuses = [int(s.strip()) for s in statuses_str.split(',') if s.strip().isdigit()]
            if statuses:
                data['upstream_status'] = statuses[-1]  # Final status
                data['all_statuses'] = statuses

        # Extract upstream_addr (can be comma-separated if retries)
        addr_match = re.search(r'upstream_addr=([\d.:,\s]+)', line)
        if addr_match:
            addrs_str = addr_match.group(1)
            addrs = [a.strip() for a in addrs_str.split(',') if a.strip() and a.strip() != '-']
            if addrs:
                data['upstream'] = addrs[-1]  # Final upstream

        # Extract request_time
        rt_match = re.search(r'request_time=([\d.]+)', line)
        if rt_match:
            data['request_time'] = float(rt_match.group(1))

        return data

    def check_failover(self, pool, release, upstream, request_time):
        """Detect pool changes and send failover/recovery alert"""
        if not pool:
            return
        self.current_pool = pool
        if pool == self.last_alerted_pool:
            return
        now = time.time()
        if now - self.last_failover_alert_time < ALERT_COOLDOWN_SEC:
            print(f"[FAILOVER-SUPPRESSED] {self.last_alerted_pool} → {pool} (cooldown active)")
            return
        if SUPPRESS_FAILOVER_ALERTS:
            print(f"[FAILOVER-SUPPRESSED] {self.last_alerted_pool} → {pool} (maintenance mode)")
            self.last_alerted_pool = pool
            return

        # Distinguish failover vs recovery
        if pool == ACTIVE_POOL:
            title = f"✅ [{ALERT_IDENTIFIER}] Recovery detected: back to {pool} (primary)"
        else:
            title = f"🔄 [{ALERT_IDENTIFIER}] Failover detected: {self.last_alerted_pool} → {pool} (to backup)"

        alert_lines = [title]
        if release:
            alert_lines.append(f"Release: {release}")
        if upstream:
            alert_lines.append(f"Upstream: {upstream}")
        if request_time is not None:
            alert_lines.append(f"Request time: {request_time:.2f}s")
        alert_message = "\n".join(alert_lines)

        if self.send_slack_alert(alert_message):
            self.last_failover_alert_time = now
            self.last_alerted_pool = pool
            print(f"[FAILOVER-ALERT] {self.last_alerted_pool} → {pool}")

    def check_error_rate(self, all_statuses):
        """Monitor upstream 5xx error rate"""
        if not all_statuses:
            return
        is_5xx = any(500 <= s < 600 for s in all_statuses)
        self.request_window.append(is_5xx)
        if len(self.request_window) < WINDOW_SIZE // 2:
            return
        error_count = sum(self.request_window)
        total_requests = len(self.request_window)
        error_rate = (error_count / total_requests) * 100
        if error_rate <= ERROR_RATE_THRESHOLD:
            return
        now = time.time()
        if now - self.last_error_alert_time < ALERT_COOLDOWN_SEC:
            print(f"[ERROR-RATE-SUPPRESSED] {error_rate:.2f}% (cooldown active)")
            return
        alert_lines = [
            f"⚠️ [{ALERT_IDENTIFIER}] High upstream error rate",
            f"5xx in upstream attempts: {error_rate:.2f}% over last {total_requests} requests (threshold {ERROR_RATE_THRESHOLD}%).",
            f"Current pool: {self.current_pool}"
        ]
        if self.last_release:
            alert_lines.append(f"Recent release: {self.last_release}")
        if self.last_upstream:
            alert_lines.append(f"Recent upstream: {self.last_upstream}")
        if self.last_request_time is not None:
            alert_lines.append(f"Recent request time: {self.last_request_time:.2f}s")
        alert_message = "\n".join(alert_lines)
        if self.send_slack_alert(alert_message):
            self.last_error_alert_time = now
            print(f"[ERROR-RATE-ALERT] {error_rate:.2f}% > {ERROR_RATE_THRESHOLD}%")

    def tail_log_file(self):
        """Main loop: tail Nginx access log"""
        print(f"[WATCHER] Monitoring {LOG_FILE}")
        while not os.path.exists(LOG_FILE):
            print(f"[WAIT] Log file not found, waiting...")
            time.sleep(2)
        print(f"[WATCHER] Log file found, starting monitoring")
        with open(LOG_FILE, 'r') as log:
            log.seek(0, 2)
            while True:
                line = log.readline()
                if not line:
                    time.sleep(0.1)
                    continue
                data = self.parse_nginx_log(line)
                if not data:
                    continue
                pool = data.get('pool')
                release = data.get('release')
                upstream = data.get('upstream')
                request_time = data.get('request_time')
                all_statuses = data.get('all_statuses', [])
                if pool:
                    self.last_pool = pool
                if release:
                    self.last_release = release
                if upstream:
                    self.last_upstream = upstream
                if request_time is not None:
                    self.last_request_time = request_time
                if pool:
                    print(f"[LOG] pool={pool} upstream_status={all_statuses}")
                if pool:
                    self.check_failover(pool, release, upstream, request_time)
                if all_statuses:
                    self.check_error_rate(all_statuses)

def main():
    """Entry point"""
    try:
        watcher = AlertWatcher()
        watcher.tail_log_file()
    except KeyboardInterrupt:
        print("\n[SHUTDOWN] Watcher stopped by user")
    except Exception as e:
        print(f"[FATAL] {type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()
        raise

if __name__ == '__main__':
    main()
