# Woka Reel Intelligence — Local Development & ngrok Setup Guide

This guide covers running the complete **Woka Reel Intelligence** platform locally on Windows with live Meta Instagram OAuth and Webhooks exposed securely via **ngrok**.

---

## 1. System Architecture

```
                                      +------------------------------------+
                                      |       Meta Developer Portal        |
                                      |  (Instagram Login for Business)    |
                                      +-----------------+------------------+
                                                        |
                                 OAuth Redirect /       | Webhooks /
                                 Token Exchange         | Deauthorize
                                                        v
                                      +------------------------------------+
                                      |     ngrok HTTPS Tunnel             |
                                      |  https://*.ngrok-free.app:443      |
                                      +-----------------+------------------+
                                                        |
+------------------------------+                        | Port 8000 forwarding
|  Browser / Client (Creator)  |                        v
|  http://localhost:3000       | ------------> +------------------------------------+
+------------------------------+               |  FastAPI Backend (Port 8000)       |
               ^                               |  - Uvicorn / Python 3.10           |
               |                               |  - /api/v1/instagram/callback     |
               | (Direct Local API Calls)      |  - /api/v1/instagram/webhook      |
               +------------------------------ |  - /api/v1/instagram/endpoints    |
                                               +-------+--------------------+-------+
                                                       |                    |
                                                       v                    v
                                          +---------------------+  +-----------------+
                                          | PostgreSQL 16       |  | Redis 7         |
                                          | (localhost:5432)    |  | (localhost:6379)|
                                          +---------------------+  +-----------------+
```

> **Security Rule:** PostgreSQL and Redis are bound exclusively to `localhost` (`127.0.0.1`) and are **never** exposed through ngrok. Only the FastAPI HTTP server (port 8000) is forwarded.

---

## 2. Prerequisites

| Component | Required Version | Status / Notes |
| :--- | :--- | :--- |
| **Windows OS** | Windows 10/11 64-bit | PowerShell 5.1+ or PowerShell 7+ |
| **Python** | 3.10+ | Virtual environment at `backend/venv` |
| **Node.js** | 18.x or 20.x | Installed with `npm` |
| **Docker Desktop** | Latest (Optional) | For PostgreSQL 16 & Redis 7 containers |
| **SQLite** | 3.x (Built-in) | Zero-configuration dev database fallback |
| **ngrok CLI** | Latest | Exposes backend port 8000 via public HTTPS |

---

## 3. Quick Start (Automated PowerShell Script)

Run the included automated setup script from the project root:

```powershell
.\start_local.ps1
```

Options:
- `-SkipDocker`: Skips Docker daemon checks and runs using SQLite.
- `-SkipMigrations`: Skips applying Alembic migrations.
- `-NgrokDomain <URL>`: Automatically updates `BACKEND_PUBLIC_URL` in `backend\.env`.

Example with custom ngrok domain:
```powershell
.\start_local.ps1 -NgrokDomain "https://uncommon-tiger-prompt.ngrok-free.app"
```

---

## 4. Manual Step-by-Step Setup

### Step 1: Database & Cache (PostgreSQL + Redis)

#### Option A: Docker Compose (Recommended)
From the repository root:
```powershell
docker compose up -d postgres redis
```
This starts:
- PostgreSQL 16 at `localhost:5432` (User: `woka`, DB: `woka_reel_intelligence`)
- Redis 7 at `localhost:6379`

#### Option B: SQLite Fallback (No Docker Required)
If Docker Desktop is not installed, the application automatically supports SQLite. In `backend/.env`, set:
```ini
DATABASE_URL=sqlite:///./woka.db
```

---

### Step 2: Database Migrations (Alembic)

Synchronize the database schema to the latest migration head:
```powershell
.\backend\venv\Scripts\python.exe -m alembic -c backend/alembic.ini upgrade head
```

Verify current version:
```powershell
.\backend\venv\Scripts\python.exe -m alembic -c backend/alembic.ini current
```
Expected output: `c8194ad51e7f (head)`

---

### Step 3: Configure Environment Variables

#### Backend (`backend/.env`)
Copy `backend/.env.local.example` to `backend/.env` (or let `start_local.ps1` generate it):
```ini
ENVIRONMENT=development
DEBUG=True
DATABASE_URL=postgresql://woka:woka_dev_password_2026@localhost:5432/woka_reel_intelligence
# Or for SQLite: DATABASE_URL=sqlite:///./woka.db
REDIS_URL=redis://localhost:6379/0
SECRET_KEY=woka-dev-secret-key-at-least-32-chars-long-2026
TOKEN_ENCRYPTION_KEY=N0NlbmRfdG9rZW5fZW5jcnlwdGlvbl9zdGFnaW5nOTk=
FRONTEND_URL=http://localhost:3000

# Meta Developer Portal Credentials
META_APP_ID=your-meta-app-id
META_APP_SECRET=your-meta-app-secret
META_VERIFY_TOKEN=woka_local_webhook_verify_token_2026
META_API_VERSION=v21.0

# ngrok Tunnel (Set after starting ngrok)
BACKEND_PUBLIC_URL=https://your-domain.ngrok-free.app
```

