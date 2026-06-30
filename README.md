# p3dx-data-collector

Standalone Docker + tmux setup for collecting RGB/depth/odometry datasets from a P3DX + RealSense robot. No model inference or server connection required.

## Build

```bash
docker build -t p3dx-data-collector .
```

## Record a Dataset (default mode)

```bash
./start_tmux.sh
```

This starts a 5-pane tmux layout inside the container:

- top-left: `roscore`
- top-right: `rosrun rosaria RosAria`
- bottom-right: `roslaunch realsense2_camera rs_camera.launch`
- bottom-left: `record_data.py` writing frames to `data/<DATASET_NAME>/`
- bottom-left split: teleop pane (joystick + keyboard by default)

Data is written to `./data/<DATASET_NAME>/` on the host:

```
data/dataset_20250101_120000/
  images/000000.jpg
  images/000001.jpg
  ...
  depth/000000.png          # only if SAVE_DEPTH=1
  frames.jsonl              # per-frame stamp, odom, cmd
  dataset_meta.json
```

### Common overrides

```bash
DATASET_NAME=lab_run_001 ./start_tmux.sh
RECORD_HZ=3.0 ./start_tmux.sh
SAVE_DEPTH=1 ./start_tmux.sh
RECORD_WIDTH=640 RECORD_HEIGHT=480 ./start_tmux.sh
```

Custom ROS topics:

```bash
RGB_TOPIC=/camera/color/image_raw CMD_TOPIC=/cmd_vel ./start_tmux.sh
```

## Teleop Only (no recording)

```bash
MODE=teleop ./start_tmux.sh
```

Teleop defaults:

- type: `both` (joystick + keyboard in the same pane)
- joystick device: `/dev/input/js0`
- left stick vertical axis `1`: forward/backward
- right stick horizontal axis `3`: turning
- angular sign: inverted (push stick right → robot turns right)
- max speed: `TELEOP_MAX_V=0.20`, `TELEOP_MAX_W=0.75`
- joystick center calibration for `0.75 s` on startup; leave sticks untouched

Keyboard controls:

- `w`/`s`: forward/backward
- `a`/`d`: turn left/right
- `space` or `x`: stop
- `q`: quit

### Teleop overrides

```bash
TELEOP_TYPE=keyboard MODE=teleop ./start_tmux.sh
TELEOP_TYPE=joystick MODE=teleop ./start_tmux.sh
TELEOP_MAX_V=0.30 TELEOP_MAX_W=1.0 MODE=teleop ./start_tmux.sh
TELEOP_LINEAR_AXIS=1 TELEOP_ANGULAR_AXIS=4 MODE=teleop ./start_tmux.sh
TELEOP_INVERT_ANGULAR=0 MODE=teleop ./start_tmux.sh
TELEOP_CALIBRATE_SECONDS=2 TELEOP_DEADZONE=0.15 MODE=teleop ./start_tmux.sh
TELEOP_ENABLE_BUTTON=0 MODE=teleop ./start_tmux.sh   # hold BtnA to enable motion
```

## Session Management

Stop the tmux session and container:

```bash
./start_tmux.sh stop
```

Detach without killing:

```bash
./start_tmux.sh detach
```

Re-attach later:

```bash
tmux attach -t p3dx-data-collector
```

## ROS Driver Overrides

```bash
ROSARIA_CMD="rosrun rosaria RosAria _port:=/dev/ttyUSB1" ./start_tmux.sh
CAMERA_CMD="roslaunch realsense2_camera rs_camera.launch color_width:=640 color_height:=480 color_fps:=30 align_depth:=true" ./start_tmux.sh
```

## Manual Use Inside Container

Record directly:

```bash
python3 /opt/data-collector/record_data.py \
  --out-dir /data/p3dx/lab_run_001 \
  --rgb-topic /camera/color/image_raw \
  --odom-topic /RosAria/pose \
  --cmd-topic /RosAria/cmd_vel \
  --hz 1.5 \
  --width 320 \
  --height 240
```

Teleop directly (joystick + keyboard):

```bash
/opt/data-collector/teleop both \
  --device /dev/input/js0 \
  --cmd-topic /RosAria/cmd_vel \
  --linear-axis 1 \
  --angular-axis 3
```

Keyboard only:

```bash
/opt/data-collector/teleop keyboard --cmd-topic /RosAria/cmd_vel
```

## Safety Notes

- Keep the P3DX e-stop reachable.
- Start with low speed limits: `TELEOP_MAX_V=0.10 TELEOP_MAX_W=0.40`.
- The joystick goes to zero when the device is unplugged or times out.
