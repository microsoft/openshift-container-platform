This CHANGELOG.md file will contain the update log for the latest set of updates to the templates


# UPDATES for Master (Release 3.10) - September 13, 2018

1.  Update to deploy 3.10
2.  Add support for 3rd party marketplace image
3.  Add support for broker pool ID in addition to compute pool ID


# UPDATES for Master (Release 3.9) - August 28, 2018

1.  Lock version to 3.9.33 - Azure Cloud Provider setup issues in 3.9.40


# UPDATES for Master (Release 3.9) - August 6, 2018

1.  Added support for private master nodes
2.  Addes support for private infra nodes
3.  Removed inbound NAT rules for master LB to better secure master nodes


# UPDATES for Master (Release 3.9) - July 14, 2018

1.  Added support for Accelerated Networking
2.  Added support for existing or new VNet


# UPDATES for Master (Release 3.9) - May 22, 2018

1.  Added parameter for CNS VM Size
2.  Added support for non-HA masters by allowing a single master
3.  Cleaned up Azure Cloud Provider configuration


# UPDATES for Master (Release 3.9) - May 19, 2018

1.  Updated scripts to support 3.9.27
2.  Added Support for RHEL 7.5
3.  Added Container Native Storage (CNS) support
4.  Added support for custom IP range for the Virtual Network

# UPDATES for Master (Release 3.9) - March 28, 2018

1.  Create Release 3.9 Branch
2.  Updating scripts for 3.9 repository
3.  Switch to port 443 for web console
4.  Remove old unused resources


# UPDATES for Master (Release 3.7) - February 14, 2018

1.  Created Release 3.7 Branch
2.  Update deployOpenShift.sh file to separate out Ansible Playbooks
3.  Created separate repo for OpenShift installation Playbooks


# UPDATES for Release 3.7 - January 12, 2018

1.  Inject the Private Key into Bastion host during prep.
2.  Add support for managed and unmanaged disks.
3.  Update prep script to simplify Cloud Access registration for username/password or activation key/organization id.
4.  Update Azure Cloud Provider playbooks - no need to delete node and include cluster reboot.
5.  Include additional data disk sizes.
6.  Create storage class based on managed or unmanaged disk.
7.  General cleanup.


# UPDATES for Release 3.6 - September 29, 2017

1.  Removed installation of Azure CLI as this is no longer needed.
2.  Removed dnslabel parameters and made them variables to simplify deployment.
3.  Added new D2-64v3, D2s-64sv3, E2-64v3, and E2s-64sv3 VM types.
4.  Updated prep scripts to include additional documented pre-requisites.
5.  Set OS disk size to 64 GB and updated prep scripts to expand root partition.
6.  Removed option to install single master cluster.  Now supports 3 or 5 Masters and 2 or 3 Infra nodes.
7.  Configure RHEL to use NetworkManager on eth0.
8.  Added additional troubleshooting for Azure Cloud Configuration playbooks (Exit Codes 7 - 10).
9.  Updated to latest versions of APIs - includes reworking of Storage Account creation.
10. Bastion Host - separate Storage Account and VM size definition.
11. Enabled Diagnostics Storage for all VMs.
12. Added Tags to all resources.
13. Switched to nip.io (versus xip.io).
14. Added option to enable Azure Cloud Provider (true or false).
15. Moved Metric and Logging setup to post cluster install.
16. General cleanup (removed unnecessary resources, variables, etc.).

