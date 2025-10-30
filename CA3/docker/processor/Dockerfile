FROM python:3.11-slim

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir kafka-python influxdb-client prometheus_client

# Copy processor script
COPY conveyor_processor.py .

# Run as non-root user
RUN useradd -m -u 1000 processor && chown -R processor:processor /app
USER processor

CMD ["python", "-u", "conveyor_processor.py"]
