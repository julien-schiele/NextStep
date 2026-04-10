# Architecture — NextStep

## Overview

NextStep is a fullstack fitness coaching app built with Django (REST API) and Next.js (frontend). This document explains the infrastructure decisions made for the portfolio deployment, including trade-offs and what would change at scale.

---

## Production Stack

```
Cloudflare DNS
       ↓  (proxy + DDoS protection)
VPS Hetzner CX23  —  cheap, fixed cost
       ↓
Docker Compose
       ↓
Caddy 2  (reverse proxy + automatic SSL via Let's Encrypt)
    ├── nextstep.julien-schiele.dev              → Next.js  :3000
    ├── nextstep.julien-schiele.dev/api          → Django   :8000
    ├── admin.nextstep.julien-schiele.dev/api    → Django   :8000
    ├── julien-schiele.dev                       → static portfolio
    └── status.julien-schiele.dev                → Uptime Kuma :3001
       ↑
GitHub Actions  (push main → tests → SSH deploy)
```

---

## Key Decisions & Trade-offs

### Caddy over Nginx
Caddy handles SSL certificate provisioning and renewal automatically via Let's Encrypt. No manual cert management, no cron for renewal, declarative config. The trade-off is less ecosystem documentation than Nginx — acceptable for a single-server setup.

### Single VPS over managed services (Vercel/Render/Supabase)
A single Hetzner CX23 hosts the entire stack: frontend, API, database, reverse proxy, and monitoring. This gives predictable fixed costs with zero overage risk, full control over the environment, and the ability to host multiple projects on the same instance as the portfolio grows.

The trade-off: no auto-scaling, single point of failure. Acceptable for a portfolio with low traffic. In a production context with SLA requirements, this would move to a managed database (RDS or equivalent) and a load balancer in front of at least two app instances.

### Docker Compose over Kubernetes
Kubernetes overhead — cluster management, YAML verbosity, networking complexity — is not justified before there is real traffic and a team to operate it. Docker Compose provides the same reproducibility and service isolation at a fraction of the operational cost.

When this would change: multiple services owned by different teams, or horizontal scaling requirements.

### JWT (stateless auth) over session-based auth
JWT tokens are verified locally — no shared session store needed. This means the API is horizontally scalable without additional infrastructure (Redis, Memcached) from day one.

The trade-off: token revocation requires a denylist or short expiry windows. Implemented here with short-lived access tokens + HttpOnly refresh token cookie.

### Postgres in Docker over managed DB
For a portfolio with near-zero traffic, running Postgres in a container on the same VPS is sufficient. Daily backups run via cron and are rotated locally.

What would change in production: move to a managed Postgres instance (RDS, Supabase, or Hetzner Managed Database) for automatic backups, point-in-time recovery, and failover.

### Synchronous tasks over async queue
Currently, periodic tasks (demo data reset, backups) run as cron jobs on the VPS. No message queue or worker process.

What would change at scale: tasks that could block the request cycle (email sending, report generation, webhook delivery) would move to an async queue (Celery + Redis or similar). The current architecture deliberately avoids this complexity before it is needed.

---

## CI/CD Pipeline

```
create a tag
    │
    ├── changes detected in backend/**  →  Django tests
    ├── changes detected in frontend/** →  ESLint
    │
    └── if all relevant tests pass (or were skipped)
            ↓
        Github action create new images
        VPS pull images
```

Path filtering ensures Django tests only run on backend changes, and frontend checks only run on frontend changes — keeping CI fast on partial commits.

---

## Security

- No ports exposed publicly except 80 and 443 (UFW)
- Django and Next.js containers use `expose` not `ports` — only reachable via Caddy
- Postgres has no public port
- `/admin/*` blocked at the reverse proxy level
- `DEBUG=False` enforced via environment variable
- Cookies: `"AUTH_COOKIE_SECURE": not DEBUG`
- Demo accounts blocked from write actions via a dedicated DRF permission (`IsNotDemoUser`)
- Root SSH login disabled on the VPS

---

## Monitoring

Uptime Kuma (self-hosted) monitors:
- Frontend availability
- API health endpoint (`/api/health/`)
- SSL certificate expiry (alert at 14 days)

Alerts via email. Simple, sufficient for a portfolio. In a team context, this would plug into a shared alerting system (PagerDuty, Opsgenie, or equivalent) and aggregate logs from all services.

---

## What This Architecture Does Not Cover (Intentionally)

| Concern | Current state | Production equivalent |
|---|---|---|
| High availability | Single VPS | Load balancer + 2+ instances |
| Database failover | Local Docker volume | Managed DB with replication |
| Async task queue | Cron jobs | Celery + Redis |
| Centralized logging | Container stdout | Log aggregation (ELK, Loki, etc.) |
| Advanced metrics | Uptime Kuma only | Full metrics pipeline |
| CDN for static assets | Cloudflare edge cache | Dedicated CDN configuration |

The goal of this deployment is to demonstrate production-ready practices at an appropriate scale — not to over-engineer a portfolio project.

---

## Local Development

```bash
git clone --recurse-submodules git@github.com:julien-schiele/nextstep.git
cd nextstep
cp .env.example .env
docker compose up
```

Keep git tree clean using:
```bash 
git merge --no-ff develop -m "merge (develop): ..."
```


App available at:
- Frontend: http://localhost:3000
- API: http://localhost:8000
- PgAdmin: http://localhost:8888
- Mailhog: http://localhost:8025
