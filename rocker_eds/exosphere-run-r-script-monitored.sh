#!/bin/bash
# exosphere-run-r-script-monitored.sh
#
# Usage:
#   ./exosphere-run-r-script-monitored.sh --script <script.R> [options]
#
# Required:
#   --script <path>             R script relative to project_subdir
#
# Optional:
#   --interval <seconds>        Monitoring interval
#                               Default: 10
#   --monitor-script <path>     Monitor script relative to dev_dir
#                               Default: docker-images/monitor-resources.sh
#   --log-dir <path>            Log directory relative to dev_dir
#                               Default: compound-disturbance-resilience/logs
#   --project-subdir <path>     Project directory relative to dev_dir
#                               Default: compound-disturbance-resilience
#   --dev-dir <path>            Host directory mounted into the container
#                               Default: /media/volume/working-volume
#   --help                      Display this help message

IMAGE="tylerlmcintosh/rocker_eds:4.6-cran20260501"
CONTAINER_DEV_DIR="/home/rstudio/dev"

# Defaults
SCRIPT_NAME=""
INTERVAL=10
MONITOR_SCRIPT="docker-images/monitor-resources.sh"
LOG_DIR="compound-disturbance-resilience/logs"
PROJECT_SUBDIR="compound-disturbance-resilience"
DEV_DIR="/media/volume/working-volume"

print_usage() {
  sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'
}

# Parse named arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --script)
      [[ $# -ge 2 ]] || {
        echo "Error: --script requires a value." >&2
        exit 1
      }
      SCRIPT_NAME="$2"
      shift 2
      ;;

    --interval)
      [[ $# -ge 2 ]] || {
        echo "Error: --interval requires a value." >&2
        exit 1
      }
      INTERVAL="$2"
      shift 2
      ;;

    --monitor-script)
      [[ $# -ge 2 ]] || {
        echo "Error: --monitor-script requires a value." >&2
        exit 1
      }
      MONITOR_SCRIPT="$2"
      shift 2
      ;;

    --log-dir)
      [[ $# -ge 2 ]] || {
        echo "Error: --log-dir requires a value." >&2
        exit 1
      }
      LOG_DIR="$2"
      shift 2
      ;;

    --project-subdir)
      [[ $# -ge 2 ]] || {
        echo "Error: --project-subdir requires a value." >&2
        exit 1
      }
      PROJECT_SUBDIR="$2"
      shift 2
      ;;

    --dev-dir)
      [[ $# -ge 2 ]] || {
        echo "Error: --dev-dir requires a value." >&2
        exit 1
      }
      DEV_DIR="$2"
      shift 2
      ;;

    --help|-h)
      print_usage
      exit 0
      ;;

    *)
      echo "Error: Unknown argument: $1" >&2
      echo "Run '$0 --help' for usage." >&2
      exit 1
      ;;
  esac
done

if [[ -z "$SCRIPT_NAME" ]]; then
  echo "Error: --script is required." >&2
  echo "Run '$0 --help' for usage." >&2
  exit 1
fi

# Basic validation
if ! [[ "$INTERVAL" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: --interval must be a positive integer." >&2
  exit 1
fi

if [[ ! -d "$DEV_DIR" ]]; then
  echo "Error: Development directory does not exist: $DEV_DIR" >&2
  exit 1
fi

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
  -w "${CONTAINER_DEV_DIR}/${PROJECT_SUBDIR}" \
  "$IMAGE" \
  bash -c "
    umask 000

    mkdir -p '${CONTAINER_DEV_DIR}/${LOG_DIR}'

    Rscript '${SCRIPT_NAME}' &
    R_PID=\$!
    echo \"R process started with PID \$R_PID\"

    bash '${CONTAINER_DEV_DIR}/${MONITOR_SCRIPT}' \
      \$R_PID \
      '${CONTAINER_DEV_DIR}/${LOG_NAME}' \
      '${INTERVAL}' &
    MON_PID=\$!

    wait \$R_PID
    R_EXIT=\$?

    sleep '${INTERVAL}'
    kill \$MON_PID 2>/dev/null
    wait \$MON_PID 2>/dev/null

    echo \"R exited with code \$R_EXIT\"
    exit \$R_EXIT
  "