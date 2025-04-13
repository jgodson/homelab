# Systemd Service WantedBy Reference

## Overview
The `WantedBy` directive in systemd service files determines when a service will be started automatically. This document explains the different target options and their appropriate usage scenarios.

## Table of Contents
- [Common Targets](#common-targets)
- [Special Purpose Targets](#special-purpose-targets)
- [Multiple Targets](#multiple-targets)
- [Examples](#examples)
- [References](#references)

## Common Targets

### `multi-user.target` 
This means the service will run for all users (though will be run as the `User` and `Group` given). It will be started even without a GUI (graphical user interface).

### `graphical.target` 
This starts in the graphical environment. Also for all users. Includes everything in `multi-user.target` plus graphical login capability.

### `default.target` 
This can be used when you are adding a system service for a specific user instead of a system service (ie: in `~/.config/systemd/username`). The system's default target is typically symlinked to either `multi-user.target` or `graphical.target`.

## Special Purpose Targets

### Emergency and Recovery Targets
- `rescue.target` and `emergency.target`: These start even in minimal environments for system repair or troubleshooting. Run for a single user.

### Shutdown-Related Targets
Less likely to be used, but good to know about as they can be used for graceful shutdowns:

- `reboot.target`: Triggered when rebooting the system.
- `shutdown.target`: Triggered when shutting down the system.

## Multiple Targets

You can specify multiple targets to ensure your service behaves correctly in different scenarios:

```
[Install]
WantedBy=multi-user.target # Run for all users when booted
WantedBy=shutdown.target   # Ensures service stops during shutdown
WantedBy=reboot.target     # Ensures service stops before reboot
```

## Examples

### Basic Service for All Users

```ini
[Unit]
Description=My Background Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/myservice
User=serviceuser
Group=servicegroup
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

### GUI-Dependent Service

```ini
[Unit]
Description=My Desktop Application Service
After=network.target display-manager.service

[Service]
Type=simple
ExecStart=/usr/local/bin/my-desktop-app
User=desktopuser
Environment=DISPLAY=:0

[Install]
WantedBy=graphical.target
```

## References
- [Systemd Documentation](https://www.freedesktop.org/software/systemd/man/systemd.unit.html)
- [Systemd Target Units](https://www.freedesktop.org/software/systemd/man/systemd.target.html)