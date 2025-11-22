FROM alpine:latest

# Set working directory directly to final location
WORKDIR /app/test/orders-testing

# Install dependencies
RUN apk add --no-cache bash jq curl

# Default command (optional)
# CMD ["test-orders", "10"]

# Entrypoint
ENTRYPOINT ["/bin/bash", "/app/test/orders-testing/run.sh", "10"]