#### Frontend (`frontend/.env.local`)
```ini
NEXT_PUBLIC_API_URL=http://localhost:8000/api/v1
NEXT_PUBLIC_APP_ENV=development
```

---

### Step 4: Start ngrok HTTPS Tunnel

1. If you haven't installed ngrok:
   ```powershell
   winget install ngrok.ngrok
   ```
2. Authenticate ngrok (get your free authtoken from https://dashboard.ngrok.com):
   ```powershell
   ngrok config add-authtoken <YOUR_AUTHTOKEN>
   ```
3. Launch the tunnel to port 8000:
   ```powershell
   ngrok http 8000
   ```
4. Note your forwarding URL:
   ```
   Forwarding   https://xyz-abc.ngrok-free.app -> http://localhost:8000
   ```
5. Update `BACKEND_PUBLIC_URL` in `backend/.env`:
   ```ini
   BACKEND_PUBLIC_URL=https://xyz-abc.ngrok-free.app
   ```

---

### Step 5: Start the Backend & Frontend

#### Terminal 1 — FastAPI Backend
```powershell
cd backend
.\venv\Scripts\Activate.ps1
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

#### Terminal 2 — Next.js Frontend
```powershell
cd frontend
npm run dev
```

---

## 5. Meta Developer Portal Configuration Checklist

Configure the following URLs in your App Dashboard at [developers.facebook.com](https://developers.facebook.com):

| Meta Dashboard Field | Location in Meta Dashboard | Exact URL to Configure |
| :--- | :--- | :--- |
| **Valid OAuth Redirect URIs** | Instagram > Basic Display / API Setup > Valid OAuth Redirect URIs | `https://YOUR-NGROK-DOMAIN.ngrok-free.app/api/v1/instagram/callback` |
| **Webhook Callback URL** | Webhooks > Instagram > Edit Subscription | `https://YOUR-NGROK-DOMAIN.ngrok-free.app/api/v1/instagram/webhook` |
| **Verify Token** | Webhooks > Instagram > Edit Subscription | Value of `META_VERIFY_TOKEN` (e.g. `woka_local_webhook_verify_token_2026`) |
| **Deauthorize Callback URL** | App Settings > Basic > Data Protection / Deauthorize | `https://YOUR-NGROK-DOMAIN.ngrok-free.app/api/v1/instagram/deauthorize` |
| **Data Deletion Request URL** | App Settings > Basic > User Data Deletion | `https://YOUR-NGROK-DOMAIN.ngrok-free.app/api/v1/instagram/data-deletion` |

> **Live Inspection:** Visit `http://localhost:8000/api/v1/instagram/endpoints-info` at any time to inspect your active resolved URLs.

---

## 6. Verification & Health Probes

Verify the local environment with these checks:

```powershell
# 1. Container liveness probe
curl http://localhost:8000/healthz

# 2. Database readiness probe
curl http://localhost:8000/readyz

# 3. Dynamic ngrok endpoints inspection
curl http://localhost:8000/api/v1/instagram/endpoints-info

# 4. Meta Webhook challenge verification (simulated)
curl "http://localhost:8000/api/v1/instagram/webhook?hub.mode=subscribe&hub.challenge=test_challenge_123&hub.verify_token=woka_local_webhook_verify_token_2026"
# Output must be: test_challenge_123

# 5. User data deletion check
curl "http://localhost:8000/api/v1/instagram/deletion-status?code=woka_del_test123"
```

---

## 7. Running the Automated Test Suites

### Backend Tests (112 Tests)
```powershell
.\backend\venv\Scripts\python.exe -m pytest -o pythonpath=backend -v
```
Result: **112 passed, 1 skipped**

### Frontend Tests (14 Tests)
```powershell
npm --prefix frontend test
```
Result: **14 passed**

### TypeScript Type Check
```powershell
.\frontend\node_modules\.bin\tsc.cmd --project frontend/tsconfig.json --noEmit
```
Result: **0 errors**

---

## 8. Troubleshooting

| Issue | Cause | Resolution |
| :--- | :--- | :--- |
| **Docker not installed or not running** | Docker Desktop engine is stopped | Use SQLite fallback: set `DATABASE_URL=sqlite:///./woka.db` in `backend/.env`. |
| **ngrok URL changed after restart** | Free ngrok sessions assign a new domain per run | Update `BACKEND_PUBLIC_URL` in `backend/.env` and update the Redirect URI in the Meta Developer Portal. Alternatively, claim a static free domain at [ngrok.com](https://dashboard.ngrok.com/cloud-edge/domains). |
| **OAuth State / CSRF Mismatch** | Tampered state or session > 15 mins old | Click **Connect Instagram** again from `http://localhost:3000/dashboard/instagram` to generate a fresh HMAC-signed token. |
| **Port 8000 or 3000 already in use** | Another local process is holding the port | Run `netstat -ano \| findstr :8000` to find the PID and terminate with `taskkill /PID <PID> /F`. |
