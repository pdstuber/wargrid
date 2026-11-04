FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY . .
RUN ./gradlew --no-daemon buildFatJar

FROM eclipse-temurin:21-jre
COPY --from=build /src/build/libs/relay-all.jar /relay-all.jar
# AppCDS archive from a short training run: halves local startup; no measured gain on fly yet.
RUN java -XX:ArchiveClassesAtExit=/relay.jsa -jar /relay-all.jar & pid=$!; \
    for i in $(seq 150); do curl -sf http://127.0.0.1:8080/health >/dev/null && break; sleep 0.2; done; \
    kill $pid; wait $pid || true; test -s /relay.jsa
EXPOSE 8080
CMD ["java", "-XX:SharedArchiveFile=/relay.jsa", "-XX:+UseSerialGC", "-XX:TieredStopAtLevel=1", "-XX:-UsePerfData", "-jar", "/relay-all.jar"]
