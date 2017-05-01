#!/bin/bash

echo $(date) " - Starting Script"

set -e

NODE=$1
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
      line: "$NODE openshift_node_labels=\"{'type': 'app', 'zone': 'default'}\" openshift_hostname=$NODE"
      regexp: '^$NODE '
      state: present
EOF

# Run Ansible Playbook to update Hosts file

echo $(date) " - Updating hosts file"

ansible-playbook ./updatehosts.yaml

# Run Ansible Playbook to add new Node to OpenShift Cluster

echo $(date) " - Adding new Node to OpenShift Cluster via Ansible Playbook"

runuser -l $SUDOUSER -c "ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/openshift-node/scaleup.yml"

echo $(date) " - Script complete"