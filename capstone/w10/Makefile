ENV_DIR   := environments/dev
STATE_DIR := s3-ddb

.PHONY: init plan apply destroy show output validate fmt \
        state-init state-apply state-destroy \
        macie-findings macie-sample help

# ─── Dev Environment ──────────────────────────────────────────────────────────

init:
	@echo "==> Initializing Terraform ($(ENV_DIR))..."
	cd $(ENV_DIR) && terraform init

plan:
	@echo "==> Planning Terraform changes ($(ENV_DIR))..."
	cd $(ENV_DIR) && terraform plan

apply:
	@echo "==> Applying Terraform changes ($(ENV_DIR))..."
	cd $(ENV_DIR) && terraform apply -auto-approve
	@echo ""
	@echo "✅ Done! Next steps:"
	@echo "   1. Check your email and confirm the SNS subscription"
	@echo "   2. Wait 5-15 minutes for Macie to scan and generate findings"
	@echo "   3. Run 'make macie-findings' to check status"

destroy:
	@echo "==> Destroying infrastructure ($(ENV_DIR))..."
	cd $(ENV_DIR) && terraform destroy -auto-approve

show:
	@echo "==> Showing current Terraform state ($(ENV_DIR))..."
	cd $(ENV_DIR) && terraform show

output:
	@echo "==> Showing Terraform outputs ($(ENV_DIR))..."
	cd $(ENV_DIR) && terraform output

validate:
	@echo "==> Validating Terraform config ($(ENV_DIR))..."
	cd $(ENV_DIR) && terraform validate

fmt:
	@echo "==> Formatting Terraform files..."
	terraform fmt -recursive

# ─── Remote State Bootstrap ───────────────────────────────────────────────────

state-init:
	@echo "==> Initializing remote state backend ($(STATE_DIR))..."
	cd $(STATE_DIR) && terraform init

state-apply:
	@echo "==> Creating S3 + DynamoDB for Terraform state..."
	cd $(STATE_DIR) && terraform init && terraform apply -auto-approve

state-destroy:
	@echo "==> Destroying Terraform state backend resources..."
	cd $(STATE_DIR) && terraform destroy -auto-approve

# ─── Macie Helpers ────────────────────────────────────────────────────────────

macie-findings:
	@echo "==> Listing Macie findings (last 10)..."
	aws macie2 list-findings --finding-criteria '{}' --max-results 10 --region us-east-1
	@echo ""
	@echo "==> View in console: https://console.aws.amazon.com/macie/home?region=us-east-1#/findings"

macie-sample:
	@echo "==> Generating Macie sample findings (for testing notifications)..."
	aws macie2 create-sample-findings \
		--finding-types "SensitiveData:S3Object/Personal" \
		                "SensitiveData:S3Object/Financial" \
		                "SensitiveData:S3Object/Credentials" \
		--region us-east-1
	@echo "✅ Sample findings created — check your email and Macie console!"

macie-status:
	@echo "==> Checking Macie account status..."
	aws macie2 get-macie-session --region us-east-1
	@echo ""
	@echo "==> Listing classification jobs..."
	aws macie2 list-classification-jobs --region us-east-1

# ─── Help ─────────────────────────────────────────────────────────────────────

help:
	@echo ""
	@echo "Capstone W11 — Amazon Macie Sensitive Data Detection"
	@echo "====================================================="
	@echo ""
	@echo "  Dev environment (environments/dev):"
	@echo "    init              terraform init"
	@echo "    plan              terraform plan"
	@echo "    apply             terraform apply (deploys everything)"
	@echo "    destroy           terraform destroy"
	@echo "    output            show terraform outputs"
	@echo "    validate          terraform validate"
	@echo "    fmt               terraform fmt -recursive"
	@echo ""
	@echo "  Remote state bootstrap (s3-ddb/) — run ONCE before init:"
	@echo "    state-apply       create S3 + DynamoDB for state"
	@echo "    state-destroy     destroy state backend resources"
	@echo ""
	@echo "  Macie helpers (requires AWS CLI):"
	@echo "    macie-sample      generate sample findings immediately"
	@echo "    macie-findings    list current findings"
	@echo "    macie-status      check Macie account + job status"
	@echo ""
	@echo "  Quickstart:"
	@echo "    1. Edit environments/dev/terraform.tfvars with your email + bucket name"
	@echo "    2. make state-apply"
	@echo "    3. make init && make apply"
	@echo "    4. Confirm SNS email subscription"
	@echo "    5. make macie-sample  (trigger test notification immediately)"
	@echo ""
