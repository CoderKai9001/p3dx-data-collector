# p3dx-data-collector

Collect RGB + odometry datasets from a P3DX robot with a RealSense camera.
Teleop is built in — drive the robot while frames are recorded automatically.

---

## One-time setup

**1. Build the Docker image** (run once, or after any file changes):

```bash
cd /path/to/p3dx-data-collector
docker build -t p3dx-data-collector .
```

**2. Plug in the robot and camera** via USB before starting.

---

## Recording a dataset

**1. Start everything:**

```bash
./start_tmux.sh
```

This opens a tmux window with four panes that start automatically:
- `roscore`
- P3DX driver (`RosAria`)
- RealSense camera
- Data recorder + teleop side-by-side

Frames are saved to `./data/dataset_<timestamp>/` on your machine.

**2. Drive the robot** using the teleop pane (bottom-left split):

| Key | Action |
|-----|--------|
| `w` | Forward |
| `s` | Backward |
| `a` | Turn left |
| `d` | Turn right |
| `space` | Stop |
| `q` | Quit teleop |

If you have a joystick/gamepad plugged in, it works in the same pane — left stick for forward/back, right stick for turning.

**3. Stop recording** — press `Ctrl-C` in the recorder pane, or stop everything:

```bash
./start_tmux.sh stop
```

Dataset output:

```
data/dataset_20250101_120000/
  images/000000.jpg
  images/000001.jpg
  ...
  frames.jsonl        ← per-frame timestamp, odometry, velocity command
  dataset_meta.json   ← recording parameters
```

### Options

Give the dataset a name:
```bash
DATASET_NAME=lab_corridor_001 ./start_tmux.sh
```

Change recording rate (default 1.5 Hz):
```bash
RECORD_HZ=3.0 ./start_tmux.sh
```

Also record depth images:
```bash
SAVE_DEPTH=1 ./start_tmux.sh
```

Higher resolution (default 320×240):
```bash
RECORD_WIDTH=640 RECORD_HEIGHT=480 ./start_tmux.sh
```

---

## Teleop only (no recording)

**1. Start in teleop mode:**

```bash
MODE=teleop ./start_tmux.sh
```

Same four panes open but only the teleop pane is in the bottom-left — no recorder.

**2. Drive** with the keyboard or joystick as above.

**3. Stop:**

```bash
./start_tmux.sh stop
```

### Options

Keyboard only:
```bash
TELEOP_TYPE=keyboard MODE=teleop ./start_tmux.sh
```

Joystick only:
```bash
TELEOP_TYPE=joystick MODE=teleop ./start_tmux.sh
```

Increase speed limits (defaults: 0.20 m/s, 0.75 rad/s):
```bash
TELEOP_MAX_V=0.30 TELEOP_MAX_W=1.0 MODE=teleop ./start_tmux.sh
```

If the robot turns at rest when you start, the joystick is drifting. Increase calibration time (leave sticks untouched for the first 2 seconds):
```bash
TELEOP_CALIBRATE_SECONDS=2 MODE=teleop ./start_tmux.sh
```

If turning is reversed on your controller:
```bash
TELEOP_INVERT_ANGULAR=0 MODE=teleop ./start_tmux.sh
```

If your controller uses different axes (check with `jstest /dev/input/js0`):
```bash
TELEOP_LINEAR_AXIS=1 TELEOP_ANGULAR_AXIS=4 MODE=teleop ./start_tmux.sh
```

Require holding a button to enable motion (e.g. BtnA = button 0 on Xbox pad):
```bash
TELEOP_ENABLE_BUTTON=0 MODE=teleop ./start_tmux.sh
```

---

## Session management

| Command | What it does |
|---------|-------------|
| `./start_tmux.sh` | Start everything and attach |
| `./start_tmux.sh detach` | Start everything but don't attach |
| `tmux attach -t p3dx-data-collector` | Re-attach to a running session |
| `./start_tmux.sh stop` | Kill the tmux session and container |

To apply any `MODE` or setting change, stop first then re-run:
```bash
./start_tmux.sh stop
MODE=teleop ./start_tmux.sh
```

---

## Notes

**Robot port** — the default serial port is `/dev/ttyUSB0`. If the driver fails to connect, check which port the robot is on (`ls /dev/ttyUSB*`) and override:
```bash
ROSARIA_CMD="rosrun rosaria RosAria _port:=/dev/ttyUSB1" ./start_tmux.sh
```

**Camera settings** — to change resolution or frame rate:
```bash
CAMERA_CMD="roslaunch realsense2_camera rs_camera.launch color_width:=640 color_height:=480 color_fps:=30 align_depth:=true" ./start_tmux.sh
```

**Joystick calibration** — at startup the teleop reads the stick positions for 0.75 s to learn the center. Leave all sticks untouched until you see the "Calibrating" message disappear.

**Safety** — keep the P3DX e-stop within reach. Start with the default (slow) speed limits before increasing them.
