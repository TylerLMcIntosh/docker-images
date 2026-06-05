#!/bin/bash
IMAGE="tylerlmcintosh/rocker_eds:4.6-cran20260501"
DEV_DIR="/media/volume/test-volume"
CONTAINER_DEV_DIR="/home/rstudio/dev"

echo "Starting interactive R session on your Exosphere volume..."
echo "Type 'q()' to exit R when finished."
echo "--------------------------------------------------------"

# Run Docker interactively (-it), mounting the volume, and launching 'R'
docker run --rm -it \
  --user "$(id -u):$(id -g)" \
  -v "${DEV_DIR}:${CONTAINER_DEV_DIR}" \
  -w $CONTAINER_DEV_DIR \
  $IMAGE \
  R
