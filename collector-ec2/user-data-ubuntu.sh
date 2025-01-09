#!/bin/bash

cat <<EOF > /home/ubuntu/otel-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: "0.0.0.0:4317"
      http:
        endpoint: "0.0.0.0:4318"
  prometheus:
    config:
      scrape_configs:
        - job_name: "keycloak-exporter"
          static_configs:
            - targets:
                - "localhost:9000"
          metrics_path: /metrics
          relabel_configs:
            - source_labels: [__address__]
              regex: "(.*):9000"
              target_label: instance
              replacement: "keycloak"

        - job_name: "node-exporter"
          static_configs:
            - targets:
                - "localhost:9100"
          metrics_path: /metrics
          relabel_configs:
            - source_labels: [__address__]
              regex: "(.*):9100"
              target_label: instance
              replacement: "node"
     
exporters:
  otlphttp:
    endpoint: https://tempo.elvenobservability.com/http
    headers:
      X-Scope-OrgID: "4shark"
      Authorization: "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJlbHZlbi1sZ3RtLWp3dCIsInN1YiI6IjEyMzQ1Njc4OTAiLCJuYW1lIjoiRWx2ZW4gTEdUTSIsImFkbWluIjp0cnVlLCJpYXQiOjE3MzY0Mjc0MTl9.lM5Qc402JD0DJAvZaVSPPAUoV2rbO2efQsFGNjwZtCo"
  prometheusremotewrite:
    endpoint: https://mimir.elvenobservability.com/api/v1/push
    headers:
      X-Scope-OrgID: "4shark"
      Authorization: "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJlbHZlbi1sZ3RtLWp3dCIsInN1YiI6IjEyMzQ1Njc4OTAiLCJuYW1lIjoiRWx2ZW4gTEdUTSIsImFkbWluIjp0cnVlLCJpYXQiOjE3MzY0Mjc0MTl9.lM5Qc402JD0DJAvZaVSPPAUoV2rbO2efQsFGNjwZtCo"
  loki:
    endpoint: "http://loki.elvenobservability.com/loki/api/v1/push"
    default_labels_enabled:
      exporter: false
      job: true
    headers:
      X-Scope-OrgID: "4shark"
      Authorization: "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJlbHZlbi1sZ3RtLWp3dCIsInN1YiI6IjEyMzQ1Njc4OTAiLCJuYW1lIjoiRWx2ZW4gTEdUTSIsImFkbWluIjp0cnVlLCJpYXQiOjE3MzY0Mjc0MTl9.lM5Qc402JD0DJAvZaVSPPAUoV2rbO2efQsFGNjwZtCo"
processors:
  batch: {}
  resource:
    attributes:
    - action: insert
      key: loki.tenant
      value: host.name
  filter:
    metrics:
      exclude:
        match_type: regexp
        metric_names:
          - "go_.*"
          - "scrape_.*"
          - "otlp_.*"
          - "promhttp_.*"
service:
  pipelines:
    metrics:
      receivers: [otlp, prometheus]
      processors: [batch, filter]
      exporters: [prometheusremotewrite]
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlphttp]
    logs:
      receivers: [otlp]
      processors: [resource, batch]
      exporters: [loki]
EOF

# Run Otel Collector Contrib using Docker
sudo docker run -d --name otel-collector-contrib \
  -p 4317:4317 -p 4318:4318 \
  -v /home/ubuntu/otel-config.yaml:/etc/otel-config.yaml:ro \
  otel/opentelemetry-collector-contrib:latest \
  --config /etc/otel-config.yaml

# Configure Docker to automatically start on boot
sudo systemctl enable docker
