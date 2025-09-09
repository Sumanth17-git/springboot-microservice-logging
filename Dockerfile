#FROM openjdk:17-jdk-slim
FROM eclipse-temurin:17-jre-jammy
WORKDIR /usr/app
ADD target/*.jar app.jar
# --- Datadog defaults (can be overridden at runtime) ---
ENV DD_SERVICE="java-service" \
    DD_ENV="dev" \
    DD_VERSION="0.0.1" \
    DD_LOGS_INJECTION="true" \
    DD_DYNAMIC_INSTRUMENTATION_ENABLED="true"
EXPOSE 8881
ENTRYPOINT exec java -jar app.jar

