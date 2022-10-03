#!/bin/bash
sudo apt-get update -y
sudo curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
usermod -aG docker ubuntu
newgrp docker
