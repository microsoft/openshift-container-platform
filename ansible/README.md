# OpenShift Container Platform Deployment using Ansible

## Prerequisites

- Ansible 2.7.x
- Azure service principal
- SSH public and private keys generated

### Red Hat Subscription Access

For security reasons, the method for registering the RHEL system allows the use of an Organization ID and Activation Key as well as a Username and Password. Please know that it is more secure to use the Organization ID and Activation Key.

You can determine your Organization ID by running ```subscription-manager identity``` on a registered machine.  To create or find your Activation Key, please go here: https://access.redhat.com/management/activation_keys.

You will also need to get the Pool ID that contains your entitlements for OpenShift.  You can retrieve this from the Red Hat portal by examining the details of the subscription that has the OpenShift entitlements.  Or you can contact your Red Hat administrator to help you.

## Setting up OpenShift

Copy **vars.example.yml** to **vars.yml** and edit the file to update all the variables with your information.

In general the only thing you will have to do is to make sure you have proper SSH keys available. By default your private key will be used from **~/.ssh/id_rsa**. Copy your public key content to **admin_pubkey:**

In addition you need to provide your RHEL username/password or organisation/key in following fields:
- **rhsm_username_org**
- **rhsm_password_key**
Please check last paragraph of this document to learn more.

Run the playbook:

```bash
ansible-playbook playbooks/create.yml -e @vars.yml
```
This playbook will deploy OpenShift Container Platform with basic username / password for authentication to OpenShift. It includes the following resources:

|Resource           	|Properties                                                                                                                          |
|-----------------------|------------------------------------------------------------------------------------------------------------------------------------|
|Virtual Network <br />Default  		|**Address prefix:** 10.0.0.0/14<br />**Master subnet:** 10.1.0.0/16<br />**Node subnet:** 10.2.0.0/16                      |
|Master Load Balancer	|1 probe and 1 rule for TCP 443                                       |
|Infra Load Balancer	|2 probes and 2 rules for TCP 80 and TCP 443									                                           |
|Public IP Addresses	|Bastion Public IP for Bastion Node<br />OpenShift Master public IP attached to Master Load Balancer (if masters are public)<br />OpenShift Router public IP attached to Infra Load Balancer (if router is public)           |
|Storage Accounts|1 Storage Account for Registry|
|Network Security Groups|1 Network Security Group for Bastion VM<br />1 Network Security Group Master VMs<br />1 Network Security Group for Infra VMs<br />1 Network Security Group for Node VMs |
|Availability Sets      |1 Availability Set for Master VMs<br />1 Availability Set for Infra VMs<br />1 Availability Set for Node VMs  |
|Virtual Machines   	|1 Bastion Node - Used to Run Ansible Playbook for OpenShift deployment<br />1, 3 or 5 Master Nodes<br />1, 2 or 3 Infra Nodes<br />User-defined number of Nodes (1 to 30)<br />All VMs include a single attached data disk for Docker thin pool logical volume|

![Cluster Diagram](../images/openshiftdiagram.jpg)


## Playbook Explanation

Playbook execution can be divided into a few phases. During these phases tasks run in parallel to save time

During fist phase following resources are created in parallel:
- Public IP addresses
- subnets
- network security groups
- availability sets

In the second phase following resources are created:
- load balancers for master and infrastructure nodes
- network interfaces for bastion, master, infra and node VMs
- storage - synchronous

In the third phase:
- bastion VM
- master VMs
- node VMs
- infra VMs

In the fourth phase, after all the virtual machines are successfully deployed:
- execute custom scripts on master infra and node VMs to set them up using **azure_rm_virtualmachine_extension** module - these tasks are performed asynchronously, but we won't wait for the result
- execute tasks on bastion VM to install OpenShift - these tasks will be performed synchronously


## Parameters Explanation

## azuredeploy.Parameters.json File Explained
| Property                          | Description                                                                                                                                                                                                                                                                                                                                          | Valid options                                                                        | Default value |
|-----------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------|---------------|
|`location`|Azure region for deployment|||
|`resource_group`|Resource group name|||
|`cluster_prefix`|Cluster name prefix, used as prefix for VM names|||
|`master_count`|Number of Masters nodes to deploy||3|
|`infra_count`|Number of infra nodes to deploy||3|
|`node_count`| Number of Nodes to deploy||2|
|`vm_size_master`|Size of the Master VM.||Standard_D2s_v3|
|`vm_size_infra`|Size of the Infra VM.||Standard_D4s_v3|
|`vm_size_node`|Size of the App Node VM.|| Standard_D2s_v3|
|`vm_size_bastion`|Size of the Bastion Node VM.||Standard_D2s_v3|
|`os_disk_size`|Size of OS disk|min 64 GB|64|
|`data_disk_size`|Size of data disk to attach to nodes for Docker volume|- 32 GB<br>- 64 GB<br>- 128 GB<br>- 256 GB<br>- 512 GB<br>- 1024 GB<br>- 2048 GB|64|
|`managed_disk_type`|Type of managed disk|- Premium_LRS|Premium_LRS|
|`admin_username`| Admin username for both OS (VM) login and initial OpenShift user||azureuser|
|`admin_pubkey`|Admin public key||azureuser|
|`admin_privkey`|Admin private key location||~/.ssh/id_rsa|
|`aad_client_id`||||
|`aad_client_secret`||||
|`subscription_id`||||
|`tenant_id`||||
|`rhsm_username_org`||||
|`rhsm_username_key`||||
|`rhsm_pool`||||
|`virtual_network_name`||||
|`virtual_network_cidr`||||
|`master_subnet_cidr`||||
|`infra_subnet_cidr`||||
|`node_subnet_cidr`||||
|`cns_subnet_cidr`||||
|`bastion_publicip`||||
|`master_lb_public_ip`||||
|`routing`||||
|`router_lb_public_ip`||||
|`registry_storage_account`||||
|`unmanaged_storage_class_account`||||
|`ocp_admin_passwd`||||
|`deploy_cns`||||
|`deploy_logging`||||
|`deploy_azure_cloud_provider`||||

### Red Hat Subscription Access

For security reasons, the method for registering the RHEL system allows the use of an Organization ID and Activation Key as well as a Username and Password. Please know that it is more secure to use the Organization ID and Activation Key.

You can determine your Organization ID by running ```subscription-manager identity``` on a registered machine.  To create or find your Activation Key, please go here: https://access.redhat.com/management/activation_keys.

You will also need to get the Pool ID that contains your entitlements for OpenShift.  You can retrieve this from the Red Hat portal by examining the details of the subscription that has the OpenShift entitlements.  Or you can contact your Red Hat administrator to help you.
