# Solution for the Assessment : Servian App Deployment with IAC

This solution depends on the servian tech app assessment.

## Pre requisites
- Install terraform into local machine.
https://learn.hashicorp.com/tutorials/terraform/install-cli

- Create an Azure SPN with contributor access (Using Azure Cli).
```
az login
az ad sp create-for-rbac --name servian_app_spn --role Contributor
```

- Export Environment variables in the current session(SPN credentials).

This can be used with any CI/CD tool as global variables (example: GitLab).
```
export TF_VAR_subscription_id="<>"
export TF_VAR_client_id="<>"         
export TF_VAR_client_secret="<>"      
export TF_VAR_tenant_id="<>"   
```

## Steps to proceed (Open up a bash shell and execute the following steps)

1. Clone the git repository [source files] (https://github.com/isurulakshan/servian-app-deployment-IAC.git).
2. ```cd servian-app-deployment-IAC/azure_vm_tf_deployment``` (Change directory to azure_vm_tf_deployment).
3. ```terraform init```  - Initialise the working directory with Terraform.
4. ```terraform plan``` - Evaluates Terraform configuration to determine the desired state of all the resources it declare.
5. ```terraform apply -auto-approve```  - Executes the actions proposed in a Terraform plan.

## Validate deployment

1. Check your Azure VM within the given tenant and resource group.
2. Enter VM’s <publicip:8080> in the web browser (Example: 20.122.3.1:8080).