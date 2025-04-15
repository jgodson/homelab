## Getting logs through Promtail

### Automatic way

#### Use the setup script
If you have ssh access, you can create the file locally, then copy it to the remote computer user's home folder (replace inputs as needed, this assumes it is in the directory you are currently in).
`scp ./setup-promtail.sh $USER@$IP:~/`

Alternatively, if you have a text editor you can copy the content from [setup-promtail.sh](setup-promtail.sh) into it and save the file.

Make it executable
`chmox +x setup-promtail.sh`

Run it and promtail should be good to go
`sudo ./setup-promtail.sh`

### Manual way

#### Get the binary

If you don't have `unzip` (ie: `which unzip` returns nothing)
```bash
sudo apt-get install unzip
```

Then download the binary
```bash
wget https://github.com/grafana/loki/releases/latest/download/promtail-linux-amd64.zip

unzip promtail-linux-amd64.zip

chmod +x promtail-linux-amd64

sudo mv promtail-linux-amd64 /usr/local/bin/promtail
```

#### Create the config

Install a text editor if you do not have one:
```bash
sudo apt-get install nano
```

Create the config file:
```bash
sudo nano /usr/local/etc/promtail-config.yml
```

To get logs off the machine itself, paste the contents of [promtail.yml](./promtail.yml). Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`).

#### Start the service

For secruity reasons we should create a new user and add Promtail to the adm group so it can read logs, let's do that first.
```bash
sudo useradd -r -s /bin/false -g adm promtail
```

- The `-r` option creates a system account (no home directory).
- The `-s /bin/false` option disables shell access.
- The `-g adm` option sets the group to `adm` (so it can read all log files).
- The final `promtail` is the user name.


Now we need the service to run in the background and send the logs
```bash
sudo nano /etc/systemd/system/promtail.service
```

Paste the contents of [service](./service) in there. Save and exit.

Here is an explaination of what's in that file.


`Description`: A brief description of what the service runs

`After`: When the serice should start. In this case, we want it to start after the network is available, since it needs that.

`ExecStart`: The command to start Promtail with the specified configuration file (/etc/promtail-config.yml). `-config.expand-env=true` is added to expand the environment variables we use like `${HOSTNAME}`. You can give a variable a default value like so `${VAR:-default_value}`.

`Restart`: Promtail will restart automatically if it crashes.

`User` and `Group`: Runs Promtail under the promtail user and group (you can adjust this if needed).

`LimitNOFILE`: Sets a file descriptor limit for Promtail.

`WantedBy`: Determines when the service will run. See this [document](./../docs/system-service-wantedby.md) for more information.

Since we added a new service first we have to run:
```bash
sudo systemctl daemon-reload
```

Now we can enable and start it:
```bash
sudo systemctl enable promtail
sudo systemctl start promtail
```

Finally, we can check if it's running properly:
```bash
sudo systemctl status promtail
```

You should see output that says `Loaded: loaded` and `Active: active (running)`.

There should now be logs flowing to loki from the host.
 
## Docker logs

### Install the plugin
Install the docker plugin. You can find the latest version [here](https://hub.docker.com/r/grafana/loki-docker-driver/tags), replacing `<latest_version>` with the proper version.
```bash
sudo docker plugin install grafana/loki-docker-driver:<latest_version>-amd64 --alias loki --grant-all-permissions
```

### Configure the plugin options for docker
See [docker-config](./docker-config.md)

#### Updating the plugin
```bash
docker plugin disable loki --force

docker plugin upgrade loki grafana/loki-docker-driver:<latest_version>-amd64 --grant-all-permissions

docker plugin enable loki

sudo systemctl restart docker

# If you are using snap

sudo snap restart docker
```