# Deploy Pillar 1 RAG Bot via AWS Console

## Overview
This guide deploys the RAG bot using **CloudFormation** directly from the AWS web console. No Terminal, no local tools required.

## Prerequisites
- AWS Account (608645727500)
- Logged into AWS Console
- Baseline infrastructure deployed (VPC, subnets, security groups)

## Deployment Steps

### Step 1: Upload Lambda Code to S3

1. Go to **AWS Console → S3**
2. Create a new bucket named: `pillar-1-rag-lambda-code-608645727500`
3. Upload `lambda_deployment.zip` to this bucket
4. Note the object URL (you'll need it)

### Step 2: Deploy CloudFormation Stack

1. Go to **AWS Console → CloudFormation**
2. Click **Create Stack**
3. Select **Upload a template file**
4. Upload `cloudformation-template.yaml` from this repo
5. Click **Next**

### Step 3: Configure Stack

**Stack Name:** `pillar-1-rag-bot`

**Parameters:**
- **LambdaZipUrl:** Paste the S3 URL from Step 1
  - Example: `s3://pillar-1-rag-lambda-code-608645727500/lambda_deployment.zip`

Click **Next**

### Step 4: Review and Deploy

1. Review all settings
2. Check **I acknowledge that AWS CloudFormation might create IAM resources**
3. Click **Create Stack**

CloudFormation will now:
- Create S3 bucket for code
- Create IAM role with Bedrock access
- Create Lambda function
- Create Secrets Manager secret (Knowledge Base)
- Create API Gateway
- Wire everything together
- Deploy to production

**Status:** Watch the **Events** tab. When stack shows `CREATE_COMPLETE`, you're done.

### Step 5: Get Your API Endpoint

1. Go to **CloudFormation → Stacks → pillar-1-rag-bot**
2. Click **Outputs** tab
3. Copy the **ChatUrl** value
4. This is your live RAG bot endpoint!

## Test Your Deployment

```bash
curl -X POST https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What is ProcessNexus?"}'
```

Expected response:
```json
{
  "answer": "ProcessNexus is a workflow automation platform...",
  "context_used": 4
}
```

## Troubleshooting

### Stack creation failed
- Check **Events** tab for specific error
- Common issue: S3 bucket name already exists (AWS bucket names are globally unique)
- Solution: Try a different bucket name in the template

### Lambda timeout
- Increase `Timeout` in template (currently 30 seconds)
- Increase `MemorySize` (currently 512 MB)

### Permission denied errors
- Verify baseline VPC/subnets were created successfully
- Check IAM role has Bedrock permissions

## Cleanup

To delete everything:
1. Go to **CloudFormation → Stacks → pillar-1-rag-bot**
2. Click **Delete**
3. Confirm deletion
4. All resources (Lambda, API Gateway, etc.) will be removed
5. **Important:** Manually delete the S3 bucket (CloudFormation won't auto-delete it if it has files)

## Architecture

```
API Gateway (HTTP)
    ↓
Lambda (Python 3.12)
    ├→ Bedrock (Claude Haiku via VPC endpoint)
    ├→ Secrets Manager (Knowledge Base)
    └→ CloudWatch Logs
```

All traffic is encrypted (TLS for API, encrypted KMS keys for storage).
