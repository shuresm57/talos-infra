# Terraform

How to use:

```bash
cd terraform
set -a; source ../.env; set +a
terraform init          # download the Hetzner provider
terraform validate      # check syntax
terraform plan          # preview what will be created
terraform apply         # create everything
```