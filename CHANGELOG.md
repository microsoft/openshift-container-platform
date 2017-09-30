This CHANGELOG.md file will contain the update log for the latest set of updates to the templates

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
16. General cleanup (removed unecessary resources, variables, etc.).

