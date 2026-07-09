#!/bin/bash
set -e

echo "🚀 Pillar 1 RAG Bot - Cloud Deployment"
echo "======================================="

# Check prerequisites
echo "✓ Checking prerequisites..."
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Install with: brew install awscli"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not found. Install with: brew install terraform"
    exit 1
fi

# Verify AWS credentials
echo "✓ Verifying AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Run: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "  Account: $ACCOUNT_ID"

# Build Lambda deployment package
echo "✓ Building Lambda package..."
mkdir -p /tmp/lambda_build
cp lambda_handler.py /tmp/lambda_build/
cp -r app /tmp/lambda_build/
cd /tmp/lambda_build
python3 -m pip install -q boto3 requests -t . 2>/dev/null || pip3 install -q boto3 requests -t . 2>/dev/null
zip -r -q lambda_deployment.zip .
cp lambda_deployment.zip "$SCRIPT_DIR/lambda_deployment.zip"
cd - > /dev/null
echo "  Package size: $(du -h /tmp/lambda_build/lambda_deployment.zip | cut -f1)"

# Deploy with Terraform
echo "✓ Deploying infrastructure..."
cd terraform
terraform init -upgrade
terraform plan -out=tfplan
echo ""
read -p "  Review plan above. Deploy? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    terraform apply tfplan
    echo ""
    echo "✅ Deployment complete!"
    echo ""
    echo "API Endpoint:"
    terraform output chat_url
    echo ""
    echo "Test with:"
    echo "  curl -X POST $(terraform output -raw chat_url) \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -d '{\"message\": \"What is ProcessNexus?\"}'"
else
    echo "❌ Deployment cancelled"
    exit 1
fi
