#!/bin/bash
echo $(date) " - Starting Bastion Prep Script"

SELECT=$1
USERNAME_ORG=$2
PASSWORD_ACT_KEY="$3"
POOL_ID=$4

# Remove RHUI

rm -f /etc/yum.repos.d/rh-cloud.repo
sleep 10

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
    --enable="rhel-7-server-ose-3.6-rpms" \
    --enable="rhel-7-fast-datapath-rpms"

# Install base packages and update system to latest packages
echo $(date) " - Install base packages and update system to latest packages"

yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion httpd-tools kexec-tools sos psacct
yum -y update --exclude=WALinuxAgent
yum -y install atomic-openshift-excluder atomic-openshift-docker-excluder
atomic-openshift-excluder unexclude

# Install OpenShift utilities
echo $(date) " - Installing OpenShift utilities"

yum -y install atomic-openshift-utils

# Create playbook to update ansible.cfg file to include path to library

cat > updateansiblecfg.yaml <<EOF
#!/usr/bin/ansible-playbook

- hosts: localhost
  gather_facts: no
  tasks:
  - lineinfile:
      dest: /etc/ansible/ansible.cfg
      regexp: '^library '
      insertafter: '#library        = /usr/share/my_modules/'
      line: 'library = /usr/share/ansible/openshift-ansible/library/'
EOF

# Run Ansible Playbook to update ansible.cfg file

echo $(date) " - Updating ansible.cfg file"

ansible-playbook ./updateansiblecfg.yaml

echo $(date) " - Script Complete"
