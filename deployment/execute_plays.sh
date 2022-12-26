#!/usr/bin/env bash
ansible-playbook deployment/deploy_k3s.yml --private-key=environment/skey -i deployment/inventory -vv
ansible-playbook deployment/deploy_jenkins.yml --private-key=environment/skey -i deployment/inventory -vv

