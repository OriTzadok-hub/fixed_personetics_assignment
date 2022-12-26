FROM openjdk:8-jre-slim
RUN mkdir web
COPY target/demo.jar web/demo.jar
WORKDIR web
CMD java -jar demo.jar
