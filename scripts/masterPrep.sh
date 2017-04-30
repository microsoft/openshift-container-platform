#!/bin/bash
echo $(date) " - Starting Script"

SELECT=$1
USERNAME_ORG=$2
PASSWORD_ACT_KEY="$3"
POOL_ID=$4
STORAGEACCOUNT1=$5
STORAGEACCOUNT2=$6
SUDOUSER=$7

# Register Host with Cloud Access Subscription
echo $(date) " - Register host with Cloud Access Subscription"

if [[ $SELECT == "usernamepassword" ]]
then
   subscription-manager register --username="$USERNAME_ORG" --password="$PASSWORD_ACT_KEY"
else
   subscription-manager register --org="$USERNAME_ORG" --activationkey="$PASSWORD_ACT_KEY"
fi

if [ $? -eq 0 ]
then
   echo "Subscribed successfully"
else
   echo "Incorrect Username and Password or Organization ID and / or Activation Key specified"
   exit 3
fi

subscription-manager attach --pool=$POOL_ID > attach.log
if [ $? -eq 0 ]
then
   echo "Pool attached successfully"
else
   evaluate=$( cut -f 2-5 -d ' ' attach.log )
   if [[ $evaluate == "unit has already had" ]]
      then
         echo "Pool $POOL_ID was already attached and was not attached again."
	  else
         echo "Incorrect Pool ID or no entitlements available"
         exit 4
   fi
fi

# Disable all repositories and enable only the required ones
echo $(date) " - Disabling all repositories and enabling only the required repos"

subscription-manager repos --disable="*"

subscription-manager repos \
    --enable="rhel-7-server-rpms" \
    --enable="rhel-7-server-extras-rpms" \
    --enable="rhel-7-server-ose-3.5-rpms" \
    --enable="rhel-7-fast-datapath-rpms" 

# Install and enable Cockpit
echo $(date) " - Installing and enabling Cockpit"

yum -y install cockpit

systemctl enable cockpit.socket
systemctl start cockpit.socket

# Install base packages and update system to latest packages
echo $(date) " - Install base packages and update system to latest packages"

yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion httpd-tools
yum -y update --exclude=WALinuxAgent
yum install atomic-openshift-excluder atomic-openshift-docker-excluder
atomic-openshift-excluder unexclude

# Install OpenShift utilities
echo $(date) " - Installing OpenShift utilities"

yum -y install atomic-openshift-utils

# Install Docker 1.12.x
echo $(date) " - Installing Docker 1.12.x"

yum -y install docker
sed -i -e "s#^OPTIONS='--selinux-enabled'#OPTIONS='--selinux-enabled --insecure-registry 172.30.0.0/16'#" /etc/sysconfig/docker

# Create thin pool logical volume for Docker
echo $(date) " - Creating thin pool logical volume for Docker and staring service"

DOCKERVG=$( parted -m /dev/sda print all 2>/dev/null | grep unknown | grep /dev/sd | cut -d':' -f1 )

echo "DEVS=${DOCKERVG}" >> /etc/sysconfig/docker-storage-setup
echo "VG=docker-vg" >> /etc/sysconfig/docker-storage-setup
docker-storage-setup
if [ $? -eq 0 ]
then
   echo "Docker thin pool logical volume created successfully"
else
   echo "Error creating logical volume for Docker"
   exit 5
fi

# Enable and start Docker services

systemctl enable docker
systemctl start docker

# Prereqs for NFS, if we're $MASTER-0
# Create a lv with what's left in the docker-vg VG, which depends on disk size defined (100G disk = 60G free)

if hostname -f|grep -- "-0" >/dev/null
then
   echo $(date) " - We are on master-0 ($(hostname)): Setting up NFS server for persistent storage"
   yum -y install nfs-utils
   VGFREESPACE=$(vgs|grep docker-vg|awk '{ print $7 }'|sed 's/.00g/G/')
   lvcreate -n lv_nfs -L+$VGFREESPACE docker-vg
   mkfs.xfs /dev/mapper/docker--vg-lv_nfs
   echo "/dev/mapper/docker--vg-lv_nfs /exports xfs defaults 0 0" >>/etc/fstab
   mkdir /exports
   mount -a
   if [ "$?" -eq 0 ]
   then
      echo "$(date) Successfully setup NFS."
   else
      echo "$(date) Failed to mount filesystem which is to host the NFS share."
      exit 6
   fi
   
   for item in registry metrics jenkins
   do 
      mkdir -p /exports/$item
   done
   
   chown nfsnobody:nfsnobody /exports -R
   chmod a+rwx /exports -R  
fi

# Create Storage Class yml files on MASTER-0

if hostname -f|grep -- "-0" >/dev/null
then
cat <<EOF > /home/${SUDOUSER}/scgeneric1.yml
kind: StorageClass
apiVersion: storage.k8s.io/v1beta1
metadata:
  name: generic
  annotations:
    storageclass.beta.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/azure-disk
parameters:
  storageAccount: ${STORAGEACCOUNT1}
EOF

cat <<EOF > /home/${SUDOUSER}/scgeneric2.yml
kind: StorageClass
apiVersion: storage.k8s.io/v1beta1
metadata:
  name: slow
provisioner: kubernetes.io/azure-disk
parameters:
  storageAccount: ${STORAGEACCOUNT2}
EOF
fi


echo $(date) " - Script Complete"
