#!/bin/bash

echo $(date) " - Starting Script"

set -e

NODE=$1
SUDOUSER=$2

# Create playbook to update hosts file
# Filename: updatenodehosts.yaml

# Run Ansible Playbook to update Hosts file

echo $(date) " - Updating hosts file"
wget https://raw.githubusercontent.com/microsoft/openshift-container-platform-playbooks/master/updatenodehosts.yaml
ansible-playbook ./updatenodehosts.yaml

# Run Ansible Playbook to add new Node to OpenShift Cluster

echo $(date) " - Adding new Node to OpenShift Cluster via Ansible Playbook"

runuser -l $SUDOUSER -c "ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/openshift-node/scaleup.yml"

echo $(date) " - Script complete"
