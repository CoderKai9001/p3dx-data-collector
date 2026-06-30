#!/usr/bin/env bash
# Start or attach to a p3dx-data-collector Docker container, then bring up a
# host-side tmux session whose panes docker-exec into it.
#
# Layout:
#   top-left     : roscore
#   top-right    : rosrun rosaria RosAria
#   bottom-right : roslaunch realsense2_camera rs_camera.launch
#   bottom-left  : record_data.py (record mode) or teleop (teleop mode)
#   bottom-left split: teleop pane added automatically in record mode
#
# Usage:
#   ./start_tmux.sh             # bring up container + tmux, attach (default MODE=record)
#   ./start_tmux.sh detach      # bring up without attaching
#   ./start_tmux.sh stop        # tear down tmux session and container
#
# Common overrides:
#   MODE=record DATASET_NAME=lab_run_001 ./start_tmux.sh
#   MODE=teleop ./start_tmux.sh
#   RECORD_HZ=3.0 ./start_tmux.sh
#   SAVE_DEPTH=1 ./start_tmux.sh

set -euo pipefail

IMAGE="${IMAGE:-p3dx-data-collector}"
CONTAINER="${CONTAINER:-p3dx-data-collector}"
SESSION="${SESSION:-p3dx-data-collector}"
MODE="${MODE:-record}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
DATA_DIR="${DATA_DIR:-$REPO_ROOT/data}"

RGB_TOPIC="${RGB_TOPIC:-/camera/color/image_raw}"
DEPTH_TOPIC="${DEPTH_TOPIC:-/camera/aligned_depth_to_color/image_raw}"
CMD_TOPIC="${CMD_TOPIC:-/RosAria/cmd_vel}"
ODOM_TOPIC="${ODOM_TOPIC:-/RosAria/pose}"
JOY_DEVICE="${JOY_DEVICE:-/dev/input/js0}"

HOST_IP="${HOST_IP:-$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')}"
HOST_IP="${HOST_IP:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
HOST_IP="${HOST_IP:-127.0.0.1}"

ROSCORE_CMD="${ROSCORE_CMD:-roscore}"
ROSARIA_CMD="${ROSARIA_CMD:-rosrun rosaria RosAria _port:=/dev/ttyUSB0}"
CAMERA_CMD="${CAMERA_CMD:-roslaunch realsense2_camera rs_camera.launch color_width:=320 color_height:=240 color_fps:=15 align_depth:=true}"

DATASET_NAME="${DATASET_NAME:-dataset_$(date +%Y%m%d_%H%M%S)}"
RECORD_HZ="${RECORD_HZ:-1.5}"
RECORD_WIDTH="${RECORD_WIDTH:-320}"
RECORD_HEIGHT="${RECORD_HEIGHT:-240}"
JPEG_QUALITY="${JPEG_QUALITY:-95}"
SAVE_DEPTH="${SAVE_DEPTH:-0}"

TELEOP_TYPE="${TELEOP_TYPE:-both}"
TELEOP_MAX_V="${TELEOP_MAX_V:-0.20}"
TELEOP_MAX_W="${TELEOP_MAX_W:-0.75}"
TELEOP_LINEAR_AXIS="${TELEOP_LINEAR_AXIS:-1}"
TELEOP_ANGULAR_AXIS="${TELEOP_ANGULAR_AXIS:-2}"
TELEOP_DEADZONE="${TELEOP_DEADZONE:-0.08}"
TELEOP_ENABLE_BUTTON="${TELEOP_ENABLE_BUTTON:--1}"
TELEOP_CALIBRATE_SECONDS="${TELEOP_CALIBRATE_SECONDS:-0.75}"
TELEOP_INVERT_ANGULAR="${TELEOP_INVERT_ANGULAR:-1}"

ROS_SETUP="source /root/.rosrc"
CONTAINER_REPO="/workspace/p3dx-data-collector"
CONTAINER_DATA="/data/p3dx"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[start_tmux.sh] missing dependency: $1" >&2
    exit 1
  }
}

need docker
need tmux

if [[ "${1:-}" == "stop" ]]; then
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    tmux kill-session -t "$SESSION"
    echo "[start_tmux.sh] killed tmux session $SESSION"
  fi
  if docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    docker rm -f "$CONTAINER" >/dev/null
    echo "[start_tmux.sh] removed container $CONTAINER"
  fi
  exit 0
fi

mkdir -p "$DATA_DIR"

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    echo "[start_tmux.sh] removing stale container $CONTAINER"
    docker rm -f "$CONTAINER" >/dev/null
  fi
  if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "[start_tmux.sh] image '$IMAGE' not found. Build it with:" >&2
    echo "    docker build -t $IMAGE ." >&2
    exit 1
  fi

  echo "[start_tmux.sh] starting container $CONTAINER from $IMAGE"
  echo "[start_tmux.sh] ROS_IP=$HOST_IP"

  docker run -d --rm \
    --name "$CONTAINER" \
    --network host \
    --privileged \
    --uts host \
    -v /dev:/dev \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v "$REPO_ROOT:$CONTAINER_REPO" \
    -v "$DATA_DIR:$CONTAINER_DATA" \
    -e "DISPLAY=${DISPLAY:-:0}" \
    -e "ROS_IP=$HOST_IP" \
    -e "ROS_HOSTNAME=$HOST_IP" \
    -e "ROS_MASTER_URI=http://$HOST_IP:11311" \
    "$IMAGE" sleep infinity >/dev/null

  for _ in $(seq 1 20); do
    if docker exec "$CONTAINER" true >/dev/null 2>&1; then
      break
    fi
    sleep 0.2
  done
