#!/bin/bash

# Update the system
sudo apt-get update

# Install Docker dependencies
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update the package list
sudo apt-get update

# Install Docker
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Add the current user to the "docker" group to run Docker commands without sudo
sudo usermod -aG docker $(whoami)

# Validate Docker installation
docker run hello-world

# Install MinIO Client (MC)
curl https://dl.min.io/client/mc/release/linux-amd64/mc --create-dirs -o $HOME/minio-binaries/mc
chmod +x $HOME/minio-binaries/mc
export PATH=$PATH:$HOME/minio-binaries/

# Create directory if it does not exist
if [ ! -d "/mnt/data" ]; then
  sudo mkdir -p /mnt/data
  sudo chown -R $(whoami) /mnt/data
fi

# Pull the latest stable MinIO image
docker pull minio/minio:latest

# Deploy MinIO Single-Node Single-Drive
docker run -d -p 9000:9000 -p 9001:9001 --name minio \
  -e "MINIO_ROOT_USER=minioadmin" \
  -e "MINIO_ROOT_PASSWORD=minioadmin" \
  -e "MINIO_SERVER_URL=http://192.168.34.51:9000" \
  -e "MINIO_BROWSER_REDIRECT_URL=http://192.168.34.51:9001" \
  -v /mnt/data:/data \
  minio/minio server /data --address ":9000" --console-address ":9001"

# Allow incoming connections on port 9000
sudo ufw allow 9000

# MinIO server setup using client
mc config host add myminio http://192.168.34.51:9000 minioadmin minioadmin
mc rm -r --force myminio/manetu
mc mb myminio/manetu
mc anonymous set public myminio/manetu


# Validate MinIO
sleep 10
docker logs minio
