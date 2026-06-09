#!/bin/bash
IMAGE="tylerlmcintosh/rocker_eds:4.6-cran20260501"
HOST_PORT=8787
DEV_DIR="/media/volume/working-volume"
CONTAINER_DEV_DIR="/home/rstudio/dev"
PASSWORD="123"
URL="http://localhost:${HOST_PORT}"

# 1. Start the Docker container in the background
echo "Starting Rocker RStudio container..."
docker run -d --rm \
  -p ${HOST_PORT}:8787 \
  -e PASSWORD=$PASSWORD \
  -e USERID=$(id -u) \
  -e GROUPID=$(id -g) \
  -v "${DEV_DIR}:${CONTAINER_DEV_DIR}" \
  -w $CONTAINER_DEV_DIR \
  $IMAGE

# 2. Wait 4 seconds for the RStudio server to spin up
echo "Waiting for container to initialize..."
sleep 4

# 3. Automatically launch the browser tab inside your Web Desktop
echo "Opening RStudio at $URL"
xdg-open "$URL" > /dev/null 2>&1 &