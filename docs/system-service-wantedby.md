### About WantedBy

Determines when the service will run. More details below:

`multi-user.target`: This means the service will run for all users (though will be run as the `User` and `Group` given). It will be started even without a GUI (graphical user interface).
`graphical.target`: This starts in the graphical environment. Also for all users.
`rescue.target` and `emergency.target`: These start even in minimal environments for system repair or troubleshooting. Runs for a single user.
`default.target`: This can be used when you are adding a system service for a specific user instead of a system service (ie: in `~/.config/systemd/username`).

Less likely to be used, but good to know about as they can be used for graceful shutdowns:
`reboot.target`: Triggered when rebooting the system.
`shutdown.target`: Triggered when shutting down the system.

Note that you can use multiple targets, for example:
```
[Install]
WantedBy=multi-user.target # Run for all users when booted
WantedBy=shutdown.target   # Ensures service stops during shutdown
WantedBy=reboot.target     # Ensures service stops before reboot
```