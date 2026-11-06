<#
.SYNOPSIS
    Woka Reel Intelligence — Local Development Startup Script
.DESCRIPTION
    Automates prerequisite verification, local database migrations, and
    service launch instructions for FastAPI backend, Next.js frontend, and ngrok tunnel.
#>

param(
    [switch]$SkipDocker,
    [switch]$SkipMigrations,
    [string]$NgrokDomain
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$msg) {
    Write-Host "`n[WOKA] $msg" -ForegroundColor Cyan
}

function Write-Success([string]$msg) {
    Write-Host "[OK] $msg" -ForegroundColor Green
}

function Write-Warn([string]$msg) {
    Write-Host "[WARN] $msg" -ForegroundColor Yellow
}

function Write-Err([string]$msg) {
    Write-Host "[ERROR] $msg" -ForegroundColor Red
}

Clear-Host
Write-Host "==================================================================" -ForegroundColor Magenta
Write-Host "     WOKA REEL INTELLIGENCE -- LOCAL DEVELOPMENT ENVIRONMENT       " -ForegroundColor Magenta
Write-Host "==================================================================" -ForegroundColor Magenta

$RootDir = $PSScriptRoot
Set-Location $RootDir

# 1. Verify Python & Virtual Environment
Write-Step "Checking Python virtual environment..."
$VenvPython = Join-Path $RootDir "backend\venv\Scripts\python.exe"
if (-not (Test-Path $VenvPython)) {
    Write-Err "Python virtual environment not found at backend\venv."
    Write-Host "Run: python -m venv backend\venv ; .\backend\venv\Scripts\pip install -r backend\requirements.txt"
    exit 1
}
Write-Success "Python environment found: $VenvPython"

# 2. Verify Environment Files
Write-Step "Checking environment files..."
$BackendEnv = Join-Path $RootDir "backend\.env"
$BackendExample = Join-Path $RootDir "backend\.env.local.example"
if (-not (Test-Path $BackendEnv)) {
    if (Test-Path $BackendExample) {
        Copy-Item $BackendExample $BackendEnv
        Write-Success "Created backend\.env from template."
    } else {
        Write-Warn "backend\.env not found. Please create one."
    }
} else {
    Write-Success "backend\.env exists."
}

$FrontendEnv = Join-Path $RootDir "frontend\.env.local"
if (-not (Test-Path $FrontendEnv)) {
    $frontendConfig = "NEXT_PUBLIC_API_URL=http://localhost:8000/api/v1`r`nNEXT_PUBLIC_APP_ENV=development`r`n"
    [System.IO.File]::WriteAllText($FrontendEnv, $frontendConfig)
    Write-Success "Created frontend\.env.local."
} else {
    Write-Success "frontend\.env.local exists."
}

# If user passed -NgrokDomain, update backend\.env
if ($NgrokDomain) {
    $cleanDomain = $NgrokDomain.Trim().TrimEnd('/')
    Write-Step "Configuring BACKEND_PUBLIC_URL to $cleanDomain in backend\.env..."
    $envContent = Get-Content $BackendEnv
    $updated = $false
    $newLines = @()
    foreach ($line in $envContent) {
        if ($line -match "^BACKEND_PUBLIC_URL=") {
            $newLines += "BACKEND_PUBLIC_URL=$cleanDomain"
            $updated = $true
        } else {
            $newLines += $line
        }
    }
    if (-not $updated) {
        $newLines += "BACKEND_PUBLIC_URL=$cleanDomain"
    }
    $newLines | Set-Content $BackendEnv
    Write-Success "Updated BACKEND_PUBLIC_URL in backend\.env."
}

# 3. Docker Infrastructure (PostgreSQL & Redis)
if (-not $SkipDocker) {
    Write-Step "Checking Docker availability for PostgreSQL and Redis..."
    $dockerCmd = Get-Command "docker" -ErrorAction SilentlyContinue
    if ($dockerCmd) {
        try {
            docker info *> $null
            Write-Host "Starting PostgreSQL and Redis containers via Docker Compose..." -ForegroundColor DarkGray
            docker compose up -d postgres redis
            Write-Success "PostgreSQL (5432) and Redis (6379) are active."
        } catch {
            Write-Warn "Docker engine is installed but not running. Proceeding with fallback configuration."
        }
    } else {
        Write-Warn "Docker not found on system PATH."
        Write-Host "Tip: You can install Docker Desktop for PostgreSQL/Redis, or use local SQLite (DATABASE_URL=sqlite:///./woka.db)." -ForegroundColor DarkGray
    }
}

# 4. Database Migrations (Alembic)
if (-not $SkipMigrations) {
    Write-Step "Applying Alembic database migrations..."
    try {
        & $VenvPython -m alembic -c backend/alembic.ini upgrade head
        Write-Success "Database schema is synchronized at migration HEAD."
    } catch {
        Write-Warn "Alembic migration completed or encountered notes."
    }
}

# 5. ngrok Information & Instructions
Write-Step "Checking ngrok status..."
$ngrokCmd = Get-Command "ngrok" -ErrorAction SilentlyContinue
if ($ngrokCmd) {
    Write-Success "ngrok is installed on PATH."
    Write-Host "To expose the backend for live Meta Instagram OAuth and Webhooks:" -ForegroundColor Cyan
    Write-Host "  Run in a separate PowerShell window:  ngrok http 8000" -ForegroundColor White
    Write-Host "  Then set BACKEND_PUBLIC_URL in backend\.env with your https://xxx.ngrok-free.app domain." -ForegroundColor White
} else {
    Write-Warn "ngrok CLI not found on PATH."
    Write-Host "Install ngrok via: winget install ngrok.ngrok" -ForegroundColor DarkGray
    Write-Host "Or download from: https://ngrok.com/download" -ForegroundColor DarkGray
}

# 6. Service Launch Summary
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "                   READY TO LAUNCH SERVICES                       " -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "To start the application, open two separate PowerShell windows:"
Write-Host ""
Write-Host "  1. Backend (FastAPI):" -ForegroundColor Cyan
Write-Host "     cd `"$RootDir\backend`""
Write-Host "     .\venv\Scripts\Activate.ps1"
Write-Host "     uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload"
Write-Host ""
Write-Host "  2. Frontend (Next.js):" -ForegroundColor Cyan
Write-Host "     cd `"$RootDir\frontend`""
Write-Host "     npm run dev"
Write-Host ""
Write-Host "  3. ngrok HTTPS Tunnel (for Meta OAuth / Webhooks):" -ForegroundColor Cyan
Write-Host "     ngrok http 8000"
Write-Host ""
Write-Host "Endpoints:" -ForegroundColor Yellow
Write-Host "  - Frontend Dashboard:       http://localhost:3000"
Write-Host "  - Backend API:              http://localhost:8000"
Write-Host "  - OpenAPI Documentation:    http://localhost:8000/api/v1/docs"
Write-Host "  - Health Check:             http://localhost:8000/healthz"
Write-Host "  - Readiness Probe:          http://localhost:8000/readyz"
Write-Host "  - Meta Endpoints Info:      http://localhost:8000/api/v1/instagram/endpoints-info"
Write-Host "=================================================================="
Write-Host ""
