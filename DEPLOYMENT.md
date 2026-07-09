# Pillar 1 RAG Bot - Cloud Deployment

## Status
**Terraform code ready.** Requires AWS CLI and Terraform to deploy.

## What's Deployed
- `lambda_handler.py` — Lambda entry point
- `lambda_deployment.zip` — Packaged function with dependencies
- `terraform/` — IaC for Lambda + API Gateway

## Deployment Steps

### 1. Prerequisites
```bash
# Install AWS CLI
brew install awscli

# Install Terraform
brew install terraform

# Configure AWS credentials
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-east-1)
```

### 2. Deploy
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 3. Test
```bash
# Get the API endpoint from Terraform output
API_URL=$(terraform output -raw chat_url)

curl -X POST $API_URL \
  -H "Content-Type: application/json" \
  -d '{"message": "What is ProcessNexus?"}'
```

## Architecture
- **Lambda Function:** `pillar-1-rag-bot` (Python 3.12, 512 MB)
- **API Gateway:** HTTP API with POST /chat route
- **VPC:** Deployed in baseline VPC (private subnets)
- **IAM:** Least-privilege role with Bedrock + Secrets Manager access
- **KB Storage:** AWS Secrets Manager
- **Logging:** CloudWatch Logs for API Gateway and Lambda

## Security Notes
- Lambda runs in VPC (no direct internet access)
- Bedrock access via VPC endpoint (baseline deployment)
- Knowledge base encrypted in Secrets Manager
- API logs stored in CloudWatch (encrypted)
- IAM role scoped to specific resources

## Vulnerability Demonstrations
Run attacks from `attacks/` directory to test:
1. **Prompt Injection** — attempts to break system prompt via user input
2. **Hallucination** — model generates false information
3. **KB Poisoning** — malicious data in context
4. **Data Exfiltration** — extracting the admin URL from the prompt

## Next: Guarded Version
Switch to `main_guarded.py` implementation to demonstrate:
- Input sanitization
- Context isolation
- Prompt injection defenses
- Secure information handling
