# tools/

- `docs-lint.py`: checks the docs size, links, lab status sync and writing style (`python3 tools/docs-lint.py`).
- `specs-lint.py`: validates `specs/` line caps, `INDEX.md` links, relative links, deltas, and task Context Manifest budgets (`python3 tools/specs-lint.py`).
- `identifier-check.py`: fails when a tracked file holds an AWS account number or access key ID. It never prints the value. Runs in `Docs: lint`.
- `tofu-stacks.py`: lists OpenTofu stacks from `platform/stacks.json` (`all`, `ci`, `changed`) and checks every stack is listed with its own S3 state key.
- `reaper.py`: turns the tagging API output into the nightly reaper's dry-run report. It deletes nothing and hides account numbers.
- `oidc-claims.py`: prints the non-secret claims of a job's GitHub OIDC token, to debug AWS role trust policies.
- `bot-token.py`: mints a 1-hour `GH_TOKEN` from `~/.config/stator/stator-bot.pem` and `~/.config/stator/app-id` (`eval "$(python3 tools/bot-token.py)"`).
- `plan-gate.py`: classifies an OpenTofu plan JSON (`tofu show -json tfplan`) into `auto` (`aws-apply-auto`), `manual` (`aws-apply`), or `deny` (hard policy failure). Rules come from `platform/stacks.json` on `main`. Denies NotAction, forbidden actions, lab roles without `stator-boundary` or outside `/stator/workload/`; sends unknown-at-plan policies to manual.
- `provider-allowlist.py` (list in `platform/stacks.json`): refuses a stack whose lockfile lists a provider outside the allowlist, or that commits `.terraform/` or `terraform.d/`. The plan workflow runs it from `main` before `tofu init`.
- `apply-alert.sh`: keeps one "Infrastructure: main is failing" issue open while a main plan or apply fails, and closes it after a clean apply.
- `cloud-setup.sh`: pinned, SHA256-checked tool install for the Cloud-Project environment and CI.
- `antigravity-setup.sh`: user-space install for Antigravity cloud VMs (`.agents/environment.json`), reading the same pins from `cloud-setup.sh`.
- `checkov/`: custom checkov check `CKV_RUNWAY_1`, which requires `default_tags` on every AWS provider.
