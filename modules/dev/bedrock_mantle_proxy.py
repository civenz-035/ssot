"""Local OpenAI-compatible SigV4 proxy for AWS Bedrock Mantle.
SSOT Module: modules/dev/bedrock_mantle_proxy.py
"""

import os
from typing import Optional

import botocore.session
import httpx
import uvicorn
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
from fastapi import FastAPI, Request, Response
from fastapi.responses import StreamingResponse

REGION = os.environ.get("BEDROCK_MANTLE_REGION", "ap-southeast-2")
ENDPOINT = f"https://bedrock-mantle.{REGION}.api.aws"
HOST = os.environ.get("BEDROCK_PROXY_HOST", "127.0.0.1")
PORT = int(os.environ.get("BEDROCK_PROXY_PORT", "4098"))

app = FastAPI(title="Bedrock Mantle SigV4 Proxy")
_client: Optional[httpx.AsyncClient] = None


@app.on_event("startup")
async def _startup() -> None:
    global _client
    _client = httpx.AsyncClient(timeout=httpx.Timeout(300.0, connect=30.0))
    print(f"[SSOT-Proxy] Started on {HOST}:{PORT} ({REGION})")


@app.on_event("shutdown")
async def _shutdown() -> None:
    if _client is not None:
        await _client.aclose()


def _sign_headers(method: str, url: str, body: bytes, content_type: Optional[str]) -> dict[str, str]:
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


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "endpoint": ENDPOINT, "region": REGION}


@app.api_route("/{full_path:path}", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"])
async def proxy(full_path: str, request: Request) -> Response:
    assert _client is not None
    query = request.url.query
    target_url = f"{ENDPOINT}/{full_path}" + (f"?{query}" if query else "")
    body = await request.body()
    content_type = request.headers.get("content-type", "application/json" if body else None)
    signed_headers = _sign_headers(request.method, target_url, body, content_type)

    req = _client.build_request(
        method=request.method,
        url=target_url,
        content=body if body else None,
        headers=signed_headers,
    )
    upstream = await _client.send(req, stream=True)

    resp_headers = {
        k: v
        for k, v in upstream.headers.items()
        if k.lower() not in {"transfer-encoding", "connection", "content-encoding", "content-length"}
    }

    async def _iter_stream():
        try:
            async for chunk in upstream.aiter_raw():
                yield chunk
        finally:
            await upstream.aclose()

    return StreamingResponse(
        _iter_stream(),
        status_code=upstream.status_code,
        headers=resp_headers,
        media_type=upstream.headers.get("content-type"),
    )


if __name__ == "__main__":
    uvicorn.run(app, host=HOST, port=PORT, log_level="warning")
