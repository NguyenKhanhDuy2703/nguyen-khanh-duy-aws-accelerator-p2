
ENV_DIR  := environments/dev
STATE_DIR := s3-ddb

.PHONY: init plan apply destroy show output validate fmt unlock \
        state-init state-apply state-import state-plan state-destroy \
        help
init:
	@echo "==> Initializing Terraform ($(ENV_DIR))..."
	cd $(ENV_DIR) && terraform init

plan:
	@echo "==> Planning Terraform changes ($(ENV_DIR))..."
	cd $(ENV_DIR) && terraform plan

apply:
	@echo "==> Applying Terraform changes ($(ENV_DIR))..."
	cd $(ENV_DIR) && terraform apply -auto-approve

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

unlock:
	@echo "==> Force-unlocking Terraform state..."
	@echo "    Usage: make unlock LOCK_ID=<lock-id>"
	cd $(ENV_DIR) && terraform force-unlock $(LOCK_ID)

# ------------------------------------------------------------
# Remote state bootstrap (S3 + DynamoDB)
# Run ONCE before the first terraform init in environments/dev
# ------------------------------------------------------------

state-init:
	@echo "==> Initializing remote state backend ($(STATE_DIR))..."
	cd $(STATE_DIR) && terraform init

state-apply:
	@echo "==> Creating S3 bucket + DynamoDB table for Terraform state..."
	cd $(STATE_DIR) && terraform init && terraform apply -auto-approve

state-import:
	@echo "==> Importing existing S3 bucket and DynamoDB table into Terraform state..."
	cd $(STATE_DIR) && terraform init
	cd $(STATE_DIR) && terraform import aws_s3_bucket.terraform_state dev-terraform-state-bucket-kduy
	cd $(STATE_DIR) && terraform import aws_s3_bucket_versioning.terraform_state_versioning dev-terraform-state-bucket-kduy
	cd $(STATE_DIR) && terraform import aws_s3_bucket_server_side_encryption_configuration.terraform_state_crypto dev-terraform-state-bucket-kduy
	cd $(STATE_DIR) && terraform import aws_dynamodb_table.terraform_locks dev-terraform-state-lock
	@echo "==> Import done. Run 'make state-plan' to verify."

state-plan:
	@echo "==> Planning state resources (should show no changes after import)..."
	cd $(STATE_DIR) && terraform plan

state-destroy:
	@echo "==> Destroying S3 bucket + DynamoDB table for Terraform state..."
	cd $(STATE_DIR) && terraform destroy -auto-approve

# ------------------------------------------------------------
# Help
# ------------------------------------------------------------

help:
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "  Dev environment (environments/dev):"
	@echo "    init          terraform init"
	@echo "    plan          terraform plan"
	@echo "    apply         terraform apply -auto-approve"
	@echo "    destroy       terraform destroy -auto-approve"
	@echo "    show          terraform show"
	@echo "    output        terraform output"
	@echo "    validate      terraform validate"
	@echo "    fmt           terraform fmt -recursive"
	@echo "    unlock        force-unlock stale state lock (make unlock LOCK_ID=<id>)"
	@echo ""
	@echo "  Remote state bootstrap (s3-ddb):"
	@echo "    state-init    terraform init in s3-ddb/"
	@echo "    state-apply   create S3 + DynamoDB for state (neu chua ton tai)"
	@echo "    state-import  import S3 + DynamoDB da ton tai vao Terraform state"
	@echo "    state-plan    terraform plan trong s3-ddb/ (kiem tra sau import)"
	@echo "    state-destroy destroy S3 + DynamoDB for state"
	@echo ""
