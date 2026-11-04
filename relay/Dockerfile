FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY . .
RUN ./gradlew --no-daemon buildFatJar

FROM eclipse-temurin:21-jre
COPY --from=build /src/build/libs/relay-all.jar /relay-all.jar
EXPOSE 8080
CMD ["java", "-jar", "/relay-all.jar"]
