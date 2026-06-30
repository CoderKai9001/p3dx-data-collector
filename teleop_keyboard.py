#!/usr/bin/env python3
"""Keyboard teleop for P3DX/RosAria."""

from __future__ import annotations

import argparse
import contextlib
import select
import sys
import termios
import time
import tty

import rospy
from geometry_msgs.msg import Twist


@contextlib.contextmanager
def raw_terminal():
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setcbreak(fd)
        yield
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)


class KeyboardTeleop:
    def __init__(self, args: argparse.Namespace):
        self.args = args
        self.pub = rospy.Publisher(args.cmd_topic, Twist, queue_size=1)
        self.linear = 0.0
        self.angular = 0.0
        self.last_key_time = 0.0

    def read_keys(self) -> None:
        while True:
            ready, _, _ = select.select([sys.stdin], [], [], 0.0)
            if not ready:
                return
            key = sys.stdin.read(1).lower()
            if key in {"w", "i"}:
                self.linear = 1.0
                self.angular = 0.0
            elif key in {"s", "k"}:
                self.linear = -1.0
                self.angular = 0.0
            elif key in {"a", "j"}:
                self.linear = 0.0
                self.angular = 1.0
            elif key in {"d", "l"}:
                self.linear = 0.0
                self.angular = -1.0
            elif key in {" ", "x"}:
                self.linear = 0.0
                self.angular = 0.0
            elif key in {"q", "\x03"}:
                rospy.signal_shutdown("keyboard requested shutdown")
                self.linear = 0.0
                self.angular = 0.0
            else:
                continue
            self.last_key_time = time.time()

    def build_twist(self) -> Twist:
        linear = self.linear
        angular = self.angular
        if time.time() - self.last_key_time > self.args.key_timeout:
            linear = 0.0
            angular = 0.0

        twist = Twist()
        twist.linear.x = linear * self.args.max_v
        twist.angular.z = angular * self.args.max_w
        return twist

    def run(self) -> None:
        rospy.loginfo("Keyboard teleop -> %s", self.args.cmd_topic)
        rospy.loginfo("Keys: w/s forward/back, a/d turn, space stop, q quit")
        rate = rospy.Rate(float(self.args.hz))
        last_log = 0.0
        with raw_terminal():
            try:
                while not rospy.is_shutdown():
                    self.read_keys()
                    twist = self.build_twist()
                    self.pub.publish(twist)
                    now = time.time()
                    if now - last_log > self.args.log_period:
                        rospy.loginfo("keyboard cmd: v=%.3f w=%.3f", twist.linear.x, twist.angular.z)
                        last_log = now
                    rate.sleep()
            finally:
                self.pub.publish(Twist())


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cmd-topic", default="/RosAria/cmd_vel")
    parser.add_argument("--max-v", type=float, default=0.20)
    parser.add_argument("--max-w", type=float, default=0.75)
    parser.add_argument("--hz", type=float, default=20.0)
    parser.add_argument("--key-timeout", type=float, default=0.35)
    parser.add_argument("--log-period", type=float, default=1.0)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    rospy.init_node("plann3r_keyboard_teleop", anonymous=False)
    KeyboardTeleop(args).run()


if __name__ == "__main__":
    main()