else
  echo "[start_tmux.sh] container $CONTAINER already running"
fi

EXEC="docker exec -it \
  -e ROS_IP=$HOST_IP \
  -e ROS_HOSTNAME=$HOST_IP \
  -e ROS_MASTER_URI=http://$HOST_IP:11311 \
  $CONTAINER zsh -c"

# Build teleop command.
if [[ "$TELEOP_TYPE" == "keyboard" ]]; then
  TELEOP_CMD="${TELEOP_CMD:-/opt/data-collector/teleop keyboard --cmd-topic $CMD_TOPIC --max-v $TELEOP_MAX_V --max-w $TELEOP_MAX_W}"
elif [[ "$TELEOP_TYPE" == "joystick" || "$TELEOP_TYPE" == "both" ]]; then
  angular_invert_arg="--invert-angular"
  if [[ "$TELEOP_INVERT_ANGULAR" == "0" || "$TELEOP_INVERT_ANGULAR" == "false" ]]; then
    angular_invert_arg="--no-invert-angular"
  fi
  TELEOP_CMD="${TELEOP_CMD:-/opt/data-collector/teleop $TELEOP_TYPE --device $JOY_DEVICE --cmd-topic $CMD_TOPIC --linear-axis $TELEOP_LINEAR_AXIS --angular-axis $TELEOP_ANGULAR_AXIS --deadzone $TELEOP_DEADZONE --max-v $TELEOP_MAX_V --max-w $TELEOP_MAX_W --enable-button $TELEOP_ENABLE_BUTTON --calibrate-seconds $TELEOP_CALIBRATE_SECONDS $angular_invert_arg}"
else
  echo "[start_tmux.sh] unsupported TELEOP_TYPE=$TELEOP_TYPE. Use joystick, keyboard, or both." >&2
  exit 2
fi

# Build bottom-left pane command.
if [[ "$MODE" == "record" ]]; then
  save_depth_arg=""
  if [[ "$SAVE_DEPTH" != "0" && "$SAVE_DEPTH" != "false" ]]; then
    save_depth_arg="--save-depth --depth-topic $DEPTH_TOPIC"
  fi
  RECORD_CMD="${RECORD_CMD:-python3 /opt/data-collector/record_data.py --out-dir $CONTAINER_DATA/$DATASET_NAME --rgb-topic $RGB_TOPIC --odom-topic $ODOM_TOPIC --cmd-topic $CMD_TOPIC --hz $RECORD_HZ --width $RECORD_WIDTH --height $RECORD_HEIGHT --jpeg-quality $JPEG_QUALITY $save_depth_arg}"
  BOTTOM_LEFT_CMD="$RECORD_CMD"
elif [[ "$MODE" == "teleop" ]]; then
  BOTTOM_LEFT_CMD="$TELEOP_CMD"
else
  echo "[start_tmux.sh] unsupported MODE=$MODE. Use MODE=record or MODE=teleop." >&2
  exit 2
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "[start_tmux.sh] tmux session '$SESSION' already exists; attaching"
  echo "[start_tmux.sh] run '$0 stop' first to apply MODE changes"
else
  P0=$(tmux new-session -d -s "$SESSION" -n robot -x 220 -y 50 -P -F '#{pane_id}')
  tmux send-keys -t "$P0" "$EXEC '$ROS_SETUP && $ROSCORE_CMD'" C-m

  sleep 2

  P1=$(tmux split-window -h -t "$P0" -P -F '#{pane_id}')
  tmux send-keys -t "$P1" "$EXEC '$ROS_SETUP && $ROSARIA_CMD'" C-m

  P2=$(tmux split-window -v -t "$P1" -P -F '#{pane_id}')
  tmux send-keys -t "$P2" "$EXEC '$ROS_SETUP && $CAMERA_CMD'" C-m

  P3=$(tmux split-window -v -t "$P0" -P -F '#{pane_id}')
  tmux send-keys -t "$P3" "$EXEC '$ROS_SETUP && sleep 5 && $BOTTOM_LEFT_CMD'" C-m

  if [[ "$MODE" == "record" ]]; then
    P4=$(tmux split-window -h -t "$P3" -P -F '#{pane_id}')
    tmux send-keys -t "$P4" "$EXEC '$ROS_SETUP && sleep 5 && $TELEOP_CMD'" C-m
  fi

  tmux select-pane -t "$P0"
fi

if [[ "${1:-}" == "detach" ]]; then
  echo "[start_tmux.sh] tmux session running; attach with: tmux attach -t $SESSION"
  echo "[start_tmux.sh] tear down with: $0 stop"
  exit 0
fi

tmux attach -t "$SESSION"
