#!/usr/bin/bash

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root." 1>&2
  exit 1
fi

if ! command -v unzip &> /dev/null; then
    echo "unzip command not found. Please install it first."
    exit 1
fi

echo 'downloading latest promtail-linux-amd64 from github.'
wget https://github.com/grafana/loki/releases/latest/download/promtail-linux-amd64.zip

unzip promtail-linux-amd64.zip -d /usr/local/bin/
ln -s /usr/local/bin/promtail-linux-amd64 /usr/local/bin/promtail

echo 'cleanup old zip file.'
rm promtail-linux-amd64.zip

echo 'create promtail user and add to adm group'
sudo useradd -r -s /bin/false -g adm promtail

echo 'creating local configuration file in /usr/local/etc/'
cat <<EOF > /usr/local/etc/promtail-config.yml
server:
  disable: true
  http_listen_port: 9080

clients:
  - url: http://192.168.1.4:8090/loki/api/v1/push
    tenant_id: home

positions:
  filename: /tmp/positions.yaml

scrape_configs:
  - job_name: systemd-journal
    journal:
      max_age: 12h
      labels:
        job: systemd
    relabel_configs:
      - source_labels: ["__journal__systemd_unit"]
        target_label: unit
      - source_labels: ["__journal__hostname"]
        target_label: host
      - source_labels: ["__journal_priority_keyword"]
        target_label: level
      - source_labels: ["__journal_syslog_identifier"]
        target_label: syslog_identifier

  - job_name: syslog
    static_configs:
      - targets:
          - localhost
        labels:
          job: syslog
          __path__: "/var/log/*.log"
          host: ${HOSTNAME}
EOF

echo 'creating promtail service file'
cat <<EOF > /etc/systemd/system/promtail.service
[Unit]
Description=Promtail service
After=network.target

[Service]
ExecStart=/usr/local/bin/promtail -config.file=/usr/local/etc/promtail-config.yml
Restart=always
User=promtail
Group=adm
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start promtail.service
systemctl enable promtail.service
systemctl status promtail.service

echo 'configuration location: /usr/local/etc/promtail-config.yml'