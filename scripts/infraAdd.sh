#!/bin/bash

echo $(date) " - Starting Script"

set -e

INFRA=$1
SUDOUSER=$2

# Create playbook to update hosts file

cat > updatehosts.yaml <<EOF
#!/usr/bin/ansible-playbook

- hosts: localhost
  gather_facts: no
  tasks: 
  - lineinfile:
      dest: /etc/ansible/hosts
      insertafter: '[new_nodes]'
      line: "$INFRA openshift_node_labels=\"{'type': 'infra', 'zone': 'default'}\" openshift_hostname=$INFRA"
      regexp: '^$INFRA '
      state: present
EOF

# Run Ansible Playbook to update Hosts file

echo $(date) " - Updating hosts file"

ansible-playbook ./updatehosts.yaml

# Run Ansible Playbook to add new Infra to OpenShift Cluster

echo $(date) " - Adding new Infra to OpenShift Cluster via Ansible Playbook"

runuser -l $SUDOUSER -c "ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/openshift-node/scaleup.yml"

echo $(date) " - Script complete"