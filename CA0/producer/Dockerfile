FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser
RUN mkdir -p /app/logs && chown -R appuser:appuser /app

# Copy application code
COPY . .

# Switch to non-root user
USER appuser

# Set default environment variables
ENV KAFKA_BOOTSTRAP_SERVERS=localhost:9092
ENV KAFKA_TOPIC=sensor-data
ENV PRODUCER_INTERVAL=5
ENV SENSOR_COUNT=10
ENV PRODUCER_TYPE=realtime

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import sys; sys.exit(0)"

# Run the producer
CMD ["python", "producer.py"]