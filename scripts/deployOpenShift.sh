#!/bin/bash

echo $(date) " - Starting Script"

set -e

export SUDOUSER=$1
export PASSWORD="$2"
export MASTER=$3
export MASTERPUBLICIPHOSTNAME=$4
export MASTERPUBLICIPADDRESS=$5
export INFRA=$6
export NODE=$7
export NODECOUNT=$8
export INFRACOUNT=$9
export MASTERCOUNT=${10}
export ROUTING=${11}
export REGISTRYSA=${12}
export ACCOUNTKEY="${13}"
export METRICS=${14}
export LOGGING=${15}
export TENANTID=${16}
export SUBSCRIPTIONID=${17}
export AADCLIENTID=${18}
export AADCLIENTSECRET="${19}"
export RESOURCEGROUP=${20}
export LOCATION=${21}
export AZURE=${22}
export STORAGEKIND=${23}
export ENABLECNS=${24}
export CNS=${25}
export CNSCOUNT=${26}
export VNETNAME=${27}
export NODENSG=${28}
export NODEAVAILIBILITYSET=${29}
export MASTERCLUSTERTYPE=${30}
export PRIVATEIP=${31}
export PRIVATEDNS=${32}
export MASTERPIPNAME=${33}
export ROUTERCLUSTERTYPE=${34}
export INFRAPIPNAME=${35}

export BASTION=$(hostname)

# Determine if Commercial Azure or Azure Government
CLOUD=$( curl -H Metadata:true "http://169.254.169.254/metadata/instance/compute/location?api-version=2017-04-02&format=text" | cut -c 1-2 )
export CLOUD=${CLOUD^^}

export MASTERLOOP=$((MASTERCOUNT - 1))
export INFRALOOP=$((INFRACOUNT - 1))
export NODELOOP=$((NODECOUNT - 1))

echo "Configuring SSH ControlPath to use shorter path name"

sed -i -e "s/^# control_path = %(directory)s\/%%h-%%r/control_path = %(directory)s\/%%h-%%r/" /etc/ansible/ansible.cfg
sed -i -e "s/^#host_key_checking = False/host_key_checking = False/" /etc/ansible/ansible.cfg
sed -i -e "s/^#pty=False/pty=False/" /etc/ansible/ansible.cfg
sed -i -e "s/^#stdout_callback = skippy/stdout_callback = skippy/" /etc/ansible/ansible.cfg

# Run on MASTER-0 node - configure registry to use Azure Storage
# Create docker registry config based on Commercial Azure or Azure Government
if [[ $CLOUD == "US" ]]
then
    DOCKERREGISTRYYAML=dockerregistrygov.yaml
    export CLOUDNAME="AzureUSGovernmentCloud"
else
    DOCKERREGISTRYYAML=dockerregistrypublic.yaml
    export CLOUDNAME="AzurePublicCloud"
fi

# Setting the default openshift_cloudprovider_kind if Azure enabled
if [[ $AZURE == "true" ]]
then
    CLOUDKIND="openshift_cloudprovider_kind=azure
osm_controller_args={'cloud-provider': ['azure'], 'cloud-config': ['/etc/origin/cloudprovider/azure.conf']}
osm_api_server_args={'cloud-provider': ['azure'], 'cloud-config': ['/etc/origin/cloudprovider/azure.conf']}
openshift_node_kubelet_args={'cloud-provider': ['azure'], 'cloud-config': ['/etc/origin/cloudprovider/azure.conf'], 'enable-controller-attach-detach': ['true']}"
fi

# Cloning Ansible playbook repository

echo $(date) " - Cloning Ansible playbook repository"

