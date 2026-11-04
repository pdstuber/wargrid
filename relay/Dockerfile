FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY . .
RUN ./gradlew --no-daemon buildFatJar

FROM eclipse-temurin:21-jre
COPY --from=build /src/build/libs/relay-all.jar /relay-all.jar
# AppCDS archive from a short training run: roughly halves JVM startup.
RUN java -XX:ArchiveClassesAtExit=/relay.jsa -jar /relay-all.jar & pid=$!; \
    until curl -sf http://127.0.0.1:8080/health >/dev/null; do sleep 0.2; done; \
    kill $pid; wait $pid || true; test -s /relay.jsa
EXPOSE 8080
CMD ["java", "-XX:SharedArchiveFile=/relay.jsa", "-XX:+UseSerialGC", "-XX:TieredStopAtLevel=1", "-XX:-UsePerfData", "-jar", "/relay-all.jar"]
