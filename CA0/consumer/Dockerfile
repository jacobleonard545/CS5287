# Multi-stage build - Build stage
FROM maven:3.8-openjdk-17 AS build

WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn clean package -DskipTests

# Runtime stage
FROM openjdk:17-jdk-slim

WORKDIR /app

# Copy built JAR from build stage
COPY --from=build /app/target/data-processor-1.0-SNAPSHOT.jar app.jar

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser
RUN mkdir -p /app/logs && chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Set JVM options for t2.micro (reduced memory)
ENV JAVA_OPTS="-Xmx128m -Xms64m -XX:+UseSerialGC"

# Run the processor
CMD ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]