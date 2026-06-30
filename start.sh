#!/usr/bin/env bash
set -euo pipefail

export ROS_MASTER_URI=${ROS_MASTER_URI:-http://localhost:11311}
export ROS_IP=${ROS_IP:-127.0.0.1}

source /opt/ros/noetic/setup.bash
source /root/catkin_ws/devel/setup.bash

if [[ "$#" -eq 0 ]]; then
  exec zsh
fi

exec "$@"
