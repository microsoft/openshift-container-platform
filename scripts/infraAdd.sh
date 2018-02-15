#!/bin/bash

echo $(date) " - Starting Script"

set -e

INFRA=$1
SUDOUSER=$2

# Create playbook to update hosts file
# Filename: updateinfrahosts.yaml

# Run Ansible Playbook to update Hosts file

echo $(date) " - Updating hosts file"
wget https://raw.githubusercontent.com/microsoft/openshift-container-platform-playbooks/master/updateinfrahosts.yaml
ansible-playbook ./updateinfrahosts.yaml

# Run Ansible Playbook to add new Infra to OpenShift Cluster

echo $(date) " - Adding new Infra to OpenShift Cluster via Ansible Playbook"

runuser -l $SUDOUSER -c "ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/openshift-node/scaleup.yml"

echo $(date) " - Script complete"
