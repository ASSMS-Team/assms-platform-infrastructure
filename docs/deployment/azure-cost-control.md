# Azure Staging Cost Control

ASSMS uses Azure for Students, so staging is deliberately cost constrained.

- Backend and Kafka use economical `Standard_B2pls_v2` Arm64 VMs.
- The frontend uses the F1 Free Linux App Service tier for staging.
- MySQL uses `Standard_B1ms`, 20 GiB storage, and disabled auto-grow.
- Monitoring is deferred to ASSMS-18.
- All five staging VMs are currently deallocated.

```powershell
az vm start --resource-group rg-assms-staging --name <vm-name>
az vm deallocate --resource-group rg-assms-staging --name <vm-name>
```

Deallocation stops VM compute billing but preserves the VM, disk, NIC, IP configuration, and state. Managed disks, Standard public IPs, MySQL, storage, and data transfer may still be billed. Deallocated VMs also retain vCPU quota allocation.
