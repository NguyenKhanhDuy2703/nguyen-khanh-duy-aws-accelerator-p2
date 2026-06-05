# Lab 1: VPC, EC2, S3 with Terraform
init-dev-lab1 :
	@echo "Initializing Terraform..."
	cd lab1-VPC+EC2+S3/environments/dev && terraform init
plan-dev-lab1 :
	@echo "Planning Terraform changes..."
	cd lab1-VPC+EC2+S3/environments/dev && terraform plan
apply-dev-lab1 :
	@echo "Applying Terraform changes..."
	cd lab1-VPC+EC2+S3/environments/dev && terraform apply -auto-approve
destroy-dev-lab1 :
	@echo "Destroying Terraform-managed infrastructure..."
	cd lab1-VPC+EC2+S3/environments/dev && terraform destroy -auto-approve
show-dev-lab1 :
	@echo "Showing Terraform-managed infrastructure..."
	cd lab1-VPC+EC2+S3/environments/dev && terraform show
create-s3-ddb :
	@echo "Creating S3 bucket and DynamoDB table for Terraform state management..."
	cd lab1-VPC+EC2+S3/s3-ddb && terraform init && terraform plan && terraform apply -auto-approve
destroy-s3-ddb :
	@echo "Destroying S3 bucket and DynamoDB table for Terraform state management..."
	cd lab1-VPC+EC2+S3/s3-ddb && terraform destroy -auto-approve