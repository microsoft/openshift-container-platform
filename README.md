# OpenShift Container Platform Deployment Template

## NOTE: Structure of Repo

**The Master branch has been updated to deploy version 3.11**

**MAJOR UPDATES HAVE BEEN MADE - READ BEFORE DEPLOYING**

The master branch contains the most current release of OpenShift Container Platform with experimental items.  This may cause instability but will include new items or enable new configuration options. We will maintain the templates for the current version of OCP as well as one version back (N-1). The older branches will not be deleted but will no longer be maintained or updated.

New as of August 27, 2019: I have added the azurestack-release-3.11 branch with templates and scripts for deploying OCP 3.11 to Azure Stack.

The following branches exist:

**Commercial Azure**
- Release-3.6 (As is; no longer updated)
- Release-3.7 (As is; no longer updated)
- Release-3.9 (As is; no longer updated)
- Release-3.10

**Azure Stack**
- azurestack-release-3.7 (As is; no longer updated)
- azurestack-release-3.9 (As is; no longer updated)
- azurestack-release-3.11

Bookmark [aka.ms/OpenShift](http://aka.ms/OpenShift) for future reference.

**For OpenShift Origin refer to https://github.com/Microsoft/openshift-origin**

## OpenShift Container Platform 3.11 with Username / Password authentication for OpenShift

1.  Single master option available
2.  VM types that support Accelerated Networking will automatically have this feature enabled
3.  Custom and existing Vnet
4.  Support cluster with private masters (no public IP on load balancer in front of master nodes)
5.  Support cluster with private router (no public IP on load balancer in front of infra nodes)
6.  Support broker pool ID (for master and infra nodes) along with compute pool ID (for compute nodes)
7.  Support for default gallery RHEL On Demand image and 3rd party Marketplace offer such as BYOS image in Private Marketplace
8.  Support self-signed certificates or custom SSL certificates for master load balancer (Web Console)
9.  Support self-signed certificates or custom SSL certificates for infra load balancer (Router)


This template deploys OpenShift Container Platform with basic username / password for authentication to OpenShift. It includes the following resources:

|Resource           	|Properties                                                                                                                          |
|-----------------------|------------------------------------------------------------------------------------------------------------------------------------|
|Virtual Network <br />Default  		|**Address prefix:** 10.0.0.0/14<br />**Master subnet:** 10.1.0.0/16<br />**Infra subnet:** 10.2.0.0/16<br />**Node subnet:** 10.3.0.0/16                      |
|Virtual Network <br />Custom   		|**Address prefix:** Your Choice<br />**Master subnet:** Your Choice<br />**Infra subnet:** Your Choice<br />**CNS subnet:** Your Choice<br />**Node subnet:** Your Choice                      |
|Master Load Balancer	|1 probe and 1 rule for TCP 443                                       |
|Infra Load Balancer	|2 probes and 2 rules for TCP 80 and TCP 443									                                           |
|Public IP Addresses	|Bastion Public IP for Bastion Node<br />OpenShift Master public IP attached to Master Load Balancer (if masters are public)<br />OpenShift Router public IP attached to Infra Load Balancer (if router is public)           |
|Storage Accounts <br />Unmanaged Disks  	|1 Storage Account for Bastion VM <br />1 Storage Account for Master VMs <br />1 Storage Account for Infra VMs<br />2 Storage Accounts for Node VMs<br />2 Storage Accounts for Diagnostics Logs <br />1 Storage Account for Private Docker Registry  |
|Storage Accounts <br />Managed Disks      |2 Storage Accounts for Diagnostics Logs <br />1 Storage Account for Private Docker Registry |
|Network Security Groups|1 Network Security Group for Bastion VM<br />1 Network Security Group Master VMs<br />1 Network Security Group for Infra VMs<br />1 Network Security Group for CNS VMs (if CNS enabled)<br />1 Network Security Group for Node VMs |
|Availability Sets      |1 Availability Set for Master VMs<br />1 Availability Set for Infra VMs<br />1 Availability Set for CNS VMs (if CNS enabled)<br />1 Availability Set for Node VMs  |
|Virtual Machines   	|1 Bastion Node - Used to run ansible playbook for OpenShift deployment<br />1, 3 or 5 Master Nodes<br />1, 2 or 3 Infra Nodes<br />3 or 4 CNS Nodes (if CNS enabled)<br />User-defined number of Nodes (1 to 30)<br />All VMs include a single attached data disk for Docker thin pool logical volume<br />CNS VMs include 3 additional data disks for glusterfs storage (if CNS enabled)|

![Cluster Diagram](images/openshiftdiagram.jpg)

## READ the instructions in its entirety before deploying!

Additional documentation for deploying OpenShift in Azure can be found here: https://docs.microsoft.com/en-us/azure/virtual-machines/linux/openshift-get-started

This template deploys multiple VMs and requires some pre-work before you can successfully deploy the OpenShift Cluster.  If you don't complete the pre-work correctly, you will most likely fail to deploy the cluster using this template.  Please read the instructions completely before you proceed. 

By default, this template uses the On-Demand Red Hat Enterprise Linux image from the Azure Gallery. 
>When using the On-Demand image, there is an additional hourly RHEL subscription charge for using this image on top of the normal compute, network and storage costs.  At the same time, the instance will be registered to your Red Hat subscription, so you will also be using one of your entitlements. This will lead to "double billing". To avoid this, you would need to build your own RHEL image, which is defined in [this Red Hat KB article](https://access.redhat.com/articles/uploading-rhel-image-to-azure). 

If you have a valid Red Hat subscription, register for Cloud Access and [request access](http://aka.ms/rhel-byos) to the BYOS RHEL image in the Private Azure Marketplace to avoid the double billing. To use a 3rd party marketplace offer (such as the BYOS private image), you need to provide the following information for the offer - publisher, offer, sku, and version.  You also need to enable the offer for programmatic deployment.

If you are only using one pool ID for all nodes, then enter the same pool ID for both 'rhsmPoolId' and 'rhsmBrokerPoolId'.

**Private Clusters**

Deploying private OpenShift clusters requires more than just not having a public IP associated to the master load balancer (web console) or to the infra load balancer (router).  A private cluster generally uses a custom DNS server (not the default Azure DNS), a custom domain name (such as contoso.com), and pre-defined virtual network(s).  For private clusters, you will need to configure your virtual network with all the appropriate subnets and DNS server settings in advance.  Then use **existingMasterSubnetReference**, **existingInfraSubnetReference**, **existingCnsSubnetReference**, and **existingNodeSubnetReference** to specify the existing subnet for use by the cluster.

If private masters is selected (**masterClusterType**=private), a static private IP needs to be specified for **masterPrivateClusterIp** which will be assigned to the front end of the master load balancer.  This must be within the CIDR for the master subnet and not already in use.  **masterClusterDnsType** must be set to "custom" and the master DNS name must be provided for **masterClusterDns** and this needs to map to the static Private IP and will be used to access the console on the master nodes.

If private router is selected (**routerClusterType**=private), a static private IP needs to be specified for **routerPrivateClusterIp** which will be assigned to the front end of the infra load balancer.  This must be within the CIDR for the infra subnet and not already in use.  **routingSubDomainType** must be set to "custom" and the wildcard DNS name for routing must be provided for **routingSubDomain**.  

If private masters and private router is selected, the custom domain name must also be entered for **domainName**

After successful deployment, the Bastion Node is the only node with a public IP that you can ssh into.  Even if the master nodes are configured for public access, they are not exposed for ssh access.

## Prerequisites

### Create Key Vault to store secret based information

You will need to create a Key Vault to store various secret information that will then be used as part of the deployment so that the information is not exposed via the parameters file.  Secrets will need to be created for the SSH private key (**sshPrivateKey**), Azure AD client secret (**aadClientSecret**), OpenShift admin password (**openshiftPassword**), and Red Hat Subscription Manager password or activation key (**rhsmPasswordOrActivationKey**).  Additionally, if custom SSL certificates are used, then 6 additional secrets will need to be created - **routingcafile**, **routingcertfile**, **routingkeyfile**, **mastercafile**, **mastercertfile**, and **masterkeyfile**.  These will be explained in more detail.

The template references specific secret names so you **must** use the bolded names listed above (case sensitive).

It is recommend to create a separate Resource Group specifically to store the KeyVault.  This way, you can reuse the KeyVault for other deployments and you won't have to create this every time you chose to deploy another OpenShift cluster.

**Create Key Vault using Azure CLI**
1.  Create new Resource Group: az group create -n \<name\> -l \<location\><br/>
    Ex: `az group create -n KeyVaultResourceGroupName -l 'East US'`<br/>
1.  Create Key Vault: az keyvault create -n \<vault-name\> -g \<resource-group\> -l \<location\> --enabled-for-template-deployment true<br/>
    Ex: `az keyvault create -n KeyVaultName -g KeyVaultResourceGroupName -l 'East US' --enabled-for-template-deployment true`<br/>

### Generate SSH Keys

You'll need to generate an SSH key pair (Public / Private) in order to provision this template. Ensure that you do **NOT** include a passphrase with the private key.

If you are using a Windows computer, you can download puttygen.exe.  You will need to export to OpenSSH (from Conversions menu) to get a valid Private Key for use in the Template.

From a Linux or Mac, you can just use the ssh-keygen command.  Once you are finished deploying the cluster, you can always generate new keys that uses a passphrase and replace the original ones used during initial deployment.

**Store SSH Private key in Secret**

1.  Create Secret: az keyvault secret set --vault-name \<vault-name\> -n \<secret-name\> --file \<private-key-file-name\><br/>
    Ex: `az keyvault secret set --vault-name KeyVaultName -n sshPrivateKey --file ~/.ssh/id_rsa`<br/>

### Generate Azure Active Directory (AAD) Service Principal

To configure Azure as the Cloud Provider for OpenShift Container Platform, you will need to create an Azure Active Directory Service Principal.  The easiest way to perform this task is via the Azure CLI.  Below are the steps for doing this.

Assigning permissions to the entire Subscription is the easiest method but does give the Service Principal permissions to all resources in the Subscription.  Assigning permissions to only the Resource Group is the most secure as the Service Principal is restricted to only that one Resource Group. 
   
**Azure CLI 2.0**

1. **Create Service Principal and assign permissions to Subscription**<br/>
  a.  az ad sp create-for-rbac -n \<friendly name\> --password \<password\> --role contributor --scopes /subscriptions/\<subscription_id\><br/>
      Ex: `az ad sp create-for-rbac -n openshiftcloudprovider --password Pass@word1 --role contributor --scopes /subscriptions/555a123b-1234-5ccc-defgh-6789abcdef01`<br/>

2. **Create Service Principal and assign permissions to Resource Group**<br/>
  a.  If you use this option, you must have created the Resource Group first.  Be sure you don't create any resources in this Resource Group before deploying the cluster.<br/>
  b.  az ad sp create-for-rbac -n \<friendly name\> --password \<password\> --role contributor --scopes /subscriptions/\<subscription_id\>/resourceGroups/\<Resource Group Name\><br/>
      Ex: `az ad sp create-for-rbac -n openshiftcloudprovider --password Pass@word1 --role contributor --scopes /subscriptions/555a123b-1234-5ccc-defgh-6789abcdef01/resourceGroups/00000test`<br/>

3. **Create Service Principal without assigning permissions to Resource Group**<br/>
  a.  If you use this option, you will need to assign permissions to either the Subscription or the newly created Resource Group shortly after you initiate the deployment of the cluster or the post installation scripts will fail when configuring Azure as the Cloud Provider.<br/>
  b.  az ad sp create-for-rbac -n \<friendly name\> --password \<password\> --role contributor --skip-assignment<br/>
      Ex: `az ad sp create-for-rbac -n openshiftcloudprovider --password Pass@word1 --role contributor --skip-assignment`<br/>

You will get an output similar to:

```javascript
{
  "appId": "2c8c6a58-44ac-452e-95d8-a790f6ade583",
  "displayName": "openshiftcloudprovider",
  "name": "http://openshiftcloudprovider",
  "password": "Pass@word1",
  "tenant": "12a345bc-1234-dddd-12ab-34cdef56ab78"
}
```

The appId is used for the aadClientId parameter.  Store the password in the Key Vault.

```bash
az keyvault secret set --vault-name KeyVaultName -n aadClientSecret --value Pass@word1
```

### OpenShift Admin Password

An initial OpenShift Cluster Admin user will be created after the cluster is deployed.  This admin user will need a password.  Store the password that you want to use in the Key Vault.

```bash
az keyvault secret set --vault-name KeyVaultName -n openshiftPassword --value Pass@word1
```

### Red Hat Subscription Access

For security reasons, the method for registering the RHEL system allows the use of an Organization ID and Activation Key as well as a Username and Password. Please know that it is more secure to use the Organization ID and Activation Key.

You can determine your Organization ID by running ```subscription-manager identity``` on a registered machine.  To create or find your Activation Key, please go here: https://access.redhat.com/management/activation_keys.

You will also need to get the Pool ID that contains your entitlements for OpenShift.  You can retrieve this from the Red Hat portal by examining the details of the subscription that has the OpenShift entitlements.  Or you can contact your Red Hat administrator to help you.

Store the password or activation key that you want to use in the Key Vault.

```bash
az keyvault secret set --vault-name KeyVaultName -n rhsmPasswordOrActivationKey --value Pass@word1
```

### Custom Certificates

By default, the template will deploy an OpenShift cluster using self-signed certificates for the OpenShift web console and the routing domain. If you want to use custom SSL certificates, set 'routingCertType' to 'custom' and 'masterCertType' to 'custom'.  You will need the CA, Cert, and Key files in .pem format for the certificates.

You will need to store these files in Key Vault secrets.  Use the same Key Vault as the one used for the private key.  Rather than require 6 additional inputs for the secret names, the template is hard-coded to use specific secret names for each of the SSL certificate files.  Store the certficiate data using the information from the following table.

| Secret Name      | Certificate file   |
|------------------|--------------------|
| mastercafile     | master CA file     |
| mastercertfile   | master CERT file   |
| masterkeyfile    | master Key file    |
| routingcafile    | routing CA file    |
| routingcertfile  | routing CERT file  |
| routingkeyfile   | routing Key file   |

Create the secrets using the Azure CLI. Below is an example.

```bash
az keyvault secret set --vault-name KeyVaultName -n mastercafile --file ~/certificates/masterca.pem
```

## azuredeploy.Parameters.json File Explained
| Property                          | Description                                                                                                                                                                                                                                                                                                                                          | Valid options                                                                        | Default value |
|-----------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------|---------------|
| `_artifactsLocation`      | URL for artifacts (json, scripts, etc.)                                     |                                  |  https://raw.githubusercontent.com/Microsoft/openshift-container-platform/master        |
| `location`                | Azure region to deploy resources to                                         |                                  |               |
| `masterVmSize`            | Size of the Master VM. Select from one of the allowed VM sizes listed in the azuredeploy.json file          |                                                                        | Standard_E2s_v3   |
| `infraVmSize`             | Size of the Infra VM. Select from one of the allowed VM sizes listed in the azuredeploy.json file           |                                                                        | Standard_D4s_v3   |
| `nodeVmSize`              | Size of the App Node VM. Select from one of the allowed VM sizes listed in the azuredeploy.json file        |                                                                        | Standard_D4s_v3   |
| `cnsVmSize`               | Size of the CNS Node VM. Select from one of the allowed VM sizes listed in the azuredeploy.json file        |                                                                        | Standard_E4s_v3   |
| `osImageType`             | The RHEL image to use. defaultgallery: On-Demand; marketplace: 3rd Party image                              | - "defaultgallery" <br><br>- "marketplace"                             | defaultgallery    |
| `marketplaceOsImage`      | If `osImageType` is marketplace, then enter the appropriate values for 'publisher', 'offer', 'sku', 'version' of the marketplace offer. This is an object type       |               |                   |
| `storageKind`             | The type of storage to be used.                                                                             | - "managed"<br>- "unmanaged"                                           | managed           |
| `openshiftClusterPrefix`  | Cluster Prefix used to configure hostnames for all nodes.  Between 1 and 20 characters                      |                                                                        | mycluster         |
| `minoVersion`             | The minor version of OpenShift Container Platform 3.11 to deploy                                            |                                                                        | 69                |
| `masterInstanceCount`     | Number of Masters nodes to deploy                                                                           | - 1, 3, 5                                                              | 3                 |
| `infraInstanceCount`      | Number of infra nodes to deploy                                                                             | - 1, 2, 3                                                              | 3                 |
| `nodeInstanceCount`       | Number of Nodes to deploy                          | - 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30                 | 2                 |
| `cnsInstanceCount`        | Number of CNS nodes to deploy                                                                               | - 3, 4                                                                 | 3                 |
| `osDiskSize`              | Size of OS disk for the VM (in GB)                                                                          | - 64 <br>- 128 <br>- 256 <br>- 512 <br>- 1024 <br>- 2048               | 64                |
| `dataDiskSize`            | Size of data disk to attach to nodes for Docker volume (in GB)                                              | - 32 <br>- 64 <br>- 128 <br>- 256 <br>- 512 <br>- 1024 <br>- 2048      | 128               |
| `cnsGlusterDiskSize`      | Size of data disk to attach to CNS nodes for use by gluster (in GB)                                         | - 32 <br>- 64 <br>- 128 <br>- 256 <br>- 512 <br>- 1024 <br>- 2048      | 128               |
| `adminUsername`           | Admin username for both OS (VM) login and initial OpenShift user                                            |                                                                        | ocpadmin          |
| `enableMetrics`           | Enable Metrics. Metrics require more resources so select proper size for Infra VM                           | - "true"<br>- "false"                                                  | false             |
| `enableLogging`           | Enable Logging. elasticsearch pod requires 8 GB RAM so select proper size for Infra VM                      | - "true"<br>- "false"                                                  | false             |
| `enableCNS`               | Enable Container Native Storage (CNS)                                                                       | - "true"<br>- "false"                                                  | false             |
| `rhsmUsernameOrOrgId`     | Red Hat Subscription Manager Username or Organization ID                                                    |                                                                        |                   |
| `rhsmPoolId`              | The Red Hat Subscription Manager Pool ID that contains your OpenShift entitlements for compute nodes        |                                                                        |                   |
| `rhsmBrokerPoolId`        | The Red Hat Subscription Manager Pool ID that contains your OpenShift entitlements for masters and infra nodes. If you don't have different pool IDs, enter same pool ID as 'rhsmPoolId'  |              |
| `sshPublicKey`            | Copy your SSH Public Key here                                                                               |                                                                        |                   |
| `keyVaultSubscriptionId`  | The Subscription ID of the subscription that contains the Key Vault                                         |                                                                        |                   |
| `keyVaultResourceGroup`   | The name of the Resource Group that contains the Key Vault                                                  |                                                                        |                   |
| `keyVaultName`            | The name of the Key Vault you created                                                                       |                                                                        |                   |
| `enableAzure`             | Enable Azure Cloud Provider                                                                                 | - "true"<br>- "false"                                                  | true              |
| `aadClientId`             | Azure Active Directory Client ID also known as Application ID for Service Principal                         |                                                                        |                   |
| `domainName`              | Name of the custom domain name to use (if applicable). Set to "none" if not deploying fully private cluster |                                                                        | none              |
| `masterClusterDnsType`    | Domain type for OpenShift web console. 'default' will use DNS label of master infra public IP. 'custom' allows you to define your own name.          | - "default"<br>- "custom"     | default           |
| `masterClusterDns`        | The custom DNS name to use to access the OpenShift web console if you selected 'custom' for `masterClusterDnsType`                                   |                               | console.contoso.com  |
| `routingSubDomainType`    | This will either be nipio (if you don't have your own domain) or 'custom' if you have your own domain that you would like to use for routing         | - "nipio"<br>- "custom"       | nipio             |
| `routingSubDomain`        | The wildcard DNS name you would like to use for routing if you selected 'custom' for `routingSubDomainType`                                          |                               | apps.contoso.com  |
| `virtualNetworkNewOrExisting`   | Select whether to use an existing Virtual Network or create a new Virtual Network                                                              | - "existing"<br>- "new"       | new               |
| `virtualNetworkResourceGroupName` | Name of the Resource Group for the new Virtual Network if you selected 'new' for `virtualNetworkNewOrExisting`                               |                               | resourceGroup().name |
| `virtualNetworkName`            | The name of the new Virtual Network to create if you selected 'new' for `virtualNetworkNewOrExisting`                                          |                               | openshiftvnet     |
| `addressPrefixes`               | Address prefix of the new virtual network                                                             |         | 10.0.0.0/14   |
| `masterSubnetName`              | The name of the master subnet                                                                         |         | mastersubnet  |
| `masterSubnetPrefix`            | CIDR used for the master subnet - needs to be a subset of the addressPrefix                           |         | 10.1.0.0/16   |
| `infraSubnetName`               | The name of the infra subnet                                                                          |         | infrasubnet   |
| `infraSubnetPrefix`             | CIDR used for the infra subnet - needs to be a subset of the addressPrefix                            |         | 10.2.0.0/16   |
| `nodeSubnetName`                | The name of the node subnet                                                                           |         | nodesubnet    |
| `nodeSubnetPrefix`              | CIDR used for the node subnet - needs to be a subset of the addressPrefix                             |         | 10.3.0.0/16   |
| `existingMasterSubnetReference` | Full reference to existing subnet for master nodes. Not needed if creating new vNet / Subnet          |         |               |
| `existingInfraSubnetReference`  | Full reference to existing subnet for infra nodes. Not needed if creating new vNet / Subnet           |         |               |
| `existingCnsSubnetReference`    | Full reference to existing subnet for cns nodes. Not needed if creating new vNet / Subnet             |         |               |
| `existingNodeSubnetReference`   | Full reference to existing subnet for compute nodes. Not needed if creating new vNet / Subnet         |         |               |
| `masterClusterType`             | Specify whether the cluster uses private or public master nodes. If private is chosen, the master nodes will not be exposed to the Internet via a public IP. Instead, it will use the private IP specified in the `masterPrivateClusterIp`                                                                                                                  | - "public"<br>- "private"                                                       | public        |
| `masterPrivateClusterIp`        | If private master nodes is selected, then a private IP address must be specified for use by the internal load balancer for master nodes. This will be a static IP so it must reside within the CIDR block for the master subnet and not already in use. If public master nodes is selected, this value will not be used but must still be specified.        |                                                                                 | 10.1.0.200    |
| `routerClusterType`             | Specify whether the cluster uses private or public infra nodes. If private is chosen, the infra nodes will not be exposed to the Internet via a public IP. Instead, it will use the private IP specified in the `routerPrivateClusterIp`                                                                                                                  | - "public"<br>- "private"                                                       | public        |
| `routerPrivateClusterIp`        | If private infra nodes is selected, then a private IP address must be specified for use by the internal load balancer for infra nodes. This will be a static IP so it must reside within the CIDR block for the master subnet and not already in use. If public infra nodes is selected, this value will not be used but must still be specified.         |                                                                                 | 10.2.0.200    |
| `routingCertType`               | Use custom certificate for routing domain or the default self-signed certificate - follow instructions in **Custom Certificates** section              | - "selfsigned"<br>- "custom"   | selfsigned    |
| `masterCertType`                | Use custom certificate for master domain or the default self-signed certificate - follow instructions in **Custom Certificates** section               | - "selfsigned"<br>- "custom"   | selfsigned    |



## Deploy Template

Once you have collected all of the prerequisites for the template, you can deploy the template by populating the **azuredeploy.parameters.json** file and executing Resource Manager deployment commands with PowerShell or the Azure CLI.

**Azure CLI 2.0**

1. Create Resource Group: az group create -n \<name\> -l \<location\><br />
Ex: `az group create -n openshift-cluster -l westus`
2. Create Resource Group Deployment: az group deployment create --name \<deployment name\> --template-file \<template_file\> --parameters @\<parameters_file\> --resource-group \<resource group name\> --nowait<br />
Ex: `az group deployment create --name ocpdeployment --template-file azuredeploy.json --parameters @azuredeploy.parameters.json --resource-group openshift-cluster --no-wait`


### NOTE

The OpenShift Ansible playbook does take a while to run when using VMs backed by Standard Storage. VMs backed by Premium Storage are faster. If you want Premium Storage, select a DS, Es, or GS series VM.  It is highly recommended that Premium storage be used.
<hr />

If the Azure Cloud Provider is not enabled, then the Service Catalog and Ansible Template Service Broker will not be installed as Service Catalog requires persistent storage.

Be sure to follow the OpenShift instructions to create the necessary DNS entry for the OpenShift Router for access to applications. <br />

A Standard Storage Account is provisioned to provide persistent storage for the integrated OpenShift Registry as Premium Storage does not support storage of anything but VHD files.


### TROUBLESHOOTING

If you encounter an error during deployment of the cluster, please view the deployment status.  The following Error Codes will help to narrow things down.

1.  Exit Code 3:  Your Red Hat Subscription User Name / Password or Organization ID / Activation Key is incorrect
2.  Exit Code 4:  Your Red Hat Pool ID is incorrect or there are no entitlements available
3.  Exit Code 5:  Unable to provision Docker Thin Pool Volume
4.  Exit Code 99: Configuration playbooks were not downloaded

Before opening an issue, ssh to the Bastion node and review the stdout and stderr files as explained below. The stdout file will most likely contain the most useful information so please do include the last 50 lines of the stdout file in the issue description.  Do NOT copy the error output from the Azure portal.

You can SSH to the Bastion node and from there SSH to each of the nodes in the cluster and fix the issues.

A common cause for the failures related to the node service not starting is the Service Principal did not have proper permissions to the Subscription or the Resource Group.  If this is indeed the issue, then assign the correct permissions and manually re-run the script that failed an all subsequent scripts.  Be sure to restart the service that failed (e.g. systemctl restart atomic-openshift-node.service) before executing the scripts again.

For further troubleshooting, please SSH into your Bastion node on port 22.  You will need to be root **(sudo su -)** and then navigate to the following directory: **/var/lib/waagent/custom-script/download**<br/><br/>
You should see a folder named '0' and '1'.  In each of these folders, you will see two files, stderr and stdout.  You can look through these files to determine where the failure occurred.

## Post-Deployment Operations

### Service Catalog

**Service Catalog**

If you enable Azure or CNS for storage these scripts will deploy the service catalog as a post deployment option.

### Metrics and logging

**Metrics**

If you deployed Metrics, it will take a few extra minutes for deployment to complete. Please be patient.

Once the deployment is complete, log into the OpenShift Web Console and complete an addition configuration step.  Go to the openshift-infra project, click on Hawkster metrics route, and accept the SSL exception in your browser.

**Logging**

If you deployed Logging, it will take a few extra minutes for deployment to complete. Please be patient.

Once the deployment is complete, log into the OpenShift Web Console and complete an addition configuration step.  Go to the logging project, click on the Kubana route, and accept the SSL exception in your browser.

### Creation of additional users

To create additional (non-admin) users in your environment, login to your master server(s) via SSH and run:
<br><i>htpasswd /etc/origin/master/htpasswd mynewuser</i>

### Additional OpenShift Configuration Options
 
You can configure additional settings per the official (<a href="https://docs.openshift.com/container-platform/3.10/welcome/index.html" target="_blank">OpenShift Enterprise Documentation</a>).
