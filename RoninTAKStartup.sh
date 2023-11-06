#!/bin/bash

# Set your JFrog Artifactory URL and repository name
ARTIFACTORY_URL="https://ronintak.jfrog.io"
REPOSITORY="tak-registry-docker"

# Define the images and tags you want to pull
IMAGE_1_NAME="takserver-db"
IMAGE_1_TAG="4.8-RELEASE-56"

IMAGE_2_NAME="takserver"
IMAGE_2_TAG="4.8-RELEASE-56"

# Function to pull a Docker image
pull_image() {
    local image_name="$1"
    local image_tag="$2"
    local docker_image="$ARTIFACTORY_URL/$REPOSITORY/$image_name:$image_tag"
    
    docker pull "$docker_image"

    # Check if the pull was successful
    if [ $? -eq 0 ]; then
        echo "Docker image pulled successfully: $docker_image"
    else
        echo "Failed to pull Docker image: $docker_image"
        exit 1
    fi
}

# Pull the first Docker image
pull_image "$IMAGE_1_NAME" "$IMAGE_1_TAG"

# Pull the second Docker image
pull_image "$IMAGE_2_NAME" "$IMAGE_2_TAG"

# Get the version from version.txt file
VERSION=$(cat tak/version.txt)

# Run the first Docker container
docker run -d -v $(pwd)/tak:/opt/tak:z -it -p 5432:5432 --network "takserver-$VERSION" --network-alias tak-database --name "takserver-db-$VERSION" tak-server-db:4.8-RELEASE-56

# Check if the first command was successful
if [ $? -eq 0 ]; then
    echo "First Docker command was successful."
    
    # Run the second Docker container
    docker run -d -v $(pwd)/tak:/opt/tak:z -it -p 8080:8080 -p 8443:8443 -p 8444:8444 -p 8446:8446 -p 8087:8087/tcp -p 8087:8087/udp -p 8088:8088 -p 9000:9000 -p 9001:9001 --network "takserver-$VERSION" --name "takserver-$VERSION" takserver:4.8-RELEASE-56

    # Check if the second command was successful
    if [ $? -eq 0 ]; then
        echo "Second Docker command was successful."
    else
        echo "Failed to run the second Docker command."
        exit 1
    fi
else
    echo "Failed to run the first Docker command."
    exit 1
fi

# Generate root CA
docker exec -it takserver-"$VERSION" bash -c "cd /opt/tak/certs && ./makeRootCa.sh"

# Get the desired takserver certificate name from the user
read -p "Enter the new server certificate name (e.g., tcd#takserver): " new_cert_name

# Run the Docker command with the updated certificate name
docker exec -it takserver-"$VERSION" bash -c "cd /opt/tak/certs && ./makeCert.sh server $new_cert_name"

# Get the desired client certificate name from the user
read -p "Enter the new client certificate name (e.g., tcd#user#): " new_client_cert_name

# Run the Docker command with the updated user certificate name
docker exec -it takserver-"$VERSION" bash -c "cd /opt/tak/certs && ./makeCert.sh client $new_client_cert_name"

# Get the desired admin certificate name from the user
read -p "Enter the new client certificate name (e.g., tcd#user#): " new_admin_cert_name

# Run the Docker command to create the client certificate
docker exec -it takserver-"$VERSION" bash -c "cd /opt/tak/certs && ./makeCert.sh client $new_admin_cert_name"

# Run the script to modify the certificate with the updated name
docker exec takserver-"$VERSION" bash -c "cd /opt/tak/ && java -jar utils/UserManager.jar certmod -A certs/files/$new_admin_cert_name.pem"

# Prompt the user to restart the server when they are ready
read -p "Certificate updated. Please restart the server when you are ready.