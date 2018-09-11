This CHANGELOG.md file will contain the update log for the latest set of updates to the templates

# UPDATES for Release 3.9 - May 5, 2018

1.  Lock version to 3.9.33 - Azure Cloud Provider setup issues in 3.9.40
2.  Added support for private master nodes
3.  Addes support for private infra nodes
4.  Removed inbound NAT rules for master LB to better secure master nodes
5.  Added support for Accelerated Networking
6.  Added support for existing or new VNet
7.  Added parameter for CNS VM Size
8.  Added support for non-HA masters by allowing a single master
9.  Cleaned up Azure Cloud Provider configuration
10. Added Support for RHEL 7.5
11. Added Container Native Storage (CNS) support
12. Added support for custom IP range for the Virtual Network


# UPDATES for Master (Release 3.9) - May 5, 2018

1.  Include playbook to test for DNS name resolution - accomodate for Azure network latency during deployment
2.  Move Service Catalog install to post cluster standup
3.  Clean up deployment script


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

