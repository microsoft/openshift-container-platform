# WIP: Ansible playbooks to deploy OpenShift

This directory contains a work in progress set of ansible playbooks and supporting files for deploying OpenShift in Azure.  In it’s current state, it is very raw and may have issues until we clean everything up.  We welcome any and all assistance on making this work just as good (or better) than what we have created with the original ARM templates.

## Requirements

Make sure you have ansible 2.6.1, and make sure you have azure cli 2.41. Also, make sure you update azure for pip, especially if you run into not found element errors.

## TL;DR

Install the requirements:

```bash
subscription-manager repo —enable=rhel-7-server-ansible-2.6-rpms && yum install ansible
```
Copy `vars.example.yml` to vars.yml and edit the file to update all the variables with your information.

Copy `ansible.cfg.backup` to ansible.cfg and edit the file to update all the variables with your information.

Run the playbook:

```bash
ansible-playbook playbooks/create.yml -e @vars.yml
```
