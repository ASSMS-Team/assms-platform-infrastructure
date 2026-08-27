# Two-Region Staging Architecture

ASSMS staging uses Southeast Asia and Central India because the Southeast Asia Azure for Students regional vCPU quota is 6 while the five planned B-series VMs require 10 vCPUs.

| Region | VNet | Services |
|---|---|---|
| Southeast Asia | `vnet-assms-staging` — `10.20.0.0/16` | Customer, Job, Kafka, MySQL, frontend App Service |
| Central India | `vnet-assms-staging-secondary` — `10.30.0.0/16` | Dispatch, Reporting |

The VNets are connected by bidirectional Global VNet Peering. Address spaces do not overlap; gateway transit and remote gateways are disabled. The secondary subnet `10.30.1.0/24` can reach Kafka privately at `10.20.2.4:9092` and resolve MySQL through the secondary private-DNS link.

This is a staging cost/quota design, not a production topology decision. Application deployment has not started.
