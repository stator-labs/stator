# IaC platform v2: pin trust, plan once, apply fresh

Approved by Yaaf on 2026-11-27. Replaces the hand-built CI roles, the approve-before-plan apply and three tag schemes with a design that another repo could adopt. Research: 9 notes and 2 reports (about 120 sources), summarised in the tables below. "Audit §" refers to the read-only repo audit of 2026-11-27 (kept outside git). Steps are in [tasks.md](tasks.md).

## Deltas

**MODIFIED** [STACK.md](../../STACK.md): GitHub Actions role becomes plan-all on `main`, lane-based apply, Supersede and Drift; config is `AWS_<ACCOUNT>_ACCOUNT_ID` plus `AWS_REGION`.

**MODIFIED** [INVARIANTS.md](../../INVARIANTS.md): management has no CI role; `stator-boundary` lives in `labs-bootstrap`; auto-apply only in the labs account and only after the agent merge guard.
**ADDED** naming and tag rules (`project`, `lab`, `stack`, `ephemeral`; `/stator/platform/` and `/stator/workload/` paths).

**ADDED** IaC guidelines (below) as the house style for every stack.
**REMOVED** management CI roles (`runway-plan`, `runway-apply`, `runway-reaper`, `stator-foundation-*`), the management OIDC provider, and `stator-plan-main` (never applied).

## The target on one screen

- **Management account:** org policies, billing and identity. Yaaf applies it from the terminal. It has no OIDC provider and no CI role.
- **Labs account:** every CI role, the state bucket and all workloads, so SCPs and RCPs cover all of them.
- **Roles:** one `ci-roles` module creates `plan-pr`, `plan-main`, `apply` and `reaper` for each (repo, account). Each trust policy pins the repo IDs, an exact `sub` and the reusable workflow on `main`.
- **Guardrails ($0):** an SCP protects `/stator/platform/`. A boundary goes on every role that apply creates. Add an S3 RCP, an EC2 declarative policy and a tag policy.
- **Names and tags:** names follow `stator-<purpose>`. Every resource carries `project`, `lab`, `stack` and `ephemeral`.
- **Checks:** the same 4 required names. Checkov is the only scanner. The gate reads `platform/stacks.toml` from `main`.
- **Pipeline:** each merge plans every stack. `auto` applies with no click. `manual` takes one click, linked from one rolling issue.
- **No stale applies:** a HEAD check after approval, a SHA-256 check on the saved plan, OpenTofu's serial check and the gate re-run inside apply.
- **Never hunt:** Supersede cancels older waiting runs, so at most one run ever waits.
- **Migration:** 15 PR-sized steps. Disable the old apply job first, then delete the management CI roles (audit §2.4.2).

## Roles and trust

