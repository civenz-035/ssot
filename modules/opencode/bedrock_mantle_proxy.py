"""Local OpenAI-compatible SigV4 proxy for AWS Bedrock Mantle.
SSOT Module: modules/opencode/bedrock_mantle_proxy.py
Standard Library HTTP server + urllib (Zero external web framework dependencies)
Only requires: botocore for AWS SigV4 signing
"""

import sys
import os

# ── Neutralize broken system pyOpenSSL (Ubuntu/WSL2 python3-openssl bug) ──
# Prevents: AttributeError: module 'lib' has no attribute 'GEN_EMAIL'
# Cause: botocore → urllib3 → urllib3.contrib.pyopenssl → broken system OpenSSL
# Fix: inject a stub before botocore loads so urllib3 skips pyOpenSSL backend.
def _patch_broken_openssl():
    try:
        import OpenSSL  # noqa: F401
    except (AttributeError, ImportError, Exception):
        import types
        _stub = types.ModuleType("OpenSSL")
        _stub.SSL = types.ModuleType("OpenSSL.SSL")
        _stub.crypto = types.ModuleType("OpenSSL.crypto")
        sys.modules.setdefault("OpenSSL", _stub)
        sys.modules.setdefault("OpenSSL.SSL", _stub.SSL)
        sys.modules.setdefault("OpenSSL.crypto", _stub.crypto)

_patch_broken_openssl()

import http.server
import json
import os
import socketserver
import urllib.error
import urllib.request
from typing import Optional

import botocore.session
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

REGION = os.environ.get("BEDROCK_MANTLE_REGION", "ap-southeast-2")
ENDPOINT = f"https://bedrock-mantle.{REGION}.api.aws"
HOST = os.environ.get("BEDROCK_PROXY_HOST", "127.0.0.1")
PORT = int(os.environ.get("BEDROCK_PROXY_PORT", "4098"))


def _sign_headers(method: str, url: str, body: bytes, content_type: Optional[str]) -> dict:
    session = botocore.session.get_session()
    creds = session.get_credentials()
    if creds is None:
        raise RuntimeError("No AWS credentials found for SigV4 signing. Check ~/.aws/credentials.")
    frozen = creds.get_frozen_credentials()
    headers = {}
    if content_type:
        headers["Content-Type"] = content_type
    aws_req = AWSRequest(method=method, url=url, data=body, headers=headers)
    SigV4Auth(frozen, "bedrock-mantle", REGION).add_auth(aws_req)
    return dict(aws_req.headers)


class ProxyHandler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format, *args):
        # Silence standard access logs, keep output clean
        pass

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        if self.path == "/health":
            body = json.dumps({"status": "ok", "endpoint": ENDPOINT, "region": REGION}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        self._forward_request("GET", None)

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length > 0 else None
        self._forward_request("POST", body)

    def _forward_request(self, method: str, body: Optional[bytes]):
        path = self.path
        if path.startswith("/"):
            path = path[1:]
        target_url = f"{ENDPOINT}/{path}"

        content_type = self.headers.get("Content-Type", "application/json" if body else None)
        try:
            signed_headers = _sign_headers(method, target_url, body or b"", content_type)
        except Exception as e:
            err_msg = json.dumps({"error": str(e)}).encode("utf-8")
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(err_msg)))
            self.end_headers()
            self.wfile.write(err_msg)
            return

        req = urllib.request.Request(target_url, data=body, headers=signed_headers, method=method)

        try:
            with urllib.request.urlopen(req, timeout=300) as resp:
                resp_body = resp.read()
                self.send_response(resp.status)
                for k, v in resp.getheaders():
                    if k.lower() not in {"transfer-encoding", "connection", "content-encoding", "content-length"}:
                        self.send_header(k, v)
                self.send_header("Access-Control-Allow-Origin", "*")
                self.send_header("Content-Length", str(len(resp_body)))
                self.end_headers()
                self.wfile.write(resp_body)
        except urllib.error.HTTPError as e:
            err_body = e.read()
            self.send_response(e.code)
            for k, v in e.headers.items():
                if k.lower() not in {"transfer-encoding", "connection", "content-encoding", "content-length"}:
                    self.send_header(k, v)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Content-Length", str(len(err_body)))
            self.end_headers()
            self.wfile.write(err_body)
        except Exception as e:
            err_msg = json.dumps({"error": f"Upstream error: {e}"}).encode("utf-8")
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(err_msg)))
            self.end_headers()
            self.wfile.write(err_msg)


class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


if __name__ == "__main__":
    print(f"[SSOT-Proxy] Starting server on {HOST}:{PORT} (Region: {REGION})...")
    with ThreadedHTTPServer((HOST, PORT), ProxyHandler) as httpd:
        print(f"[SSOT-Proxy] Server ready at http://{HOST}:{PORT}")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n[SSOT-Proxy] Stopping...")
            httpd.server_close()
