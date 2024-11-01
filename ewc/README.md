# femdi-gateway-iac-ewc

## Cron jobs

This branch contains needed parts to create functional Vault backup Cron job. The branch is not functional with current Terraform setup! 

### TODO

The AWS Credentials needs to be created to the account with minimal privileges so that cron job can write to needed bucket

### MISC

The current Docker image naming and location might need rethinking. However you can deploy new image to GHCR with

```bash
docker build --platform=linux/amd64 -t ghcr.io/eurodeo/femdi-gateway-iac/vault-snapshot:latest -f Dockerfile.vault-snapshot .

docker push ghcr.io/eurodeo/femdi-gateway-iac/vault-snapshot:latest
```