| Rule | Value | Source |
|---|---|---|
| Account placement | Management: no OIDC provider, no CI role, terminal-only. Labs: OIDC provider, all CI roles, state bucket | SCPs and RCPs do not apply in the management account ([SCP](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html), [RCP](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps.html)); escalation path in audit §2.4.2 |
| Unit | One role set per (repo, account) | [Gruntwork](https://docs.gruntwork.io/2.0/docs/accountfactory/architecture/security-controls), [RVM](https://github.com/aws-samples/role-vending-machine/blob/main/github-workflow-roles/main.tf) |
| Provider placement | OIDC provider in the same account as its roles. No hub-and-spoke | [IAM](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html) |
| Trust, every preset | `aud = sts.amazonaws.com`; `repository_owner_id` and `repository_id` StringEquals; `sub` StringEquals in the immutable `repo:owner@id/repo@id:...` form; `job_workflow_ref` StringEquals `<owner>/<repo>/.github/workflows/<file>@refs/heads/main` | [AWS condition keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_iam-condition-keys.html), [GitHub OIDC](https://docs.github.com/en/actions/reference/security/oidc) |
| `plan-pr` | `sub ...:pull_request`, workflow `plan.yml`. ReadOnlyAccess + state read. Explicit Deny `s3:GetObject` on `plans/*` and on terminal-stack state keys. No lock write: PR plans run `tofu plan -lock=false` (inference) | Fixes audit §2.4.6 and §2.4.7 |
| `plan-main` | `sub ...:ref:refs/heads/main`, workflow `plan.yml`. ReadOnlyAccess + state read + `<key>.tflock` write + `s3:PutObject` on `plans/*` + `access-analyzer:ValidatePolicy` + `tag:ListRequiredTags` | [AWS PG backend](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html) |
| `apply` | `sub ...:environment:aws-apply` or `...:environment:aws-apply-auto`, workflow `apply.yml`. PowerUserAccess + `iam-scoped`: create and manage only `role/stator/workload/*`, only with the boundary attached. Deny on `role/stator/platform/*`, on boundary policy versions, on `DeleteRolePermissionsBoundary`, and on Put/Delete of terminal-stack state and `plans/*` | Fixes audit §2.4.8 and §2.4.9 |
| `reaper` | `sub ...:ref:refs/heads/main`, workflow `reaper.yml`. `tag:GetResources` now; tag-scoped delete later. Carries `stator-boundary` | Audit §2.2 |
| Session | 3600 s, named `stator-<preset>-<run_id>-<attempt>` | RVM default ([variables.tf](https://github.com/aws-samples/role-vending-machine/blob/main/github-workflow-roles/variables.tf)) |
| Who changes roles | The `labs-bootstrap` stack only. It is terminal-only, Yaaf applies it, and agents never do (Tier 3) | RVM: "inherently very powerful" ([README](https://github.com/aws-samples/role-vending-machine/blob/main/README.md)) |
| CI config | One repo variable per account, `AWS_<ACCOUNT>_ACCOUNT_ID`, plus `AWS_REGION`. Role ARNs and the bucket name come from the naming rules. An empty variable is a hard failure | Fixes the two writers (audit §4.5) and the silent fallback to the PR role (audit §4.3) |
| Wrong-account guard | `allowed_account_ids = [var.account_id]` in every AWS provider, with the value taken from the variable | [AWS PG security](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/security.html) |
| Humans | Identity Center permission set, 1 h sessions (as today) | Audit §2.2 |

- **Why not one shared role scoped by tags?** GitHub tokens carry no session-tag claim, and the GitHub condition keys are not available in session. Repo scoping therefore has to happen in trust ([AWS session tags](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_session-tags.html)).
- **Why not merge `plan-pr` and `plan-main` (RVM does)?** Only `plan-main` may write `plans/`. If a PR-trusted role could write there, a PR could plant the file that apply later runs. RVM never hands a plan file to apply.
- **Why not a read-only foundation plan role in management?** No SCP binds it, and the state it would read holds emails (audit §2.4.1). Running `make plan` locally costs Yaaf one command.
- **Why not `terraform-aws-modules/iam` `iam-role`?** It saves about 100 lines, but it is a new dependency, and its README example matches on name-based subjects ([README](https://github.com/terraform-aws-modules/terraform-aws-iam/blob/master/modules/iam-role/README.md)). Keep a local module and its tests.
- **Accepted trade-off.** `job_workflow_ref` contains the repo name, so renaming the repo breaks trust. It fails closed, not open.

## Guardrails

| Rule | Value | Source |
|---|---|---|
| SCP `stator-protect-platform` (labs OU) | Deny role writes (`UpdateAssumeRolePolicy`, Put/Attach/Detach/DeleteRolePolicy, `DeleteRole`, Put/DeleteRolePermissionsBoundary) on `role/stator/platform/*`. Deny version changes and deletion of `stator-boundary`. Deny OIDC provider create, delete and update. Deny `DeleteBucket`, Put/DeleteBucketPolicy, `PutBucketVersioning` and `PutLifecycleConfiguration` on the state bucket. Exempt only the human admin permission-set role, with `ArnNotLike` on `aws:PrincipalArn`. Action names are inference: verify before apply | [AWS Security Blog](https://aws.amazon.com/blogs/security/how-to-use-service-control-policies-to-set-permission-guardrails-across-accounts-in-your-aws-organization), [aws-samples](https://github.com/aws-samples/service-control-policy-examples) |
| Existing SCPs | Keep `runway-labs-guardrails` (regions, commitments, instance sizes, leave org, role templates) and the deny-new-spend kill switch at $30 | Audit §2.3 |
| RCP | S3 only, for now: deny unless `aws:PrincipalOrgID` matches or the principal is an AWS service, and deny non-TLS requests. **No STS RCP until it is tested**, because the GitHub federated principal is outside the org and an org-ID perimeter could block `AssumeRoleWithWebIdentity` (inference) | [RCP](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps.html) |
| Declarative policy | EC2: require IMDSv2, block public access for snapshots and AMIs. **No VPC Block Public Access**, because labs need egress | [AWS News](https://aws.amazon.com/blogs/aws/simplify-governance-with-declarative-policies/) |
| Permissions boundary | `stator-boundary` on every role that apply creates and on `reaper`. `CreateRole` is allowed only with `iam:PermissionsBoundary` equal to its ARN. Protect the boundary policy itself (deny `DeletePolicy` and `CreatePolicyVersion`), because sources disagree on whether `DeleteRole` supports the boundary condition | [AWS boundaries blog](https://aws.amazon.com/blogs/security/when-and-where-to-use-iam-permissions-boundaries), [SAR](https://docs.aws.amazon.com/service-authorization/latest/reference/list_awsidentityandaccessmanagementiam.html) |
| Tag policy | Require `project`, `lab`, `stack` and `ephemeral` through `report_required_tag_for`. Set `tag_policy_compliance = "error"` (AWS provider 6.22.0 or later; the repo is on 6.73), because `warning` mode is silent for most resources. Free | [Organizations](https://docs.aws.amazon.com/organizations/latest/userguide/enforce-required-tag-keys-iac.html), [provider guide](https://raw.githubusercontent.com/hashicorp/terraform-provider-aws/main/website/docs/guides/tag-policy-compliance.html.markdown) |
| Access Analyzer | Keep the external-access analyzer and run `ValidatePolicy` in the plan job; both are free. Skip unused access ($0.20 per role per month), internal access ($9 per resource per Region per month) and custom checks ($0.002 per call) | [Pricing](https://aws.amazon.com/iam/access-analyzer/pricing) |
| State bucket | Block Public Access, versioning, bucket-owner-enforced, TLS-only, SSE-S3. `plans/` expires after 7 days | [AWS PG security](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/security.html) |
| Rollout | Attach to the labs OU, never the root. Watch CloudTrail for AccessDenied | [SCP](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html) |
| Management account | Nothing in management is CI-reachable, so the missing SCP coverage there does not matter | [SCP](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html) |

- **Why a separate path for platform roles?** Without it, an SCP that protects CI roles also blocks apply from managing lab roles. A path change means recreating each role (path is treated as immutable, unverified). That is cheap now, because Lab 00 has no IAM resources (audit §2.2).
- **Why not SSE-KMS with a customer managed key (as AWS PG suggests)?** The key is billed monthly, which breaks $0 idle. The bucket policy and the SCP carry the protection.
- **Why not plan encryption?** `aws_kms` needs that same paid key. `pbkdf2` puts a passphrase in both the plan and apply jobs. Instead, keep plans in the private bucket and deny `plan-pr` reads. Revisit if a stack starts holding secrets beyond emails.

## Naming and tags

| Rule | Value | Source |
|---|---|---|
| AWS names | `stator-<purpose>[-<qualifier>]`, lowercase, hyphens. Keep in names only what never changes | [null-label](https://github.com/cloudposse/terraform-null-label), [Microsoft CAF](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming) |
| IAM paths | `/stator/platform/` for CI roles and the boundary, `/stator/workload/` for roles that apply creates. Path plus name ≤ 64 characters | [IAM identifiers](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html), [IAM quotas](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_iam-quotas.html) |
| CI role names | `stator-ci-plan-pr`, `stator-ci-plan-main`, `stator-ci-apply`, `stator-ci-reaper` (IAM role names are unique per account, so v2 cannot reuse the legacy names while they exist) | Audit §3.1 |
| Inline policy names | Drawn from one list: `state-read`, `state-lock`, `plans-write`, `iam-scoped`, `tag-read` | Audit §3.1 (5 unrelated names today) |
| Buckets | Keep the existing ones. New buckets use the account regional namespace `stator-<purpose>-<acct>-<region>-an`, which leaves 37 characters for the prefix. The account ID is computed at apply time, never committed | [S3 namespaces](https://docs.aws.amazon.com/AmazonS3/latest/userguide/gpbucketnamespaces.html) |
| State keys | `<stack-id>/terraform.tfstate`, with the stack ID taken from `stacks.toml` (`lab00`, `labs-bootstrap`) | [OpenTofu S3](https://opentofu.org/docs/language/settings/backends/s3/) |
| Plan files | `plans/<run_id>-<attempt>/<stack-id>.tfplan` (keeps the PR #38 layout) | Audit §4.3 |
| Legacy `runway-*` | All go (task 13). Trust-bearing names (management state bucket, trail bucket, budgets wired to the kill switch, the admin permission set) are replaced by create-new, switch, delete, never renamed in place | [IAM identifiers](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html) |
| Required tags | `project=stator`, `lab=00..11, d, platform`, `stack=<stack-id>`, `ephemeral=true or false`. Optional `expires-at=YYYY-MM-DD` | AGENTS.md; [AWS tagging](https://docs.aws.amazon.com/tag-editor/latest/userguide/best-practices-and-strats.html) |
| Tag style | Lowercase keys, no prefix, no keys that differ only by case, no PII in values | [AWS tagging](https://docs.aws.amazon.com/tag-editor/latest/userguide/best-practices-and-strats.html) |
| Where tags are set | Provider `default_tags`. Resource `tags` only for `Name` and true specifics | [AWS PG structure](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/structure.html) |
| Cost allocation | Activate `project`, `lab` and `stack` once in management. Expect up to 48 h before data appears | [AWS Billing](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/activating-tags.html) |
| Workflows | One noun per workflow, with the file named to match: `Infrastructure`, `Plan` (`plan.yml`), `Apply` (`apply.yml`), `Supersede`, `Drift`, `Reaper`, `Policy`, `Docs`, `Workflows` | AGENTS.md; audit §3.3 (`Tofu Plan` breaks the rule) |
| Check names | `<Workflow>: <action>` in the job `name:`. One required aggregator per workflow. No matrix values in required names | [GitHub rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/troubleshooting-rules) |
| Environments | `aws-apply` (manual) and `aws-apply-auto` (auto), lowercase. Never rename one before updating its trust policy | [GitHub environments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments) |

- **Why no `stator:` prefix on tag keys?** AWS recommends an org prefix, but these accounts host one project, and AGENTS.md already uses `project`, `lab` and `ephemeral`.
- **Why `lab=platform`?** Platform stacks are tagged `lab=00` today, which is misleading (audit §3.2).
- **Why add `stack`?** It points every resource at its state, which is the teardown path that "$0 idle" needs.

## Checks

| Rule | Value | Source |
|---|---|---|
| Required checks (ruleset) | `Docs: lint`, `Workflows: lint`, `Infrastructure: required checks`, `Policy: trust paths`. Names unchanged | Audit §4.4 |
| `Workflows: lint` | actionlint, zizmor `--offline`, shellcheck over `tools/*.sh` and `platform/**/*.sh` | [arXiv 2601.14455](https://arxiv.org/html/2601.14455v2); audit §5 (5 scripts unchecked) |
| `Infrastructure: validate` | `fmt -check`, `init -backend=false -lockfile=readonly`, `validate`, `tofu test` (mock providers), tflint, Checkov, plus self-tests for `plan-gate`, `provider-allowlist`, `tofu-stacks` and `guardrails` | [AWS PG version](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/version.html) |
| PR plan | Calls `plan.yml@main`. Runs the provider allow-list from trusted `main`, a CLI `provider_installation` block limited to the listed namespaces, `-lockfile=readonly`, `-lock=false`, the gate (deny fails the check) and `ValidatePolicy` on the IAM documents in the plan JSON | [GitFlops](https://snyk.io/blog/gitflops-dangers-of-terraform-automation-platforms), [OpenTofu provider installation](https://opentofu.org/docs/cli/plugins/) |
| Aggregator | `if: always()`. Fails if any needed job failed or was cancelled, because a skipped job reports success | [GitHub](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks) |
| Gate lanes | **deny**: destroying a never-destroy address, an IAM role without the boundary, a wildcard `Action` or `NotAction`. **manual**: any delete or replace, any IAM change, policy JSON unknown at plan time, a stack whose floor is manual, more than N changes. **auto**: everything else. Config is read from `main` only | Audit §5 gaps; [Stategraph](https://stategraph.com/docs/orchestration/governance/centralized-config?from=terrateam) |
| Scanner | Checkov only | Trivy action tags were rewritten to a credential stealer in March 2026 ([GHSA-69fq-xp46-6x23](https://github.com/aquasecurity/trivy/security/advisories/GHSA-69fq-xp46-6x23)) |
| Dependencies | Dependabot for actions and providers, weekly, 7-day cooldown (as today) | Audit §4.1 |
| Native pinning | Actions lockfile plus "Require lockfile", and "Require SHA pinning". Enable only after the `@main` reusable-call test (see Open questions) | [InfoQ](https://infoq.com/news/2026/11/github-actions-lockfiles-ga), [changelog](https://github.blog/changelog/2025-08-15-github-actions-policy-now-supports-blocking-and-sha-pinning-actions/) |
| Merge queue | Keep. Every required workflow triggers on `merge_group` | Audit §4.4 |

- **Deferral for Yaaf to choose: Conftest/Rego now or later?** Plan JSON plus Conftest is the shareable norm ([Classmethod](https://dev.classmethod.jp/articles/github-actions-terraform-plan-conftest-opa/)), and shareability is the point of this redesign. Porting now costs one PR and a pinned `conftest` binary; later costs a rewrite of tested Python. No source says which is cheaper for one repo.
- **Why not Infracost?** It needs an external account and an API-key secret, which is a Tier 2 trust ask with little payoff on free-tier labs.
- **Why not harden-runner now?** It puts a third-party action inside the job that holds AWS credentials. Revisit in audit mode.
- **Accepted gap.** Three required checks run the PR's own workflow file (audit §4.4). Trust pins `@main`, so a PR cannot get AWS credentials, but it could fake its own aggregator. That stays low priority while Yaaf makes every merge.

## Pipeline

| Rule | Value | Source |
|---|---|---|
| PR | Detect changed stacks, validate, plan with `plan-pr`, aggregator | Audit §4.1 |
| Push to `main` | Guard, then plan **all** CI stacks with `plan-main`, then apply in the lane's environment, then report | [Terramate](https://terramate.io/rethinking-iac/mastering-terraform-workflows-why-terramate-recommends-merge-before-apply) |
| Plan scope on `main` | Every non-terminal stack. No diff against the last green run | Inference: a cancelled run can never drop a stack, and a no-op plan doubles as a drift check |
| Concurrency | One run-level group `infrastructure-main`, no `queue` key (default: one pending run), no `cancel-in-progress`. PR runs use `infrastructure-pr-<n>` with `cancel-in-progress` | [Workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax) |
| Plan storage | S3 `plans/`, with a SHA-256 output per file and a 7-day expiry. Never workflow artifacts, which anyone with read access can download | [GitHub artifacts](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts) |
| Lane per run | The highest lane across all stacks in the run, so at most one approval per run | Inference |
| Environments | `aws-apply`: Yaaf as reviewer, `main`-only branch policy, "prevent self-review" **off** (Yaaf triggers every push), admin bypass off. `aws-apply-auto`: no reviewer, `main`-only. Reviewers on Free work only because the repo is public | [GitHub environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments) |
| Apply job (`apply.yml`) | `environment: ${{ inputs.environment }}` (a calling job cannot set `environment`). Inputs are the lane, the plan attempt number and the SHA-256 map. The plan key is derived from `github.run_id`, never passed as a free path. Steps, all after approval: 1) HEAD check: if `github.sha` is not `main` HEAD, exit green as "superseded". 2) Download the plan and verify SHA-256. 3) `init -lockfile=readonly` with the same tofu version. 4) Re-run `plan-gate` on `tofu show -json`, and refuse if the environment is `aws-apply-auto` but the recomputed lane is not `auto`. 5) `tofu apply <planfile>` | [Reusable workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/reusable-workflows), [Security Lab](https://securitylab.github.com/resources/github-actions-new-patterns-and-mitigations/); step 4 is inference: no caller can skip the gate |
| Engine guard | OpenTofu refuses a saved plan if lineage, serial, tofu version or lock selections differ. Report "Saved plan is stale" as "re-run", not as a failure | [backend_local.go](https://github.com/opentofu/opentofu/blob/v1.13.10/internal/backend/local/backend_local.go), [tfplan.go](https://github.com/opentofu/opentofu/blob/v1.13.10/internal/plans/planfile/tfplan.go) |
| Tool version | One pinned tofu for plan and apply. 1.13.10 is the latest, released 2026-11-23 (CI has 1.13.9) | [Releases](https://api.github.com/repos/opentofu/opentofu/releases/latest); audit §1.2 |
| Supersede | A separate workflow on push to `main`, in no group, with `actions: write`. Cancels Infrastructure runs in `waiting` whose `head_sha` is not the current one. It never rejects, because `GITHUB_TOKEN` is not a reviewer | [REST](https://docs.github.com/en/rest/actions/workflow-runs), [token scopes](https://raw.githubusercontent.com/github/docs/main/data/reusables/actions/github-token-scope-descriptions.md) |
| Notify (primary) | One rolling issue, "Infrastructure: apply waiting", assigned to the owner. Its body always links the single live waiting run and its plan summary. Both the report job and Supersede rewrite it, and it closes when nothing waits. Phone alerts come from GitHub Mobile | Inference: a newer run can carry an older PR's changes, so a link on that older PR goes stale; [GitHub Mobile](https://github.blog/changelog/2021-04-01-reviewing-deployments-on-github-mobile) |
| Notify (secondary) | A comment on the merged PR with the run link (finding the PR through `commits/{sha}/pulls` is to-verify). The report job always runs, and it opens and closes the "main failing" issue, which fixes the "never closes on no-change" bug | Audit §4.3 |
| Drift | Separate `Drift` workflow, daily at minute 17, in its own group. Calls `plan.yml` with `-lock=false -detailed-exitcode`. Exit 2 opens or updates one issue | [tofu plan](https://opentofu.org/docs/cli/commands/plan/), [schedule](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule) |
| Terminal stacks | `bootstrap`, `labs-bootstrap` and `foundation` are never planned or applied by CI. Yaaf runs `make plan` and `make apply` | AGENTS.md Tier 3 |
| Triggers | No `paths` filter on push to `main`. A tooling or tofu bump replans | Audit §5 (the filter misses 4 tool files) |

### Concurrency: one design that is safe under both readings

GitHub does not document whether a job waiting on approval holds its concurrency slot. Community reports say it does ([#135220](https://github.com/orgs/community/discussions/135220), [zerocreds #117](https://github.com/Zerocreds-com/zerocreds-server/issues/117)).

| Reading | What happens with run A waiting and run B pushed |
|---|---|
| Waiting **holds** the slot | B sits pending. Supersede, which runs outside the group, cancels A. B then plans on fresh state. If Supersede fails, approving A exits as "superseded" and B starts. |
| Waiting **does not hold** the slot | B plans while A waits. Approving A then exits as "superseded". If A had already started applying, B's saved plan fails on the stale serial. That fails closed. |
| Waiting **counts as pending** | The default queue replaces A with B as soon as B arrives. Also safe. |

- **Why the default queue and not `queue: max`?** This departs from the earlier `queue: max` advice. Main plans every stack, so only the newest run matters, and `max` would only line up stale runs for the guard to drain.
- **Why keep Drift and Reaper out of the group?** Under the default queue, a scheduled run could replace a pending merge run.
- **The one scratch-repo test.** Use a workflow with this group and a job that needs a reviewer environment. Push A and let it wait, then push B. Record whether B shows pending or running. Then cancel A through the API and time how long B takes to start.

### Product boundary

| Layer | Platform owns (versioned) | Consumer repo brings |
|---|---|---|
| AWS | `ci-roles` module, SCP, RCP and tag policy definitions | One role-set instance per account, applied from the terminal |
| GitHub | `plan.yml`, `apply.yml`, `supersede.yml`, `drift.yml` | `infrastructure.yml` stub (~40 lines), 2 environments |
| Config | `tofu-stacks.py`, `plan-gate.py`, `provider-allowlist.py` | `platform/stacks.toml`, `AWS_<ACCOUNT>_ACCOUNT_ID`, `AWS_REGION` |

Vendors ship the same split: a config file plus a thin stub, with the logic in a reusable workflow ([Gruntwork](https://docs.gruntwork.io/2.0/docs/pipelines/architecture/ci-workflows), [Stategraph](https://stategraph.com/docs/orchestration/governance/centralized-config?from=terrateam)). Only a reusable workflow gives AWS a `job_workflow_ref` to bind to ([GitHub](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-with-reusable-workflows)). Because `apply.yml` re-runs the gate, a consumer's stub cannot choose its own lane.

## IaC guidelines

| Rule | Value | Source |
|---|---|---|
| Stack | One root module per (account, component). At most 100 resources, ideally a few dozen. One state per stack. Use directories, not workspaces | [Google](https://docs.cloud.google.com/docs/terraform/best-practices/root-modules), [HashiCorp](https://developer.hashicorp.com/terraform/cli/workspaces) |
| Files | `versions.tf` (`terraform {}`: version, providers, backend), `providers.tf` (roots only), `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `tests/*.tftest.hcl`. Split into topic files (`iam.tf`) only when `main.tf` gets hard to review | [AWS PG structure](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/structure.html) |
| Modules | Only when the module names a concept the architecture talks about. No wrappers around a single resource. At most 2 levels deep. No provider blocks inside modules | [AWS PG structure](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/structure.html) |
| Identifiers | snake_case, singular, never repeat the resource type. `this` for a singleton. Booleans named `enable_<thing>` | [AWS PG](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/structure.html), [Google style](https://docs.cloud.google.com/docs/terraform/best-practices/general-style-structure) |
| Variables | Always `type` and `description`. No defaults for values that differ per account. `validation` only for rules tofu does not check itself. `sensitive = true` for secrets. `nullable = false` on collections | [HashiCorp style](https://developer.hashicorp.com/terraform/language/style), [Babenko](https://www.terraform-best-practices.com/naming) |
| Versions | Roots: `required_version = "~> 1.13"`, providers `~> 6.73`. Modules: `>=` only. Commit the lockfile; CI uses `-lockfile=readonly`. Pin module sources by full git SHA | [AWS PG version](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/version.html) |
| Backend | S3 with `use_lockfile = true`, no DynamoDB. Bucket passed through `-backend-config`, never committed | [OpenTofu S3](https://opentofu.org/docs/language/settings/backends/s3/) |
| Region | One region, `us-east-1`, as a variable with that default and the only entry in the labs SCP's `allowed_regions`. Identity Center and root sign-in events cannot leave `us-east-1`, so any other home region would mean two | [Identity Center regions](https://docs.aws.amazon.com/singlesignon/latest/userguide/regions.html) |
| Portability | Partition from `data.aws_partition`, never a hardcoded `arn:aws` | Audit §1.2 (foundation hardcodes 4 places) |
| Secrets | Ephemeral values and write-only `_wo` arguments (OpenTofu 1.11). Service-managed passwords. Personal data only in terminal stacks. No committed tfvars | [OpenTofu 1.11](https://opentofu.org/blog/opentofu-1-11-0), [AWS PG security](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/security.html) |
| Refactors | `moved`, `import` and `removed` blocks, reviewed in PRs. Never `tofu state` commands in CI | [AWS PG structure](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/structure.html) |
| Protection | `prevent_destroy` on the state bucket, org, labs account, trail bucket and OIDC provider (dynamic since 1.12) | [OpenTofu 1.12](https://opentofu.org/blog/opentofu-1-12-0/) |
| Tests | `tofu test` with `mock_provider` in every stack and module. At least one run per trust condition and per deny statement. Apply-mode tests only behind approval, because they cost money | [AWS PG testing](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/best-practices-for-testing.html) |
| Engine | OpenTofu only. `lifecycle { enabled }`, early evaluation and encryption are allowed. No `.tofu` file twins, which would mean maintaining two copies | [OpenTofu 1.8](https://opentofu.org/docs/v1.8/intro/whats-new/) |

- **Why `versions.tf` and not `terraform.tf` (as HashiCorp names it)?** Every stack already uses it, and so does AWS PG.
- **Why `this` and `enable_x`?** Sources split on both. These choices match AWS PG, the closest source to an AWS-only platform.

## Open questions

1. **Does a waiting job hold the concurrency slot?** The design is safe either way. Step 3 settles it.
2. **SHA pins against trust pins.** Trust pins `@refs/heads/main`, so the PR plan call must use `@main`, against the house SHA rule (a zizmor ignore covers it today). If "Require SHA pinning" rejects that call, keep the setting off and record a "Why not" note. For a multi-repo product, the options are either `StringLike` on `@*` plus environment and repo ID, or role vending that rewrites trust on each platform release. Neither has been tested.
3. **STS RCP.** Can an RCP limit `AssumeRoleWithWebIdentity` to the GitHub provider without blocking it? Test in a scratch account before use.
4. **Foundation in CI.** Could Organizations delegated policy management move SCP authoring into a member account so it can have a CI lane? Not researched.
5. **Bot identity (STAT-46).** Until `stator-bot` lands, agent sessions hold the owner's token. That token can approve the manual lane through `pending_deployments`, and today's guardrails neither cover that call nor run under Claude Code (audit §5). Step 12 adds a deny. Also decide whether the ruleset's admin exemption should stay as the normal merge path (audit §4.4).
6. **Exact SCP and IAM action names, and IAM path immutability.** Verify against the Service Authorization Reference before step 11.
