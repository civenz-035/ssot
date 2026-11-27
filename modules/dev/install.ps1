<#
.SYNOPSIS
    Install and setup OpenCode + AWS Bedrock Mantle Proxy on Windows (SSOT Node).
.DESCRIPTION
    Installs Python dependencies, deploys proxy script, and writes ~/.config/opencode/opencode.jsonc.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Write-Info { Write-Host "[INSTALL] $args" -ForegroundColor Cyan }
function Write-Ok   { Write-Host "[INSTALL] ✓ $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[INSTALL] ⚠ $args" -ForegroundColor Yellow }
function Write-Err  { Write-Host "[INSTALL] ✗ $args" -ForegroundColor Red }

Write-Info "Setting up OpenCode + AWS Bedrock Mantle Proxy on Windows..."

$UserHome = $env:USERPROFILE
$AwsDir = Join-Path $UserHome ".aws"
$OpenCodeConfigDir = Join-Path $UserHome ".config\opencode"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (!(Test-Path $AwsDir)) {
    New-Item -ItemType Directory -Path $AwsDir -Force | Out-Null
}
if (!(Test-Path $OpenCodeConfigDir)) {
    New-Item -ItemType Directory -Path $OpenCodeConfigDir -Force | Out-Null
}
Write-Ok "Target directories verified: $AwsDir, $OpenCodeConfigDir"

$PythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (!$PythonCmd) {
    $PythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
}
if (!$PythonCmd) {
    Write-Err "Python is not installed or not in PATH! Please install Python 3.9+."
    exit 1
}
Write-Ok "Found Python: $($PythonCmd.Source)"

$RequiredPkgs = @("fastapi", "uvicorn", "httpx", "botocore", "requests")
$MissingPkgs = @()
foreach ($pkg in $RequiredPkgs) {
    & python -c "import $pkg" 2>$null
    if ($LASTEXITCODE -ne 0) {
        $MissingPkgs += $pkg
    }
}

if ($MissingPkgs.Count -gt 0) {
    Write-Warn "Installing missing Python packages: $($MissingPkgs -join ' ')..."
    & python -m pip install --quiet $MissingPkgs
    Write-Ok "Python packages installed successfully."
} else {
    Write-Ok "All Python dependencies are already installed."
}

# Copy proxy script to ~/.aws
Copy-Item (Join-Path $ScriptDir "bedrock_mantle_proxy.py") (Join-Path $AwsDir "bedrock_mantle_proxy.py") -Force
Write-Ok "Proxy script copied to $AwsDir\bedrock_mantle_proxy.py"

# Deploy Windows start_proxy.bat launcher
$StartBat = Join-Path $AwsDir "start_proxy.bat"
$BatContent = @"
@echo off
start "" /b python "%~dp0bedrock_mantle_proxy.py"
"@
Set-Content -Path $StartBat -Value $BatContent -Encoding ascii
Write-Ok "Launcher generated at: $StartBat"

# Write opencode.jsonc
$OpencodeJsonc = Join-Path $OpenCodeConfigDir "opencode.jsonc"
$ConfigContent = @"
{
  "`$schema": "https://opencode.ai/config.json",
  "shell": "bash",
  "provider": {
    "bedrock-mantle": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Bedrock Mantle (Local SigV4)",
      "options": {
        "baseURL": "http://127.0.0.1:4098/v1",
        "apiKey": "sigv4-local"
      },
      "models": {
        "qwen.qwen3-coder-480b-a35b-instruct": {
          "name": "Qwen 3 Coder 480B (Top Coding)"
        },
        "qwen.qwen3-coder-next": {
          "name": "Qwen 3 Coder Next"
        },
        "deepseek.v3.2": {
          "name": "DeepSeek V3.2 (Latest)"
        },
        "deepseek.v3.1": {
          "name": "DeepSeek V3.1"
        },
        "moonshotai.kimi-k2.5": {
          "name": "Kimi K2.5"
        },
        "moonshotai.kimi-k2-thinking": {
          "name": "Kimi K2 Thinking (Reasoning)"
        },
        "openai.gpt-oss-120b": {
          "name": "GPT-OSS 120B (Flagship)"
        },
        "openai.gpt-oss-20b": {
          "name": "GPT-OSS 20B (Fast)"
        },
        "mistral.mistral-large-3-675b-instruct": {
          "name": "Mistral Large 3 675B"
        },
        "mistral.devstral-2-123b": {
          "name": "Devstral 2 123B (Code Specialist)"
        },
        "google.gemma-3-27b-it": {
          "name": "Google Gemma 3 27B"
        },
        "google.gemma-3-12b-it": {
          "name": "Google Gemma 3 12B"
        },
        "nvidia.nemotron-super-3-120b": {
          "name": "NVIDIA Nemotron Super 3 120B"
        },
        "nvidia.nemotron-nano-3-30b": {
          "name": "NVIDIA Nemotron Nano 3 30B"
        },
        "zai.glm-5": {
          "name": "ZAI GLM-5"
        },
        "zai.glm-4.7": {
          "name": "ZAI GLM-4.7"
        },
        "minimax.minimax-m2.5": {
          "name": "MiniMax M2.5"
        },
        "minimax.minimax-m2.1": {
          "name": "MiniMax M2.1"
        }
      }
    }
  },
  "mcp": {
    "browse": {
      "type": "local",
      "enabled": true,
      "command": [
        "C:\\Users\\User\\.local\\bin\\browse.exe",
        "mcp"
      ],
      "cwd": "C:\\Users\\User",
      "pool": true,
      "environment": {
        "OPENCODE_BROWSER_RUNTIME": "auto-update"
      }
    }
  }
}
"@

if (Test-Path $OpencodeJsonc) {
    Copy-Item $OpencodeJsonc "$OpencodeJsonc.bak" -Force
    Write-Info "Existing config backed up to $OpencodeJsonc.bak"
}
Set-Content -Path $OpencodeJsonc -Value $ConfigContent -Encoding utf8
Write-Ok "OpenCode configuration updated at: $OpencodeJsonc"

# Test Proxy Health
$Health = $null
try {
    $Health = Invoke-RestMethod -Uri "http://127.0.0.1:4098/health" -TimeoutSec 2 -ErrorAction Stop
} catch {
    Write-Info "Starting proxy in background..."
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $StartBat -WindowStyle Hidden
    Start-Sleep -Seconds 2
    try {
        $Health = Invoke-RestMethod -Uri "http://127.0.0.1:4098/health" -TimeoutSec 5 -ErrorAction Stop
    } catch {
        Write-Warn "Proxy started but could not confirm health. Please ensure AWS credentials (~/.aws/credentials) exist."
    }
}

if ($Health -and $Health.status -eq "ok") {
    Write-Ok "Bedrock Mantle Proxy is active and healthy on http://127.0.0.1:4098"
}

Write-Host "Setup Complete! OpenCode is ready with Bedrock Mantle." -ForegroundColor Green
