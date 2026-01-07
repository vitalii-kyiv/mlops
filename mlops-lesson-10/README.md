# mlops-train-automation

A small example of triggering a training pipeline via AWS Step Functions and Lambda, described in Terraform, with an automatic trigger from GitLab CI.

## Structure
- `terraform/main.tf` — AWS resources (IAM, Lambda, Step Function).
- `terraform/variables.tf` — variables (region, name prefix).
- `terraform/lambda/validate.py` — simple data validation.
- `terraform/lambda/log_metrics.py` — metrics logging.
- `terraform/lambda/*.zip` — ready-to-deploy archives.
- `.gitlab-ci.yml` — job that invokes the Step Function.

## How to build Lambda archives
```bash
cd terraform/lambda
zip validate.zip validate.py
zip log_metrics.zip log_metrics.py
```

Alternative via Python (if `zip` is unavailable):
```bash
cd terraform/lambda
python - <<'PY'
import zipfile, pathlib
base = pathlib.Path('.')
for name in ['validate', 'log_metrics']:
    src = base / f"{name}.py"
    dest = base / f"{name}.zip"
    with zipfile.ZipFile(dest, 'w', zipfile.ZIP_DEFLATED) as zf:
        zf.write(src, arcname=src.name)
    print(f"Created {dest}")
PY
```

## Deploy with Terraform
```bash
cd terraform
terraform init
terraform apply
```

Or with automatic approval:
```bash
terraform apply -auto-approve \
  -var="aws_region=<your-region>" \
  -var="project_name=mlops-train-automation"
```

After `apply`, note the state machine ARN from the output or console for CI usage.
Terraform also returns `state_machine_arn` as an output.

## Manual Step Function run

### Via AWS Console
1. Open AWS Management Console.
2. Go to **Step Functions**.
3. Open the **State machines** tab.
4. Find your state machine (e.g., `mlops-train-automation-pipeline`).
5. Click **Start execution**.
6. In **Name**, enter `train-<timestamp>` (e.g., `train-1734220800`).
7. In **Input**, provide JSON:
```json
{
  "source": "manual",
  "commit": "test-commit"
}
```
8. Click **Start execution** and watch the real-time execution.

### Via AWS CLI
```bash
aws stepfunctions start-execution \
  --state-machine-arn <STATE_MACHINE_ARN> \
  --name "train-$(date +%s)" \
  --input '{"source":"cli","note":"manual run"}'
```

## GitLab CI

GitLab CI automatically triggers the AWS Step Function on every push.

### Required CI/CD variables
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` or OIDC config (recommended) with `states:StartExecution` and permissions for the specific state machine.
- `AWS_DEFAULT_REGION` (matches `aws_region`, e.g., `us-east-1`).
- `STATE_MACHINE_ARN` — ARN of the created state machine.
- (optional for OIDC) `AWS_ROLE_ARN` + `AWS_WEB_IDENTITY_TOKEN_FILE`.

### What happens in the job
1. Install `awscli` via `pip install awscli`.
2. Start the Step Function with a unique name (e.g., `train-1734220800`).
3. Pass input:
   - `source: "gitlab-ci"`
   - `commit: SHA` of the latest commit (automatically via `$CI_COMMIT_SHORT_SHA`).

### Example job
```yaml
stages:
  - train

train-model:
  stage: train
  image: python:3.11
  before_script:
    - pip install awscli
  script:
    - echo "🚀 Starting ML pipeline via Step Function"
    - |
       aws stepfunctions start-execution \
        --region us-east-1 \
        --state-machine-arn arn:aws:states:us-east-1:019959576624:stateMachine:MLOpsPipeline \
        --name "train-$(date +%s)" \
        --input "{\"source\":\"gitlab-ci\",\"commit\":\"$CI_COMMIT_SHORT_SHA\"}"
  rules:
    - if: "$CI_PIPELINE_SOURCE == 'push'"
```

## Example payload
```json
{"source":"gitlab-ci","commit":"abc1234"}
```

## Example successful execution

### Response from `aws stepfunctions start-execution`
```json
{
    "executionArn": "arn:aws:states:us-east-1:019959576624:execution:mlops-train-automation-pipeline:train-1734220800",
    "stateMachineArn": "arn:aws:states:us-east-1:019959576624:stateMachine:mlops-train-automation-pipeline",
    "name": "train-1734220800",
    "status": "SUCCEEDED",
    "startDate": "2025-12-15T14:30:15.238000+00:00",
    "stopDate": "2025-12-15T14:30:16.116000+00:00",
    "input": "{\"source\":\"gitlab-ci\",\"commit\":\"745e60cf\"}",
    "inputDetails": {
        "included": true
    },
    "output": "{\"status\": \"logged\"}",
    "outputDetails": {
        "included": true
    }
}
```

### CloudWatch Logs for Lambda validate
```
START RequestId: a1b2c3d4-e5f6-7890-abcd-ef1234567890 Version: $LATEST
Validating data...
END RequestId: a1b2c3d4-e5f6-7890-abcd-ef1234567890
REPORT RequestId: a1b2c3d4-e5f6-7890-abcd-ef1234567890	Duration: 45.23 ms	Billed Duration: 46 ms	Memory Size: 128 MB	Max Memory Used: 45 MB	Init Duration: 123.45 ms
```

### CloudWatch Logs for Lambda log_metrics
```
START RequestId: b2c3d4e5-f6a7-8901-bcde-f12345678901 Version: $LATEST
Logging metrics...
END RequestId: b2c3d4e5-f6a7-8901-bcde-f12345678901
REPORT RequestId: b2c3d4e5-f6a7-8901-bcde-f12345678901	Duration: 38.12 ms	Billed Duration: 39 ms	Memory Size: 128 MB	Max Memory Used: 42 MB	Init Duration: 98.76 ms
```

## Customize for your setup
- Set `aws_region` and `project_name` in `terraform/variables.tf` or via `-var` during `terraform apply`.
- In `.gitlab-ci.yml`, change `STATE_MACHINE_ARN` to the ARN from Terraform output.
- If needed, swap the AWS CLI image or add `before_script` steps for registry login / environment prep.

## Step Function logic
1. `ValidateData` → calls the `validate.py` Lambda.
2. `LogMetrics` → calls the `log_metrics.py` Lambda.

Both functions return a simple dict with status and echo the input data to illustrate the pipeline sequence.
