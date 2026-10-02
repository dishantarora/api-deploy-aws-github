# Branch protection and pull requests

These settings are applied in the GitHub repository because branch rules are repository settings, not files committed to the source tree.

## Protect `main`

In **Settings → Branches** (or a repository ruleset), add a rule for `main` with:

- Require a pull request before merging.
- Require at least one approval; dismiss stale approvals when new commits are pushed.
- Require the `pr-check` status check before merging.
- Require branches to be up to date before merging.
- Block force pushes and branch deletion.
- Require conversation resolution before merging.

Do not allow direct pushes that bypass the pull request rule except for a deliberate administrator break-glass path.

## Pull request workflow

Open pull requests against `main`. The `Pull request checks` workflow runs the `pr-check` job. Review the change and deployment notes in the pull request template; merge only after approval and the required status check pass.

## Environment approvals

In **Settings → Environments**, create `dev`, `staging`, and `production`. Store `AWS_ROLE_ARN`, `AWS_REGION`, `TF_STATE_BUCKET`, and `TF_STATE_REGION` as variables in each environment. The deployment role also needs access to that stage's Terraform state and lock objects. Add required reviewers to `production` so its deploy pauses for approval after staging succeeds. Limit deployment branches to `main` for each environment.
