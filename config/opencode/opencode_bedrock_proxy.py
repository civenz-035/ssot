#!/usr/bin/env python3
"""
OpenCode Bedrock Proxy Manager - SSOT Mesh Edition
Manages AWS Bedrock Mantle proxy across multiple SSOT nodes.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional
import urllib.request
import urllib.error

# ── SSOT-aware paths ──
def get_ssot_root() -> Optional[Path]:
    """Find SSOT root from environment or common locations"""
    ssot_paths = [
        os.environ.get("SSOT_ROOT"),
        "~/ssot",
        "~/.ssot",
        "~/git/ssot",
    ]
    
    for path in ssot_paths:
        if path:
            expanded = Path(path).expanduser()
            if (expanded / "AGENTS.md").exists():
                return expanded
    return None

SSOT_ROOT = get_ssot_root()
IS_SSH_SESSION = "SSH_CONNECTION" in os.environ or "SSH_CLIENT" in os.environ

# ── Standard paths ──
AWS_DIR = Path.home() / ".aws"
CONFIG_DIR = Path.home() / ".config" / "opencode"
PROXY_SCRIPT = AWS_DIR / "bedrock_mantle_proxy.py"
PID_FILE = AWS_DIR / "bedrock_mantle_proxy.pid"
SETTINGS_FILE = CONFIG_DIR / "settings.json"


def load_config() -> dict:
    """Load config from SSOT or local"""
    # Try SSOT first
    if SSOT_ROOT:
        ssot_config = SSOT_ROOT / "config" / "opencode" / "settings.json"
        if ssot_config.exists():
            with open(ssot_config, "r", encoding="utf-8") as f:
                config = json.load(f)
                config["_config_source"] = "ssot"
                return config
    
    # Fallback to local
    if SETTINGS_FILE.exists():
        with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
            config = json.load(f)
            config["_config_source"] = "local"
            return config
    
    return {"_config_source": "default"}


def is_proxy_running(host: str = "127.0.0.1", port: int = 4098) -> bool:
    """Check proxy health"""
    try:
        url = f"http://{host}:{port}/health"
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=5) as response:
            return response.status == 200
    except:
        return False


def start_proxy(config: dict) -> bool:
    """Start proxy with SSOT-aware configuration"""
    proxy_config = config.get("bedrock_mantle_proxy", {})
    
    if not proxy_config.get("enabled", True):
        print("[SSOT-Proxy] Disabled in config")
        return False
    
    host = proxy_config.get("host", "127.0.0.1")
    port = proxy_config.get("port", 4098)
    region = proxy_config.get("region", "ap-southeast-2")
    
    # Check if already running
    if is_proxy_running(host, port):
        print(f"[SSOT-Proxy] ✓ Already running at {host}:{port}")
        # Print SSOT status if available
        try:
            url = f"http://{host}:{port}/ssot/status"
            with urllib.request.urlopen(url, timeout=2) as response:
                status = json.loads(response.read().decode())
                if status.get("ssot_managed"):
                    print(f"[SSOT-Proxy] SSOT managed: {status.get('region', 'unknown')}")
        except:
            pass
        return True
    
    # Determine which proxy script to use
    python_script = proxy_config.get("python_script", str(PROXY_SCRIPT))
    python_script = os.path.expandvars(python_script)
    
    # If SSOT available, symlink scripts
    if SSOT_ROOT:
        ssot_proxy = SSOT_ROOT / "config" / "opencode" / "bedrock_mantle_proxy.py"
        if ssot_proxy.exists() and not PROXY_SCRIPT.exists():
            try:
                # On Windows, copy instead of symlink
                if sys.platform == "win32":
                    import shutil
                    shutil.copy2(ssot_proxy, PROXY_SCRIPT)
                else:
                    PROXY_SCRIPT.symlink_to(ssot_proxy)
                print(f"[SSOT-Proxy] Synced from SSOT")
            except Exception as e:
                print(f"[SSOT-Proxy] Warning: Could not sync from SSOT: {e}")
        python_script = str(PROXY_SCRIPT)
    
    if not Path(python_script).exists():
        print(f"[SSOT-Proxy] ✗ Proxy script not found: {python_script}")
        return False
    
    print(f"[SSOT-Proxy] Starting on {host}:{port} ({region})...")
    
    # Setup environment
    env = os.environ.copy()
    env_vars = proxy_config.get("environment", {})
    for key, value in env_vars.items():
        env[key] = os.path.expandvars(str(value))
    
    # Mark as SSOT if applicable
    if SSOT_ROOT:
        env["SSOT_CONFIG_SOURCE"] = str(SSOT_ROOT)
    
    try:
        if sys.platform == "win32":
            # Windows: hide console
            creation_flags = getattr(subprocess, "CREATE_NO_WINDOW", 0x08000000)
            process = subprocess.Popen(
                [sys.executable, python_script],
                env=env,
                cwd=str(AWS_DIR),
                creationflags=creation_flags,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        else:
            # Unix: background process
            process = subprocess.Popen(
                [sys.executable, python_script],
                env=env,
                cwd=str(AWS_DIR),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        
        # Save PID
        with open(PID_FILE, "w") as f:
            f.write(str(process.pid))
        
        # Wait for ready
        max_wait = proxy_config.get("health_check", {}).get("timeout_seconds", 10)
        start_time = time.time()
        
        while time.time() - start_time < max_wait:
            if is_proxy_running(host, port):
                print(f"[SSOT-Proxy] ✓ Ready! (PID: {process.pid})")
                return True
            time.sleep(0.5)
        
        print(f"[SSOT-Proxy] ⚠ Started but health check timed out")
        return True
        
    except Exception as e:
        print(f"[SSOT-Proxy] ✗ Error: {e}")
        return False


def stop_proxy() -> bool:
    """Stop proxy"""
    if PID_FILE.exists():
        try:
            with open(PID_FILE, "r") as f:
                pid = int(f.read().strip())
            
            if sys.platform == "win32":
                subprocess.run(["taskkill", "/PID", str(pid), "/F"], capture_output=True)
            else:
                os.kill(pid, 15)
            
            PID_FILE.unlink(missing_ok=True)
            print(f"[SSOT-Proxy] ✓ Stopped (PID: {pid})")
            return True
        except Exception as e:
            print(f"[SSOT-Proxy] ✗ Error stopping: {e}")
            return False
    else:
        print("[SSOT-Proxy] Not running")
        return True


def get_proxy_status() -> dict:
    """Get detailed status"""
    config = load_config()
    proxy_config = config.get("bedrock_mantle_proxy", {})
    host = proxy_config.get("host", "127.0.0.1")
    port = proxy_config.get("port", 4098)
    
    running = is_proxy_running(host, port)
    
    status = {
        "running": running,
        "host": host,
        "port": port,
        "region": proxy_config.get("region", "ap-southeast-2"),
        "url": f"http://{host}:{port}",
        "config_source": config.get("_config_source", "unknown"),
        "ssot_root": str(SSOT_ROOT) if SSOT_ROOT else None,
    }
    
    if running:
        try:
            url = f"http://{host}:{port}/health"
            with urllib.request.urlopen(url, timeout=3) as response:
                health = json.loads(response.read().decode())
                status["health"] = health
        except:
            pass
    
    # Check SSH session
    if IS_SSH_SESSION:
        status["ssh_session"] = True
    
    return status


def ssot_sync():
    """Sync config from SSOT to local"""
    if not SSOT_ROOT:
        print("[SSOT-Proxy] ✗ SSOT not found")
        return False
    
    src_config = SSOT_ROOT / "config" / "opencode" / "settings.json"
    src_proxy = SSOT_ROOT / "config" / "opencode" / "bedrock_mantle_proxy.py"
    src_manager = SSOT_ROOT / "config" / "opencode" / "opencode_bedrock_proxy.py"
    
    # Ensure directories exist
    AWS_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    (CONFIG_DIR / "agents").mkdir(parents=True, exist_ok=True)
    
    copied = []
    
    # Copy config
    if src_config.exists():
        import shutil
        shutil.copy2(src_config, SETTINGS_FILE)
        copied.append("settings.json")
    
    # Copy proxy scripts
    for src, dst in [(src_proxy, PROXY_SCRIPT), (src_manager, AWS_DIR / "opencode_bedrock_proxy.py")]:
        if src.exists():
            import shutil
            shutil.copy2(src, dst)
            copied.append(dst.name)
    
    if copied:
        print(f"[SSOT-Proxy] ✓ Synced: {', '.join(copied)}")
        return True
    else:
        print("[SSOT-Proxy] ⚠ Nothing to sync")
        return False


def main():
    """CLI"""
    if len(sys.argv) < 2:
        print("Usage: opencode_bedrock_proxy.py <command>")
        print("")
        print("Commands:")
        print("  start     - Start the proxy")
        print("  stop      - Stop the proxy")
        print("  status    - Check status")
        print("  restart   - Restart the proxy")
        print("  sync      - Sync config from SSOT")
        print("")
        print("Environment:")
        print(f"  SSOT_ROOT: {SSOT_ROOT or 'not found'}")
        print(f"  SSH_SESSION: {IS_SSH_SESSION}")
        return
    
    command = sys.argv[1].lower()
    config = load_config()
    
    if command == "start":
        success = start_proxy(config)
        sys.exit(0 if success else 1)
    
    elif command == "stop":
        success = stop_proxy()
        sys.exit(0 if success else 1)
    
    elif command == "status":
        status = get_proxy_status()
        print(json.dumps(status, indent=2))
    
    elif command == "restart":
        stop_proxy()
        time.sleep(1)
        success = start_proxy(config)
        sys.exit(0 if success else 1)
    
    elif command == "sync":
        success = ssot_sync()
        sys.exit(0 if success else 1)
    
    else:
        print(f"[SSOT-Proxy] ✗ Unknown command: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()
