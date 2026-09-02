---
name: docker-patterns
description: Use when writing Dockerfiles, docker-compose, containerization — multi-stage builds, layer caching, security, image size optimization, health checks, networks, volumes. For Avo sandbox + general. Trigger on "dockerfile", "docker-compose", "container", "image", "build context", "/docker-check".
---

# docker-patterns

Docker best practices untuk production + development. Fokus pada image kecil, aman, cepat build.

## Dockerfile template (Python)

```dockerfile
# syntax=docker/dockerfile:1.7

# Stage 1: builder (deps + compile kalau perlu)
FROM python:3.12-slim AS builder

WORKDIR /app

# System deps (kalau perlu compile)
RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc \
        libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Python deps — copy dulu untuk cache layer
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: runtime (minimal)
FROM python:3.12-slim AS runtime

# Non-root user (security)
RUN groupadd -r app && useradd -r -g app app

WORKDIR /app

# Copy deps dari builder
COPY --from=builder /root/.local /home/app/.local
ENV PATH=/home/app/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Copy code
COPY --chown=app:app . .

USER app

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

ENTRYPOINT ["python", "-m", "uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Size comparison:**
- `python:3.12` (full) → 1.2GB
- `python:3.12-slim` → 150MB
- `python:3.12-alpine` → 50MB (butuh musl, kadang kompatibilitas issue)
- Multi-stage slim → 200-300MB total (dengan deps)

## Layer caching rules

```dockerfile
# ❌ BAD — code change = rebuild everything
COPY . .
RUN pip install -r requirements.txt

# ✅ GOOD — deps cache unless requirements.txt changes
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
```

Order by change frequency (jarang berubah → sering berubah):
1. Base image
2. System packages
3. Language deps (requirements.txt, package.json)
4. Source code
5. Config files

## Multi-stage builds

```dockerfile
# Build frontend
FROM node:20-alpine AS frontend-builder
WORKDIR /web
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build  # → /web/dist

# Build backend
FROM python:3.12-slim AS backend
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

# Final image: backend + built frontend
FROM python:3.12-slim
WORKDIR /app
COPY --from=backend /app /app
COPY --from=frontend-builder /web/dist /app/static
CMD ["python", "main.py"]
```

## Docker Compose patterns

### Local dev (hot reload)

```yaml
# docker-compose.dev.yml
services:
  app:
    build: .
    volumes:
      - .:/app  # bind mount for hot reload
      - /app/node_modules  # anonymous vol to protect node_modules
    ports:
      - "8000:8000"
    environment:
      - DEBUG=1
      - DATABASE_URL=postgresql://postgres:dev@db:5432/app
    command: uvicorn app:app --reload --host 0.0.0.0
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: dev
      POSTGRES_DB: app
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  pgdata:
```

### Production

```yaml
# docker-compose.prod.yml
services:
  app:
    build: .
    restart: unless-stopped
    ports:
      - "127.0.0.1:8000:8000"  # bind ke localhost only, expose via reverse proxy
    environment:
      - DATABASE_URL=${DATABASE_URL}
    env_file:
      - .env.prod
    depends_on:
      db:
        condition: service_healthy
    deploy:
      resources:
        limits:
          cpus: "2.0"
          memory: 2G
        reservations:
          cpus: "1.0"
          memory: 1G
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  db:
    image: postgres:16-alpine
    restart: unless-stopped
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./backups:/backups
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: app
    healthcheck:
      test: ["CMD-SHELL", "pg_isready"]
      interval: 30s
      timeout: 5s
      retries: 3

  nginx:
    image: nginx:alpine
    ports:
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/certs:ro
    depends_on:
      - app

volumes:
  pgdata:
```

## Networking

```yaml
services:
  app:
    networks:
      - frontend
      - backend

  nginx:
    networks:
      - frontend

  db:
    networks:
      - backend  # tidak exposed ke host

networks:
  frontend:
  backend:
    internal: true  # no external access
