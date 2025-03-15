FROM openjdk:21-jdk-slim
WORKDIR /app
COPY target/TaskManagement-*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]