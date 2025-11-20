# ----------------------------------------------------------
# Country dinámico (inyectado desde variable de entorno)
# ----------------------------------------------------------
local_country = "${env.LOCAL_COUNTRY}"

# ----------------------------------------------------------
# Receivers
# ----------------------------------------------------------

otelcol.receiver.otlp "local" {
  grpc { endpoint = "0.0.0.0:4317" }
  http { endpoint = "0.0.0.0:4318" }
}

prometheus.scrape "node" {
  scrape_interval = "15s"
  targets = [
    { __address__ = "node-exporter:9100" }
  ]
}

# ----------------------------------------------------------
# Processor: inyecta tenant/country si la app no lo envía
# ----------------------------------------------------------

otelcol.processor.resource "inject_tenant" {
  attributes = {
    insert = [
      { key = "service.country", value = local_country }
    ]
  }
}

# ----------------------------------------------------------
# Exporter: envía al Alloy Gateway central
# ----------------------------------------------------------

otelcol.exporter.otlp "gateway" {
  endpoint = "http://alloy-gateway:4317"

  headers = {
    "X-Scope-OrgID" = local_country
  }
}

# ----------------------------------------------------------
# Procesador batch (recomendado por Opentelemetry)
# ----------------------------------------------------------

otelcol.processor.batch "batch" {}

# ----------------------------------------------------------
# Pipelines del agente local
# ----------------------------------------------------------

otelcol.service "local" {
  pipelines {

    traces {
      receivers = [otelcol.receiver.otlp.local]
      processors = [
        otelcol.processor.resource.inject_tenant,
        otelcol.processor.batch.batch
      ]
      exporters = [otelcol.exporter.otlp.gateway]
    }

    metrics {
      receivers = [
        otelcol.receiver.otlp.local,
        prometheus.scrape.node
      ]
      processors = [
        otelcol.processor.resource.inject_tenant,
        otelcol.processor.batch.batch
      ]
      exporters = [otelcol.exporter.otlp.gateway]
    }

    logs {
      receivers = [otelcol.receiver.otlp.local]
      processors = [
        otelcol.processor.resource.inject_tenant,
        otelcol.processor.batch.batch
      ]
      exporters = [otelcol.exporter.otlp.gateway]
    }

  }
}
