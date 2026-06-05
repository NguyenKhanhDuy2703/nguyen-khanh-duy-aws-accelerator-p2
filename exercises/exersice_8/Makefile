.PHONY: init plan apply destroy show create-s3-ddb destroy-s3-ddb clean-enis unlock-state unlock-dynamo

init:
	cd environments/dev && terraform init

plan:
	cd environments/dev && terraform plan

apply:
	cd environments/dev && terraform apply -auto-approve

destroy:
	cd environments/dev && terraform destroy -auto-approve

show:
	cd environments/dev && terraform show

create-s3-ddb:
	cd s3-ddb && terraform init && terraform plan && terraform apply -auto-approve

destroy-s3-ddb:
	cd s3-ddb && terraform destroy -auto-approve

# Usage: make clean-enis VPC_ID=vpc-xxxxxxxxx
clean-enis:
	pwsh -NoProfile -File scripts\clean_enis.ps1 -VpcId $(VPC_ID)

# Usage: make unlock-state LOCK_ID=xxxx-xxxx-xxxx-xxxx
unlock-state:
	cd environments/dev && terraform force-unlock -force $(LOCK_ID)

unlock-dynamo:
	aws dynamodb delete-item --table-name dev-terraform-state-lock --key "{\"LockID\":{\"S\":\"dev-terraform-state-bucket-kduy/lab1-vpc-ec2-s3/dev/terraform.tfstate\"}}"
