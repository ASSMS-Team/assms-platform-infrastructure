# Azure Staging Cost Control

ASSMS uses Azure for Students, so staging is deliberately cost constrained.

- Backend and Kafka use economical `Standard_B2pls_v2` Arm64 VMs.
- The frontend uses the F1 Free Linux App Service tier for staging.
- MySQL uses `Standard_B1ms`, 20 GiB storage, and disabled auto-grow.
- Monitoring is configured under ASSMS-18.
- Azure API Management (APIM Developer Tier) is conditionally enabled only during gateway testing.
- All staging VMs are deallocated when not actively in use.

```powershell
az vm start --resource-group rg-assms-staging --name <vm-name>
az vm deallocate --resource-group rg-assms-staging --name <vm-name>
```

Deallocation stops VM compute billing but preserves the VM, disk, NIC, IP configuration, and state. Managed disks, Standard public IPs, MySQL, storage, and data transfer may still be billed. Deallocated VMs also retain vCPU quota allocation.

## Azure API Management (APIM) Cost Control

The Developer tier of Azure API Management incurs an ongoing hourly/monthly cost while provisioned. To eliminate APIM charges immediately after gateway testing/evaluation is completed:

1. In your staging `terraform.tfvars`, toggle the enable flag off:
   ```hcl
   api_management_enabled = false
   ```
2. Apply the Terraform change to destroy the APIM instance while leaving the rest of the staging platform and subnets intact:
   ```bash
   terraform apply -target=module.api_management
   ```
   or run standard `terraform apply`.
3. The frontend can fall back to direct service URLs in `.env` if local/direct testing is needed without the APIM gateway.

