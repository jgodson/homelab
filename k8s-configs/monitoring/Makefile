NAMESPACE := monitoring

.PHONY: deploy-all deploy-alloy deploy-grafana deploy-influxdb deploy-loki deploy-prometheus deploy-promtail deploy-telegraf deploy-tempo

deploy-all: deploy-prometheus deploy-loki deploy-tempo deploy-promtail deploy-telegraf deploy-influxdb deploy-grafana deploy-alloy

deploy-alloy:
	helm upgrade --install alloy grafana/alloy -f ./alloy/alloy-values.yaml -n $(NAMESPACE)

deploy-grafana:
	cd grafana && ./deploy.sh

deploy-influxdb:
	helm upgrade --install influxdb influxdata/influxdb2 -f ./influxdb2/influxdb2-values.yaml -n $(NAMESPACE)

deploy-loki:
	helm upgrade --install loki grafana/loki -f ./loki/loki-values.yaml -n $(NAMESPACE)

deploy-prometheus:
	helm upgrade --install prometheus prometheus-community/prometheus -f ./prometheus/prometheus-values.yaml -n $(NAMESPACE)

deploy-promtail:
	helm upgrade --install promtail grafana/promtail -f ./promtail/promtail-values.yaml -n $(NAMESPACE)

deploy-telegraf:
	helm upgrade --install telegraf-ssh influxdata/telegraf -f ./telegraf/telegraf-values.yaml -n $(NAMESPACE)

deploy-tempo:
	helm upgrade --install tempo grafana/tempo-distributed -f ./tempo/tempo-values.yaml -n $(NAMESPACE)