```

Default: bridge network, services dapat DNS name = service name.

## Volumes vs bind mounts

| Type | Use |
|---|---|
| **Named volume** | DB data, persistent state |
| **Bind mount** | Source code (dev), config files |
| **tmpfs** | Secrets, cache, sensitive data |
| **Anonymous volume** | Protect from bind mount (e.g., `/app/node_modules`) |

## Security checklist

- [ ] Non-root user di runtime stage
- [ ] `--no-install-recommends` untuk apt
- [ ] `rm -rf /var/lib/apt/lists/*` setelah apt
- [ ] `--no-cache-dir` untuk pip
- [ ] No secrets di image (pakai env atau secret mount)
- [ ] Pin base image version (jangan `latest`)
- [ ] `.dockerignore` exclude `.git`, `node_modules`, `.env`, `*.md`, tests
- [ ] Scan image: `trivy`, `grype`, `snyk`
- [ ] Read-only filesystem + writable volume untuk data dirs
- [ ] Drop capabilities: `cap_drop: [ALL]`, `security_opt: [no-new-privileges]`
- [ ] Resource limits (CPU, memory)

## .dockerignore

```
.git
.gitignore
.env
.env.*
!.env.example
*.md
README*
LICENSE
tests/
node_modules/
__pycache__
.pytest_cache
.mypy_cache
.ruff_cache
.venv
venv
*.log
.DS_Store
.vscode
.idea
```

## Image optimization

```bash
# Check layer sizes
docker history myimage:latest

# Find what's big
dive myimage:latest

# Multi-arch build
docker buildx build --platform linux/amd64,linux/arm64 -t myimage:latest .

# Cleanup
docker system prune -a
docker volume prune
```

## ROCm (AMD GPU) di container

```dockerfile
FROM rocm/pytorch:rocm6.0_ubuntu22.04_py3.10_pytorch_2.1.1

# Add ROCm devices
# docker run --device /dev/kfd --device /dev/dri ...
```

```yaml
services:
  training:
    image: rocm/pytorch:latest
    devices:
      - /dev/kfd
      - /dev/dri
    group_add:
      - video
    cap_add:
      - SYS_PTRACE
    security_opt:
      - seccomp:unconfined
    environment:
      - HSA_OVERRIDE_GFX_VERSION=10.3.0  # RX 6700S
```

Lihat skill `local-ml-gpu` untuk GPU workflow.

## Health checks

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -fsS http://localhost:8000/health || exit 1
```

Status: `healthy`, `unhealthy`, `starting` (during start-period).

## Logging

```yaml
services:
  app:
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "5"
        tag: "{{.Name}}"
```

## Networking debugging

```bash
# Inspect
docker network inspect mynet

# Exec into container
docker compose exec app sh

# Check DNS
docker compose exec app nslookup db

# Port mapping
docker compose ps
docker port myapp
```

## Common pitfalls

| Pitfall | Solusi |
|---|---|
| Image 2GB+ | Multi-stage, slim base, clean cache |
| Build ulang tiap code change | Layer cache order benar |
| Container run as root | Add USER di Dockerfile |
| Container restart on crash | `restart: unless-stopped` |
| DB data hilang saat recreate | Named volume, jangan tmpfs |
| Hot reload tidak jalan di container | Bind mount source + ignore node_modules via anonymous vol |
| Network isolation broken | Custom networks, jangan pakai `network_mode: host` |
| Secrets di env di-commit | Docker secrets atau external secret manager |
| Build context besar | `.dockerignore` exclude junk |
| ENTRYPOINT vs CMD confusion | ENTRYPOINT = main binary, CMD = default args |

## For Avo sandbox specifically

Lihat `src/avo/app_tools/sandbox.py` reference. Pattern untuk AI agent:

```dockerfile
FROM python:3.12-slim

# Install runtime tools untuk sandbox
RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl wget jq \
    && rm -rf /var/lib/apt/lists/*

# Sandbox user (no sudo, network restricted at runtime)
RUN useradd -m -s /bin/bash sandbox
USER sandbox
WORKDIR /home/sandbox
```

Runtime:
- `--network=none` (no external network)
- `--read-only` filesystem + tmpfs untuk /tmp
- `--memory`, `--cpus` limits
- `--cap-drop=ALL`
- `--security-opt=no-new-privileges`

## Invokation

Auto-trigger saat:
- Edit `Dockerfile*`, `docker-compose*.yml`, `.dockerignore`
- User sebut "docker", "container", "image", "deploy container"
- Code pattern: `docker build`, `docker compose`, `docker run`