((cd /home/$SUDOUSER && git clone https://github.com/Microsoft/openshift-container-platform-playbooks.git) || (cd /home/$SUDOUSER/openshift-container-platform-playbooks && git pull))

if [ -d /home/${SUDOUSER}/openshift-container-platform-playbooks ]
then
    echo " - Retrieved playbooks successfully"
else
    echo " - Retrieval of playbooks failed"
    exit 99
fi

# Creating variables file for future playbooks
echo $(date) " - Creating variables file for future playbooks"
cat > /home/$SUDOUSER/openshift-container-platform-playbooks/vars.yaml <<EOF
admin_user: $SUDOUSER
master_lb_private_dns: $PRIVATEDNS
EOF

# Setting DOMAIN variable
export DOMAIN=`domainname -d`

# Configure Master cluster address information based on Cluster type (private or public)
echo $(date) " - Create variable for master cluster address based on cluster type"
if [[ $MASTERCLUSTERTYPE == "private" ]]
then
	MASTERCLUSTERADDRESS="openshift_master_cluster_hostname=$MASTER-0
openshift_master_cluster_public_hostname=$PRIVATEDNS
openshift_master_cluster_public_vip=$PRIVATEIP"
else
	MASTERCLUSTERADDRESS="openshift_master_cluster_hostname=$MASTERPUBLICIPHOSTNAME
openshift_master_cluster_public_hostname=$MASTERPUBLICIPHOSTNAME
openshift_master_cluster_public_vip=$MASTERPUBLICIPADDRESS"
fi

# Create Master nodes grouping
echo $(date) " - Creating Master nodes grouping"
for (( c=0; c<$MASTERCOUNT; c++ ))
do
    mastergroup="$mastergroup
$MASTER-$c openshift_node_labels=\"{'region': 'master', 'zone': 'default'}\" openshift_hostname=$MASTER-$c"
done

# Create Infra nodes grouping 
echo $(date) " - Creating Infra nodes grouping"
for (( c=0; c<$INFRACOUNT; c++ ))
do
    infragroup="$infragroup
$INFRA-$c openshift_node_labels=\"{'region': 'infra', 'zone': 'default'}\" openshift_hostname=$INFRA-$c"
done

# Create Nodes grouping
echo $(date) " - Creating Nodes grouping"
for (( c=0; c<$NODECOUNT; c++ ))
do
    nodegroup="$nodegroup
$NODE-$c openshift_node_labels=\"{'region': 'app', 'zone': 'default'}\" openshift_hostname=$NODE-$c"
done

# Create CNS nodes grouping if CNS is enabled
if [ $ENABLECNS == "true" ]
then
    echo $(date) " - Creating CNS nodes grouping"

    for (( c=0; c<$CNSCOUNT; c++ ))
    do
        cnsgroup="$cnsgroup
$CNS-$c openshift_node_labels=\"{'region': 'cns', 'zone': 'default'}\" openshift_hostname=$CNS-$c"
    done
fi

# Setting the default openshift_cloudprovider_kind if Azure enabled
if [[ $MASTERCOUNT != 1 ]]
then
    export HAMODE="openshift_master_cluster_method=native"
fi

# Create Temp Ansible Hosts File
echo $(date) " - Create Ansible Hosts file"

cat > /etc/ansible/hosts <<EOF
[tempnodes]
$mastergroup
$infragroup
$nodegroup
$cnsgroup
EOF

# Run a loop playbook to ensure DNS Hostname resolution is working prior to continuing with script
echo $(date) " - Running DNS Hostname resolution check"
runuser -l $SUDOUSER -c "ansible-playbook ~/openshift-container-platform-playbooks/check-dns-host-name-resolution.yaml"

# Create glusterfs configuration if CNS is enabled
if [ $ENABLECNS == "true" ]
then
    echo $(date) " - Creating glusterfs configuration"

    for (( c=0; c<$CNSCOUNT; c++ ))
    do
        runuser $SUDOUSER -c "ssh-keyscan -H $CNS-$c >> ~/.ssh/known_hosts"
        drive=$(runuser $SUDOUSER -c "ssh $CNS-$c 'sudo /usr/sbin/fdisk -l'" | awk '$1 == "Disk" && $2 ~ /^\// && ! /mapper/ {if (drive) print drive; drive = $2; sub(":", "", drive);} drive && /^\// {drive = ""} END {if (drive) print drive;}')
        drive1=$(echo $drive | cut -d ' ' -f 1)
        drive2=$(echo $drive | cut -d ' ' -f 2)
        drive3=$(echo $drive | cut -d ' ' -f 3)
        cnsglusterinfo="$cnsglusterinfo
$CNS-$c glusterfs_devices='[ \"${drive1}\", \"${drive2}\", \"${drive3}\" ]'"
    done
fi

# Create Ansible Hosts File
echo $(date) " - Create Ansible Hosts file"

cat > /etc/ansible/hosts <<EOF
# Create an OSEv3 group that contains the masters and nodes groups
[OSEv3:children]
masters
nodes
etcd
master0
glusterfs
new_nodes

# Set variables common for all OSEv3 hosts
[OSEv3:vars]
ansible_ssh_user=$SUDOUSER
ansible_become=yes
openshift_install_examples=true
deployment_type=openshift-enterprise
openshift_release=v3.9
openshift_image_tag=v3.9.33
openshift_pkg_version=-3.9.33
docker_udev_workaround=True
openshift_use_dnsmasq=true
openshift_master_default_subdomain=$ROUTING
openshift_override_hostname_check=true
osm_use_cockpit=true
os_sdn_network_plugin_name='redhat/openshift-ovs-multitenant'
openshift_master_api_port=443
openshift_master_console_port=443
osm_default_node_selector='region=app'
openshift_disable_check=memory_availability,docker_image_availability
$CLOUDKIND

# Workaround for docker image failure
# https://access.redhat.com/solutions/3480921
oreg_url=registry.access.redhat.com/openshift3/ose-\${component}:\${version}
openshift_examples_modify_imagestreams=true

# default selectors for router and registry services
openshift_router_selector='region=infra'
openshift_registry_selector='region=infra'
$registrygluster

# Deploy Service Catalog
openshift_enable_service_catalog=false

# Type of clustering being used by OCP
$HAMODE

# Addresses for connecting to the OpenShift master nodes
$MASTERCLUSTERADDRESS

# Enable HTPasswdPasswordIdentityProvider
openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/origin/master/htpasswd'}]

# Setup metrics
openshift_metrics_install_metrics=false
openshift_metrics_start_cluster=true
openshift_metrics_hawkular_nodeselector={"region":"infra"}
openshift_metrics_cassandra_nodeselector={"region":"infra"}
openshift_metrics_heapster_nodeselector={"region":"infra"}

# Setup logging
openshift_logging_install_logging=false
openshift_logging_fluentd_nodeselector={"logging":"true"}
openshift_logging_es_nodeselector={"region":"infra"}
openshift_logging_kibana_nodeselector={"region":"infra"}
openshift_logging_curator_nodeselector={"region":"infra"}
openshift_logging_master_public_url=https://$MASTERPUBLICIPHOSTNAME

# host group for masters
[masters]
$MASTER-[0:${MASTERLOOP}]

# host group for etcd
[etcd]
$MASTER-[0:${MASTERLOOP}]

[master0]
$MASTER-0

# Only populated when CNS is enabled
[glusterfs]
$cnsglusterinfo

# host group for nodes
[nodes]
$mastergroup
$infragroup
$nodegroup
$cnsgroup

# host group for adding new nodes
[new_nodes]
EOF

if [[ $AZURE == "true" ]]
then
    # Create /etc/origin/cloudprovider/azure.conf on all hosts if Azure is enabled
    runuser $SUDOUSER -c "ansible-playbook -f 10 ~/openshift-container-platform-playbooks/create-azure-conf.yaml"
    if [ $? -eq 0 ]
    then
        echo $(date) " - Creation of Cloud Provider Config (azure.conf) completed on all nodes successfully"
    else
        echo $(date) " - Creation of Cloud Provider Config (azure.conf) completed on all nodes failed to complete"
        exit 13
    fi
fi

# Setup NetworkManager to manage eth0
echo $(date) " - Running NetworkManager playbook"
runuser -l $SUDOUSER -c "ansible-playbook -f 10 /usr/share/ansible/openshift-ansible/playbooks/openshift-node/network_manager.yml"

# Configure DNS so it always has the domain name
echo $(date) " - Adding $DOMAIN to search for resolv.conf"
runuser $SUDOUSER -c "ansible all -o -f 10 -b -m lineinfile -a 'dest=/etc/sysconfig/network-scripts/ifcfg-eth0 line=\"DOMAIN=$DOMAIN\"'"

# Configure resolv.conf on all hosts through NetworkManager
echo $(date) " - Restarting NetworkManager"
runuser -l $SUDOUSER -c "ansible all -o -f 10 -b -m service -a \"name=NetworkManager state=restarted\""
echo $(date) " - NetworkManager configuration complete"

# Initiating installation of OpenShift Container Platform using Ansible Playbook
echo $(date) " - Running Prerequisites via Ansible Playbook"
runuser -l $SUDOUSER -c "ansible-playbook -f 10 /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml"
echo $(date) " - Prerequisites check complete"

# Initiating installation of OpenShift Container Platform using Ansible Playbook
echo $(date) " - Installing OpenShift Container Platform via Ansible Playbook"
runuser -l $SUDOUSER -c "ansible-playbook -f 10 /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml"
if [ $? -eq 0 ]
then
    echo $(date) " - OpenShift Cluster installed successfully"
else
    echo $(date) " - OpenShift Cluster failed to install"
    exit 6
fi

echo $(date) " - Modifying sudoers"
sed -i -e "s/Defaults    requiretty/# Defaults    requiretty/" /etc/sudoers
sed -i -e '/Defaults    env_keep += "LC_TIME LC_ALL LANGUAGE LINGUAS _XKB_CHARSET XAUTHORITY"/aDefaults    env_keep += "PATH"' /etc/sudoers

# Deploying Registry
echo $(date) " - Registry automatically deployed to infra nodes"

# Deploying Router
echo $(date) " - Router automaticaly deployed to infra nodes"
echo $(date) " - Re-enabling requiretty"
sed -i -e "s/# Defaults    requiretty/Defaults    requiretty/" /etc/sudoers

# Install OpenShift Atomic Client
cd /root
mkdir .kube
runuser ${SUDOUSER} -c "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SUDOUSER}@${MASTER}-0:~/.kube/config /tmp/kube-config"
cp /tmp/kube-config /root/.kube/config
mkdir /home/${SUDOUSER}/.kube
cp /tmp/kube-config /home/${SUDOUSER}/.kube/config
chown --recursive ${SUDOUSER} /home/${SUDOUSER}/.kube
rm -f /tmp/kube-config
yum -y install atomic-openshift-clients

# Adding user to OpenShift authentication file
echo $(date) " - Adding OpenShift user"
runuser $SUDOUSER -c "ansible-playbook -f 10 ~/openshift-container-platform-playbooks/addocpuser.yaml"

# Assigning cluster admin rights to OpenShift user
echo $(date) " - Assigning cluster admin rights to user"
runuser $SUDOUSER -c "ansible-playbook -f 10 ~/openshift-container-platform-playbooks/assignclusteradminrights.yaml"

# Configure Docker Registry to use Azure Storage Account
echo $(date) " - Configuring Docker Registry to use Azure Storage Account"
runuser $SUDOUSER -c "ansible-playbook -f 10 ~/openshift-container-platform-playbooks/$DOCKERREGISTRYYAML"

# Setting CNS as default storage, only AZURE being true will override it
CNS_DEFAULT_STORAGE=true

# Handling Azure specific storage requirements if it is enabled
if [[ $AZURE == "true" ]]
then
    # Azure wants to be primary, so let us let it be
    CNS_DEFAULT_STORAGE=false

    # Create Storage Classes
    echo $(date) " - Creating Storage Classes"
    runuser $SUDOUSER -c "ansible-playbook -f 10 ~/openshift-container-platform-playbooks/configurestorageclass.yaml"
fi 

# Reconfigure glusterfs storage class
if [ $CNS_DEFAULT_STORAGE == "true" ]
then
    echo $(date) "- Create default glusterfs storage class"
    cat > /home/$SUDOUSER/default-glusterfs-storage.yaml <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  annotations:
    storageclass.kubernetes.io/is-default-class: "$CNS_DEFAULT_STORAGE"
  name: default-glusterfs-storage
parameters:
  resturl: http://heketi-storage-glusterfs.${ROUTING}
  restuser: admin
  secretName: heketi-storage-admin-secret
  secretNamespace: glusterfs
provisioner: kubernetes.io/glusterfs
reclaimPolicy: Delete
EOF
    runuser -l $SUDOUSER -c "oc create -f /home/$SUDOUSER/default-glusterfs-storage.yaml"

    echo $(date) " - Sleep for 60"
    sleep 60
fi

# Ensuring selinux is configured properly
if [ $ENABLECNS == "true" ]
then
    # Setting selinux to allow gluster-fusefs access
    echo $(date) " - Setting selinux to allow gluster-fuse access"
    runuser -l $SUDOUSER -c "ansible all -o -f 10 -b -a 'sudo setsebool -P virt_sandbox_use_fusefs on'" || true
# End of CNS specific section
fi

# Adding some labels back because they go missing
echo $(date) " - Adding api and logging labels"
runuser -l $SUDOUSER -c  "oc label --overwrite nodes $MASTER-0 openshift-infra=apiserver"
runuser -l $SUDOUSER -c  "oc label --overwrite nodes --all logging-infra-fluentd=true logging=true"

# Restarting things so everything is clean before installing anything else
echo $(date) " - Rebooting cluster to complete installation"
runuser -l $SUDOUSER -c "ansible-playbook -f 10 ~/openshift-container-platform-playbooks/reboot-master.yaml"
runuser -l $SUDOUSER -c "ansible-playbook -f 10 ~/openshift-container-platform-playbooks/reboot-nodes.yaml"
sleep 20

# Installing Service Catalog, Ansible Service Broker and Template Service Broker
if [ $AZURE == "true" ] || [ $ENABLECNS == "true" ]
then
    runuser -l $SUDOUSER -c "ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/openshift-service-catalog/config.yml -e openshift_enable_service_catalog=true"
fi

# Configure Metrics
if [ $METRICS == "true" ]
then
    sleep 30
    echo $(date) "- Deploying Metrics"
    if [ $AZURE == "true" ] || [ $ENABLECNS == "true" ]
    then
        runuser -l $SUDOUSER -c "ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/openshift-metrics/config.yml -e openshift_metrics_install_metrics=True -e openshift_metrics_cassandra_storage_type=dynamic"
    else
        runuser -l $SUDOUSER -c "ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/openshift-metrics/config.yml -e openshift_metrics_install_metrics=True"
    fi
    if [ $? -eq 0 ]
    then
        echo $(date) " - Metrics configuration completed successfully"
    else
        echo $(date) " - Metrics configuration failed"
        exit 11
    fi
fi

# Configure Logging

if [ $LOGGING == "true" ]
then
    sleep 60
    echo $(date) "- Deploying Logging"
    if [ $AZURE == "true" ] || [ $ENABLECNS == "true" ]
    then
        runuser -l $SUDOUSER -c "ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/openshift-logging/config.yml -e openshift_logging_install_logging=True -e openshift_logging_es_pvc_dynamic=true"
    else
        runuser -l $SUDOUSER -c "ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/openshift-logging/config.yml -e openshift_logging_install_logging=True"
    fi
    if [ $? -eq 0 ]
    then
        echo $(date) " - Logging configuration completed successfully"
    else
        echo $(date) " - Logging configuration failed"
        exit 12
    fi
fi

# Configure cluster for private masters
if [ $MASTERCLUSTERTYPE == "private" ]
then
	echo $(date) " - Configure cluster for private masters"
	runuser -l $SUDOUSER -c "ansible-playbook -f 10 ~/openshift-container-platform-playbooks/activate-private-lb.yaml"

	echo $(date) " - Delete Master Public IP if cluster is using private masters"
	az login --service-principal -u $AADCLIENTID -p $AADCLIENTSECRET -t $TENANTID
	az account set -s $SUBSCRIPTIONID
	az network public-ip delete -g $RESOURCEGROUP -n $MASTERPIPNAME
fi

# Delete Router / Infra Public IP if cluster is using private router
if [ $ROUTERCLUSTERTYPE == "private" ]
then
	echo $(date) " - Delete Router / Infra Public IP address"
	az login --service-principal -u $AADCLIENTID -p $AADCLIENTSECRET -t $TENANTID
	az account set -s $SUBSCRIPTIONID
	az network public-ip delete -g $RESOURCEGROUP -n $INFRAPIPNAME
fi

# Setting Masters to non-schedulable
echo $(date) " - Setting Masters to non-schedulable"
runuser -l $SUDOUSER -c "ansible-playbook -f 10 ~/openshift-container-platform-playbooks/reset-masters-non-schedulable.yaml"

# Delete yaml files
echo $(date) " - Deleting unecessary files"
rm -rf /home/${SUDOUSER}/openshift-container-platform-playbooks

echo $(date) " - Sleep for 30"
sleep 30

echo $(date) " - Script complete"

