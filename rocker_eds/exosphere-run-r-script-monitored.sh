#!/bin/bash
# run_r_script_monitored.sh
# Usage: ./run_r_script_monitored.sh <script.R> [interval_seconds] [monitor_script] [log_dir]
#
# Arguments:
#   $1  R script to run (relative to DEV_DIR)
#   $2  Monitor interval in seconds (default: 10)
#   $3  Path to monitor_resources.sh (relative to DEV_DIR, default: monitor_resources.sh)
#   $4  Directory for log outputs (relative to DEV_DIR, default: logs)

IMAGE="tylerlmcintosh/rocker_eds:4.6-cran20260501"
DEV_DIR="/media/volume/working-volume"
CONTAINER_DEV_DIR="/home/rstudio/dev"

if [ -z "$1" ]; then
  echo "Error: Please specify the R script you want to run."
  echo "Usage: ./run_r_script_monitored.sh <script.R> [interval_seconds] [monitor_script] [log_dir]"
  exit 1
fi

SCRIPT_NAME="$1"
INTERVAL=${2:-10}
MONITOR_SCRIPT=${3:-docker-images/rocker_eds/monitor-resources.sh}
LOG_DIR=${4:-logs}

# derive log filename from script name, place in log dir
SCRIPT_BASENAME=$(basename "${SCRIPT_NAME%.R}")
LOG_NAME="${LOG_DIR}/${SCRIPT_BASENAME}_resource_log.csv"

echo "Launching container to run: $SCRIPT_NAME"
echo "Monitor script:             $MONITOR_SCRIPT"
echo "Log directory:              $LOG_DIR"
echo "Resource log:               $LOG_NAME"
echo "Monitor interval:           ${INTERVAL}s"
echo "--------------------------------------------------------"

docker run --rm \
  -e USERID=$(id -u) \
  -e GROUPID=$(id -g) \
  -v "${DEV_DIR}:${CONTAINER_DEV_DIR}" \
  -w "$CONTAINER_DEV_DIR" \
  $IMAGE \
  bash -c "
    # create log directory if it doesn't exist
    mkdir -p '$LOG_DIR'

    # launch R in background
    Rscript '$SCRIPT_NAME' &
    R_PID=\$!
    echo \"R process started with PID \$R_PID\"

    # launch monitor in background
    bash '$MONITOR_SCRIPT' \$R_PID '$LOG_NAME' '$INTERVAL' &
    MON_PID=\$!

    # wait for R to finish and capture its exit code
    wait \$R_PID
    R_EXIT=\$?

    # give monitor one last write then stop it
    sleep '$INTERVAL'
    kill \$MON_PID 2>/dev/null

    echo \"R exited with code \$R_EXIT\"
    exit \$R_EXIT
  "