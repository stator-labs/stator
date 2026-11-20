# tools/

- `docs-lint.py`: checks the docs size, links, lab status sync and writing style (`python3 tools/docs-lint.py`).
- `tofu-stacks.py`: lists OpenTofu stacks for the plan and apply workflow, and checks each has its own S3 state key.
- `reaper.py`: turns the tagging API output into the nightly reaper's dry-run report. It deletes nothing and hides account numbers.
- `oidc-claims.py`: prints the non-secret claims of a job's GitHub OIDC token, to debug AWS role trust policies.
- `cloud-setup.sh`: pinned, SHA256-checked tool install for the Cloud-Project environment and CI.
- `checkov/`: custom checkov check `CKV_RUNWAY_1`, which requires `default_tags` on every AWS provider.
