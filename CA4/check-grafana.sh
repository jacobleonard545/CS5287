#!/bin/bash
# Quick check of Grafana status on AWS
ssh -i ~/.ssh/ca4-key -o ConnectTimeout=10 ubuntu@3.22.240.63 'sudo docker ps && echo "---" && sudo docker logs grafana --tail 5 && echo "---" && curl -I http://localhost:3000 2>&1 | head -3'
