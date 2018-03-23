#!/bin/bash
echo $(date) " - Starting Infra / Node Prep Script"

USERNAME_ORG=$1
PASSWORD_ACT_KEY="$2"
POOL_ID=$3

# Remove RHUI

rm -f /etc/yum.repos.d/rh-cloud.repo
sleep 10

# Register Host with Cloud Access Subscription
echo $(date) " - Register host with Cloud Access Subscription"

subscription-manager register --username="$USERNAME_ORG" --password="$PASSWORD_ACT_KEY" || subscription-manager register --activationkey="$PASSWORD_ACT_KEY" --org="$USERNAME_ORG"

if [ $? -eq 0 ]
then
   echo "Subscribed successfully"
else
   echo "Incorrect Username / Password or Organization ID / Activation Key specified"
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
    --enable="rhel-7-server-ose-3.7-rpms" \
    --enable="rhel-7-fast-datapath-rpms" \
    --enable="rh-gluster-3-for-rhel-7-server-rpms"

# Install base packages and update system to latest packages
echo $(date) " - Install base packages and update system to latest packages"

yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion kexec-tools sos psacct
yum -y install cloud-utils-growpart.noarch
yum -y update --exclude=WALinuxAgent
yum -y install atomic-openshift-excluder atomic-openshift-docker-excluder

atomic-openshift-excluder unexclude

# Grow Root File System
echo $(date) " - Grow Root FS"

rootdev=`findmnt --target / -o SOURCE -n`
rootdrivename=`lsblk -no pkname $rootdev`
rootdrive="/dev/"$rootdrivename
majorminor=`lsblk  $rootdev -o MAJ:MIN | tail -1`
part_number=${majorminor#*:}

growpart $rootdrive $part_number -u on
xfs_growfs $rootdev

# Install Docker 1.12.x
echo $(date) " - Installing Docker 1.12.x"
## Pinning to 1.12.6 to support OCP v3.7 for the same and not use 1.13.x as default##
## From @vincepower pull #50 on master ##
#yum -y install docker
yum -y install docker-1.12.6
yum -y install yum-plugin-versionlock
yum versionlock docker-client-1.12.6 docker-common-1.12.6 docker-rhel-push-plugin-1.12.6 docker-1.12.6
## End Pinning
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
#gluster pre-reqs for all
yum install -y iscsi-initiator-utils device-mapper-multipath
mpathconf --enable
## Placeholder for /etc/multipath.conf entry and systemctl restart multipathd
modprobe dm_thin_pool
modprobe dm_multipath
modprobe target_core_user
modprobe dm_mirror
modprobe dm_snapshot
echo "dm_thin_pool" > /etc/modules-load.d/dm_thin_pool.conf
echo "dm_multipath" > /etc/modules-load.d/dm_multipath.conf
echo "target_core_user" > /etc/modules-load.d/target_core_user.conf
echo "dm_mirror" > /etc/modules-load.d/dm_mirror.conf
echo "dm_snapshot" > /etc/modules-load.d/dm_snapshot.conf
systemctl add-wants multi-user rpcbind.service
systemctl enable rpcbind.service
systemctl start rpcbind.service
yum install -y redhat-storage-server
yum install -y gluster-block
systemctl start sshd
systemctl enable sshd
systemctl start glusterd
systemctl enable glusterd
systemctl start gluster-blockd
systemctl enable gluster-blockd
echo $(date) " - Script Complete"

