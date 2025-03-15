FROM openjdk:21-jdk-slim
WORKDIR /app
COPY target/incident-management-*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]