FROM ros:noetic-ros-base

ENV DEBIAN_FRONTEND=noninteractive
ENV DATA_COLLECTOR_HOME=/opt/data-collector
ENV DATA_DIR=/data/p3dx

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    git \
    libaria-dev \
    python3-catkin-tools \
    python3-cv-bridge \
    python3-empy \
    python3-opencv \
    python3-pip \
    python3-rosdep \
    ros-noetic-diagnostic-updater \
    ros-noetic-geometry-msgs \
    ros-noetic-image-transport \
    ros-noetic-nav-msgs \
    ros-noetic-realsense2-camera \
    ros-noetic-realsense2-description \
    ros-noetic-roslaunch \
    ros-noetic-sensor-msgs \
    ros-noetic-tf \
    ros-noetic-tf2-ros \
    tmux \
    udev \
    zsh \
    && rm -rf /var/lib/apt/lists/*

# RosAria is not shipped in the default Noetic apt repos, so build it from source.
RUN mkdir -p /root/catkin_ws/src && \
    cd /root/catkin_ws/src && \
    git clone --depth=1 https://github.com/amor-ros-pkg/rosaria.git && \
    cd /root/catkin_ws && \
    /bin/bash -c "source /opt/ros/noetic/setup.bash && catkin_make -DCMAKE_BUILD_TYPE=Release"

RUN pip3 install --no-cache-dir \
    numpy \
    pillow \
    requests

RUN printf '%s\n' \
    'source /opt/ros/noetic/setup.zsh' \
    'source /root/catkin_ws/devel/setup.zsh' \
    > /root/.rosrc

COPY dotfiles/.zshrc /root/.zshrc
COPY dotfiles/.p10k.zsh /root/.p10k.zsh
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /root/powerlevel10k || true
RUN printf '%s\n' \
    '' \
    'source /root/.rosrc' \
    'cd /workspace/p3dx-data-collector 2>/dev/null || true' \
    >> /root/.zshrc

WORKDIR ${DATA_COLLECTOR_HOME}
COPY start.sh ${DATA_COLLECTOR_HOME}/start.sh
COPY record_data.py ${DATA_COLLECTOR_HOME}/record_data.py
COPY teleop ${DATA_COLLECTOR_HOME}/teleop
COPY teleop_joystick.py ${DATA_COLLECTOR_HOME}/teleop_joystick.py
COPY teleop_keyboard.py ${DATA_COLLECTOR_HOME}/teleop_keyboard.py
RUN chmod +x ${DATA_COLLECTOR_HOME}/*.py ${DATA_COLLECTOR_HOME}/*.sh ${DATA_COLLECTOR_HOME}/teleop

WORKDIR /workspace/p3dx-data-collector
ENTRYPOINT ["/opt/data-collector/start.sh"]
CMD ["zsh"]
