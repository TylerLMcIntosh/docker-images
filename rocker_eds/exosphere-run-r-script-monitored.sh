#!/bin/bash
# exosphere-run-r-script-monitored.sh
#
# Usage:
# ./exosphere-run-r-script-monitored.sh \
#   <script.R> \
#   [interval_seconds] \
#   [monitor_script] \
#   [log_dir] \
#   [project_subdir] \
#   [dev_dir]
#
# Arguments:
#   $1  R script to run, relative to project_subdir
#   $2  Monitor interval in seconds
#       Default: 10
#   $3  Path to monitor-resources.sh, relative to DEV_DIR
#       Default: docker-images/monitor-resources.sh
#   $4  Directory for log outputs, relative to DEV_DIR
#       Default: compound-disturbance-resilience/logs
#   $5  Project subdirectory within DEV_DIR
#       Default: compound-disturbance-resilience
#   $6  Host development directory mounted into the container
#       Default: /media/volume/working-volume

IMAGE="tylerlmcintosh/rocker_eds:4.6-cran20260501"
CONTAINER_DEV_DIR="/home/rstudio/dev"

if [ -z "$1" ]; then
  echo "Error: Please specify the R script you want to run."
  echo "Usage: ./exosphere-run-r-script-monitored.sh <script.R> [interval_seconds] [monitor_script] [log_dir] [project_subdir] [dev_dir]"
  exit 1
fi

SCRIPT_NAME="$1"
INTERVAL="${2:-10}"
MONITOR_SCRIPT="${3:-docker-images/monitor-resources.sh}"
LOG_DIR="${4:-compound-disturbance-resilience/logs}"
PROJECT_SUBDIR="${5:-compound-disturbance-resilience}"
DEV_DIR="${6:-/media/volume/working-volume}"

# Derive log filename from script name and place it in the log directory.
SCRIPT_BASENAME=$(basename "${SCRIPT_NAME%.R}")
LOG_NAME="${LOG_DIR}/${SCRIPT_BASENAME}_resource_log.csv"

echo "Launching container to run: $SCRIPT_NAME"
echo "Host development directory: $DEV_DIR"
echo "Container mount directory:   $CONTAINER_DEV_DIR"
echo "Monitor script:              $MONITOR_SCRIPT"
echo "Log directory:               $LOG_DIR"
echo "Resource log:                $LOG_NAME"
echo "Monitor interval:            ${INTERVAL}s"
echo "Project subdirectory:        $PROJECT_SUBDIR"
echo "--------------------------------------------------------"

docker run --rm \
  -e USERID="$(id -u)" \
  -e GROUPID="$(id -g)" \
  -v "${DEV_DIR}:${CONTAINER_DEV_DIR}" \
  -w "$CONTAINER_DEV_DIR/$PROJECT_SUBDIR" \
  "$IMAGE" \
  bash -c "
    umask 000

    # Create log directory if it does not exist.
    mkdir -p '$CONTAINER_DEV_DIR/$LOG_DIR'

    # Launch R in the background.
    Rscript '$SCRIPT_NAME' &
    R_PID=\$!
    echo \"R process started with PID \$R_PID\"

    # Launch resource monitor in the background.
    bash '$CONTAINER_DEV_DIR/$MONITOR_SCRIPT' \
      \$R_PID \
      '$CONTAINER_DEV_DIR/$LOG_NAME' \
      '$INTERVAL' &
    MON_PID=\$!

    # Wait for R to finish and capture its exit code.
    wait \$R_PID
    R_EXIT=\$?

    # Give the monitor one final interval, then stop it.
    sleep '$INTERVAL'
    kill \$MON_PID 2>/dev/null

    echo \"R exited with code \$R_EXIT\"
    exit \$R_EXIT
  "