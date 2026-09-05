FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -q -DskipTests dependency:go-offline
COPY src src
RUN mvn -q clean package -DskipTests

FROM eclipse-temurin:17-jre
WORKDIR /app
RUN addgroup --system dental && adduser --system --ingroup dental dental
COPY --from=build /app/target/dental-americana-backend-*.jar app.jar
RUN mkdir -p /app/storage/patients && chown -R dental:dental /app
USER dental
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
