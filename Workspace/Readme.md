```sh
terraform workspace List
```

```sh
terraform workspace new dev
terraform workspace new stage
terraform workspace new prod
```

# To switch into the workspace
```sh
terraform workspace select <workspace_name>
```

```sh
terraform workspace show
```

```sh
terraform workspace delete
```
```sh
terraform apply -var-file=dev.tfvars
terraform apply -var-file=stage.tfvars
terraform apply -var-file=prod.tfvars
```

