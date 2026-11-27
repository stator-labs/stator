# ci-roles

Four GitHub Actions OIDC roles for one (repository, account). Applied from a terminal-only
bootstrap stack; CI never manages its own roles.

| Preset | Trusts (`sub`) | Workflow (`job_workflow_ref`) | Grants |
|---|---|---|---|
| `plan-pr` | `<prefix>:pull_request` | `workflow_refs.plan` | ReadOnlyAccess, `state-read`, `state-deny` (no `plans/`, no terminal state, no lock) |
| `plan-main` | `<prefix>:ref:refs/heads/main` | `workflow_refs.plan` | ReadOnlyAccess, `state-read`, `state-lock`, `plans-write` |
| `apply` | `<prefix>:environment:<each apply environment>` | `workflow_refs.apply` | PowerUserAccess, `iam-scoped` (IAM only under `workload_path`, boundary required) |
| `reaper` | `<prefix>:ref:refs/heads/main` | `workflow_refs.reaper` | `tag-read`, carries the boundary |

Every trust policy also checks `aud = sts.amazonaws.com`. `github_sub_prefix` must be the
immutable `repo:<owner>@<id>/<repo>@<id>` form.

- **Why not one shared role scoped by session tags?** GitHub tokens carry no session-tag claim and AWS does not keep GitHub claims in the session, so scoping has to happen in trust.
- **Why not `terraform-aws-modules/iam`?** It saves about 100 lines but adds a dependency, and its examples match name-based subjects that break on rename.
- **Why separate `plan-pr` and `plan-main`?** Only `plan-main` may write `plans/`. A PR-trusted role that could write there could plant the file apply runs.
- **Why no `repository_id` condition?** The immutable `sub` already carries both IDs, so an extra key adds nothing but another way to lock out.
