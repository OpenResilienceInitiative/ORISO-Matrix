FROM matrixdotorg/synapse:latest

# Copy custom homeserver configuration if provided
# Note: In Kubernetes, this is typically provided via ConfigMap
# This Dockerfile allows for custom builds with baked-in configs if needed
COPY homeserver.yaml /data/homeserver.yaml 2>/dev/null || true

# Expose Matrix Synapse ports
EXPOSE 8008 8009

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8008/_matrix/client/versions || exit 1

# Use the default entrypoint from base image
# The homeserver.yaml will be mounted via ConfigMap in Kubernetes

