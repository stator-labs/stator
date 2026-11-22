#!/usr/bin/env python3
"""Mint a 1-hour GitHub App installation token for stator-bot.

Reads the App ID from STATOR_BOT_APP_ID or ~/.config/stator/app-id, and the
private key from STATOR_BOT_KEY_PATH or ~/.config/stator/stator-bot.pem.
Prints `export GH_TOKEN=<token>` to stdout for `eval "$(python3 tools/bot-token.py)"`.
Never prints the token to stderr or logs.

Standard library + openssl CLI only.
Usage:
  eval "$(python3 tools/bot-token.py)"
  python3 tools/bot-token.py --self-test
"""
import base64
import json
import os
import subprocess
import sys
import time
import urllib.request
from pathlib import Path


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def build_jwt_unsigned(app_id: str, now: int) -> str:
    hdr = b64url(json.dumps({"alg": "RS256", "typ": "JWT"}, separators=(",", ":")).encode())
    pay = b64url(json.dumps({"iat": now - 60, "exp": now + 540, "iss": str(app_id)}, separators=(",", ":")).encode())
    return f"{hdr}.{pay}"


def resolve_app_id() -> str:
    if env_id := os.environ.get("STATOR_BOT_APP_ID", "").strip():
        return env_id
    id_file = Path.home() / ".config/stator/app-id"
    if id_file.is_file():
        return id_file.read_text(encoding="utf-8").strip()
    sys.exit("bot-token: set STATOR_BOT_APP_ID or write it once to ~/.config/stator/app-id")


def resolve_key_path() -> Path:
    raw = os.environ.get("STATOR_BOT_KEY_PATH", "~/.config/stator/stator-bot.pem")
    path = Path(raw).expanduser()
    if not path.is_file():
        sys.exit(f"bot-token: private key not found at {path}")
    return path


def api(path: str, jwt: str, method: str = "GET") -> object:
    req = urllib.request.Request(
        f"https://api.github.com{path}",
        method=method,
        headers={
            "Authorization": f"Bearer {jwt}",
            "Accept": "application/vnd.github+json",
            "User-Agent": "stator-bot-token",
        },
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.load(resp)


def self_test() -> int:
    unsigned = build_jwt_unsigned("123456", 1700000000)
    parts = unsigned.split(".")
    if len(parts) != 2:
        print("bot-token: self-test failed (expected 2 JWT parts)", file=sys.stderr)
        return 1
    pay = json.loads(base64.urlsafe_b64decode(parts[1] + "=="))
    if pay.get("iss") != "123456" or pay.get("exp") - pay.get("iat") != 600:
        print("bot-token: self-test failed (bad payload claims)", file=sys.stderr)
        return 1
    print("bot-token: self-test OK")
    return 0


def main() -> int:
    if sys.argv[1:] == ["--self-test"]:
        return self_test()
    app_id = resolve_app_id()
    key_path = resolve_key_path()
    unsigned = build_jwt_unsigned(app_id, int(time.time()))
    sig_bytes = subprocess.check_output(
        ["openssl", "dgst", "-sha256", "-sign", str(key_path)],
        input=unsigned.encode("ascii"),
    )
    jwt = f"{unsigned}.{b64url(sig_bytes)}"
    installs = api("/app/installations", jwt)
    if not isinstance(installs, list) or not installs:
        sys.exit("bot-token: no installations found for this GitHub App")
    inst_id = installs[0]["id"]
    token_resp = api(f"/app/installations/{inst_id}/access_tokens", jwt, method="POST")
    token = token_resp["token"]
    print(f"export GH_TOKEN={token}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
