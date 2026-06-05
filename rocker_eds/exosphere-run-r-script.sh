# If no permissions:
# chmod +x run_r_script.sh

# Usage
# ./run_r_script.sh analysis.R

#!/bin/bash
IMAGE="tylerlmcintosh/rocker_eds:4.6-cran20260501"
DEV_DIR="/media/volume/test-volume"
CONTAINER_DEV_DIR="/home/rstudio/dev"

# 1. Check if the user provided a script name argument
if [ -z "$1" ]; then
    echo "Error: Please specify the R script you want to run."
    echo "Usage: ./run_r_script.sh your_script.R"
    exit 1
fi

SCRIPT_NAME="$1"

echo "Launching container to run script: $SCRIPT_NAME"
echo "--------------------------------------------------------"

# 2. Run Docker, map the volume, and execute Rscript
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "${DEV_DIR}:${CONTAINER_DEV_DIR}" \
  -w $CONTAINER_DEV_DIR \
  $IMAGE \
  Rscript "$SCRIPT_NAME"
