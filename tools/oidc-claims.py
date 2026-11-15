#!/usr/bin/env python3
"""Print the non-secret claims of this job's GitHub OIDC token.

Run it when assuming an AWS role fails: the role's trust policy must match `aud` and
`sub` exactly, and the only way to see what GitHub really issues is to look at a token.
The token itself is masked and never printed. The job needs `permissions: id-token: write`.
Standard library only.
"""
import base64
import json
import os
import sys
import urllib.request

SHOW = ("iss", "aud", "sub", "event_name", "ref", "repository", "repository_id",
        "repository_owner", "repository_owner_id", "job_workflow_ref", "environment")

url = os.environ.get("ACTIONS_ID_TOKEN_REQUEST_URL")
bearer = os.environ.get("ACTIONS_ID_TOKEN_REQUEST_TOKEN")
if not url or not bearer:
    sys.exit("no OIDC request URL or token: the job needs `permissions: id-token: write`")

req = urllib.request.Request(f"{url}&audience=sts.amazonaws.com",
                             headers={"Authorization": f"Bearer {bearer}"})
jwt = json.load(urllib.request.urlopen(req, timeout=30))["value"]
print(f"::add-mask::{jwt}", flush=True)  # from here on the runner hides the token in the log

payload = jwt.split(".")[1]
claims = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
print("OIDC claims of this job (trust policy conditions must equal aud and sub):")
for key in SHOW:
    if key in claims:
        print(f"  {key}: {claims[key]}")
