#!/bin/bash
echo $(date) " - Starting Script"

SELECT=$1
USERNAME_ORG=$2
PASSWORD_ACT_KEY="$3"
POOL_ID=$4

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
    --enable="rhel-7-server-ose-3.4-rpms"

# Install base packages and update system to latest packages
echo $(date) " - Install base packages and update system to latest packages"

yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion
yum -y update --exclude=WALinuxAgent

# Install Docker 1.12.5
echo $(date) " - Installing Docker 1.12.5"

yum -y install docker-1.12.5
sed -i -e "s#^OPTIONS='--selinux-enabled'#OPTIONS='--selinux-enabled --insecure-registry 172.30.0.0/16'#" /etc/sysconfig/docker

# Enable and start Docker services

systemctl enable docker
systemctl start docker

echo $(date) " - Script Complete"

