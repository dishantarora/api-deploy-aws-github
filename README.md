# Node.js API on AWS with Terraform

A read-only HTTP API built with AWS Lambda and API Gateway HTTP API. Each stage gets its own Lambda function, API Gateway API, execution role, CloudWatch log group, and DynamoDB table.

## API

- `GET /items` returns `{ "items": [...] }` for records with `pk = "ITEM"`.
- `GET /items/{id}` returns one item or a `404` response.

Store each item with a string partition key `pk` set to `ITEM` and a string sort key `sk` set to its ID. Other DynamoDB attributes are returned as JSON fields; `sk` is returned as `id`.

The HTTP API has no authorizer in this starter, so callers who know the URL can read these records. Add IAM, JWT, or Lambda authorization before using it for non-public data.

The Lambda runtime provides AWS SDK for JavaScript v3. The function uses the runtime's DynamoDB client, so its deployment package does not need npm dependencies.

## Terraform layout

- `terraform/modules/api` defines the Lambda, API Gateway, DynamoDB table, IAM permissions, and logs.
- `terraform/environments/{dev,staging,prod}.tfvars` selects the stage. Each stage is applied to a separate S3 backend state key.
- `terraform/bootstrap` creates a private, encrypted, versioned S3 bucket for Terraform state and locking.

The production DynamoDB table has deletion protection and point-in-time recovery enabled. Log retention is 30 days in dev/staging and 90 days in prod.

## Deployment flow

`.github/workflows/deploy.yml` contains exactly three sequential deployment jobs: `deploy-dev` → `deploy-staging` → `deploy-production`. A push to `main` runs Terraform plan/apply for each stage using that stage's GitHub Environment and AWS OIDC role. Production can pause for GitHub Environment reviewer approval.

Each job builds the Lambda ZIP, applies the infrastructure and code, then smoke-checks `GET /items`. If apply or the smoke check fails, the rollback step restores the previous Lambda `live` alias when one exists. A first deployment has no previous Lambda version to restore. Terraform remains the owner of the alias and will reconcile it on the next apply.

Pull requests to `main` run the `pr-check` workflow, which checks Node syntax, Terraform formatting, and Terraform configuration validation. Merging starts the three-stage deployment workflow.

## One-time setup

### Create and migrate the Terraform state bucket

Use an AWS identity that can create an S3 bucket and bucket policy. The bootstrap state starts locally, then moves into the bucket it creates:

```sh
terraform -chdir=terraform/bootstrap init -backend=false
terraform -chdir=terraform/bootstrap apply -var="aws_region=us-east-1"
STATE_BUCKET="$(terraform -chdir=terraform/bootstrap output -raw state_bucket)"
terraform -chdir=terraform/bootstrap init -migrate-state -force-copy \
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="key=bootstrap/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="use_lockfile=true" \
  -backend-config="encrypt=true"
```

Replace `us-east-1` with the AWS region you want for the state bucket. The bucket has public access blocked, server-side encryption, versioning, and a TLS-only bucket policy.

### Configure GitHub and AWS

1. Create a GitHub OIDC provider in AWS for audience `sts.amazonaws.com`. Create a deployment role for each stage with trust restricted to this repository and that GitHub Environment, for example `repo:OWNER/REPOSITORY:environment:dev`.
2. Give each deployment role permissions for its Terraform-managed Lambda, API Gateway, DynamoDB, CloudWatch Logs, and IAM resources, including `iam:PassRole` for the Lambda execution role. Also grant S3 state access: list the state bucket; get/put the stage state object; and get/put/delete its `.tflock` object. Scope permissions to the stage key where possible.
3. Create GitHub Environments named `dev`, `staging`, and `production`. In each, set variables `AWS_ROLE_ARN`, `AWS_REGION`, `TF_STATE_BUCKET`, and `TF_STATE_REGION`. Use the bootstrap bucket name for `TF_STATE_BUCKET`; `TF_STATE_REGION` is the bucket region. If stages use different AWS accounts, bootstrap a state bucket in each account and set that stage's bucket values.
4. Add required reviewers to the `production` GitHub Environment and limit its deployment branches to `main`. Configure `main` branch protection as described in [Branch protection and pull requests](docs/branch-protection.md).
5. Merge a pull request into `main`. After deployment, find the stage's URL with `terraform -chdir=terraform output -raw api_url` or the Terraform output in CI.

The first infrastructure apply creates empty DynamoDB tables. To add a sample dev item:

```sh
aws dynamodb put-item \
  --region us-east-1 \
  --table-name api-items-dev \
  --item '{"pk":{"S":"ITEM"},"sk":{"S":"item-001"},"name":{"S":"Example item"},"active":{"BOOL":true}}'
```

Then call `GET <ApiUrl>/items` or `GET <ApiUrl>/items/item-001`.

## Moving from the earlier SAM template

The deployment workflow now uses Terraform as the infrastructure owner. If the earlier SAM workflow has already created AWS resources named `api-dev`, `api-staging`, or `api-prod`, do not run the first Terraform apply against those stages until the existing stack resources are imported into Terraform state or the stacks are deliberately removed. Preserve the DynamoDB table data during that migration.
