# Loki Setup

## How I started the stack

~~~bash
cd monitoring
docker compose up -d
docker compose ps
curl -s http://localhost:3100/ready
cd ..
~~~

- `docker compose ps` showed `loki`, `promtail` and `grafana` running.
- `curl` on `/ready` returned `ready`.
- Grafana runs at http://localhost:3000. I added a Loki data source with the URL `http://loki:3100`.
- Promtail reads container logs through the Docker socket and sends them to Loki. The Nomad job `nginx-app` is the log source.

## Label set

| Label | Value | Source |
|---|---|---|
| job | nginx-app | static label in `promtail-config.yaml` |
| service | nginx-app | static label in `promtail-config.yaml` |
| container | nginx-d055cf07-2b4a-adb1-b059-e46ad3be30d6 | Docker container name |
| nomad_alloc_id | d055cf07-2b4a-adb1-b059-e46ad3be30d6 | parsed from the container name by a relabel rule |
| service_name | nginx-app | added automatically by Loki (not configured by me) |

Promtail only keeps containers named `nginx-<allocation-id>`, so the Nomad task is collected and my earlier manual test container is ignored.

## LogQL queries run

1. `{job="nginx-app"}` : all logs from the app.
2. `{job="nginx-app"} |= " 404 "` : only requests that returned 404.
3. `{job="nginx-app"} != " 200 "` : everything except 200 responses.
4. `sum(count_over_time({job="nginx-app"} |= " 404 " [5m]))` : count of 404s over 5 minutes.

## Results

I generated traffic against the Nomad allocation (port 24013), including two requests for pages that do not exist:

~~~bash
curl -s http://127.0.0.1:24013/
curl -s http://127.0.0.1:24013/does-not-exist
curl -s http://127.0.0.1:24013/missing-page
~~~

Querying Loki directly from the terminal with the 404 filter returned:

~~~
172.18.0.1 - - [10/Nov/2026:21:30:35 +0000] "GET /missing-page HTTP/1.1" 404 153 "-" "curl/8.5.0"
172.18.0.1 - - [10/Nov/2026:21:30:35 +0000] "GET /does-not-exist HTTP/1.1" 404 153 "-" "curl/8.5.0"
~~~

In Grafana Explore, the unfiltered query showed both the `GET /` requests (status 200) and the 404 requests, and the 404 filter isolated the 404 lines for `/missing-page` and `/does-not-exist`. Expanding a log line showed the labels `container`, `job`, `nomad_alloc_id`, `service` and `service_name`.

Note: Grafana displays times in my browser's local time (UTC+1), while nginx logs UTC, so the same request appears one hour apart (for example 22:30:35 in Grafana and 21:30:35 +0000 in the log line).

![Grafana Explore showing nginx logs with labels](../docs/screenshots/loki-explore.png)

## Problems and fixes

1. **Docker "permission denied" on `/var/run/docker.sock`.**
   Fix: added my user to the docker group with `sudo usermod -aG docker $USER`, then ran `newgrp docker`.
2. **Grafana showed "Unauthorized" at http://localhost:3000.**
   Fix: Opened http://localhost:3000/login and signed in using admin as username and password
3. **`curl` failed with "No such file or directory" when checking Loki.**
   Cause: I typed the URL without `curl` in front, so the shell treated it as a file name.
   Fix: `curl -s http://localhost:3100/ready`.
4. **`jq: command not found` when reading Loki's JSON output.**
   Fix: `sudo apt install -y jq`.
5. **The Nomad job commit landed on `main` instead of the feature branch.**
   Fix: fast-forwarded `feature/nomad` to that commit and reset local `main` to `origin/main` with `git branch -f main origin/main`.
