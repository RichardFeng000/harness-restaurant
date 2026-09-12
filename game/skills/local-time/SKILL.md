---
name: local-time
description: Read the current user's device-local date, time, and UTC offset for the hamster timekeeper and synchronize the restaurant wall clock. Use when the hamster needs to report or correct the current local time.
---

# Local time

This project-local skill is preassigned to the hamster (`hamster`). One manager-controlled authorization allows an employee to install and use it. Its runnable helper is [scripts/read_local_time.gd](scripts/read_local_time.gd); [manifest.json](manifest.json) declares the default binding and required `device.time.read` capability.

Invoke it through `HarnessApi.skills.execute("hamster", "local-time")`. The runtime checks the employee's authorization, installation and enabled state before running the helper. Manager authorization does not install or enable tools. New installations remain paused until the employee enables them; the hamster's preinstalled startup assignment remains enabled by default. Revoking authorization immediately pauses the skill; granting it again does not resume execution. A successful result contains local `hour`, `minute`, `second`, `date`, `time`, `timezone`, and `utc_offset_minutes` in `data`. Pass that sample to the wall clock's `apply_time` method. A failed result must leave the last clock position unchanged and display the error.

Read the clock of the device running the restaurant. Native Godot uses the operating system's local time; the Web helper uses the browser's local `Date` and time zone. Do not substitute a model-generated timestamp, build time, server timezone, or previously saved time.

While this skill is installed and enabled, sample once per second and on return to the application. Read a fresh sample after sleep or clock changes; do not add gameplay elapsed time. Pausing the restaurant does not pause real-world time. Uninstalling or disabling the skill stops sampling. Installation and enabled state are saved with the restaurant's progress, but time samples are never restored as the current time.
