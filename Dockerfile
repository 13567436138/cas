ARG BASE_IMAGE="azul/zulu-openjdk:21"

FROM $BASE_IMAGE AS overlay

ARG EXT_BUILD_COMMANDS=""
ARG EXT_BUILD_OPTIONS=""

RUN mkdir -p cas-overlay
COPY ./src cas-overlay/src/
COPY ./gradle/ cas-overlay/gradle/
COPY ./gradlew ./settings.gradle ./build.gradle ./gradle.properties ./lombok.config /cas-overlay/
COPY cas-server-support-webconfig-7.2.0-SNAPSHOT.jar cas-overlay/

RUN mkdir -p ~/.gradle \
    && echo "org.gradle.daemon=false" >> ~/.gradle/gradle.properties \
    && echo "org.gradle.configureondemand=true" >> ~/.gradle/gradle.properties \
    && cd cas-overlay \
    && chmod 750 ./gradlew \
    && ./gradlew --version;

RUN cd cas-overlay \
    && ./gradlew clean build $EXT_BUILD_COMMANDS --parallel --no-daemon -Pexecutable=false $EXT_BUILD_OPTIONS;

RUN cd cas-overlay \
    && java -Djarmode=tools -jar build/libs/cas.war extract \
    && java -XX:ArchiveClassesAtExit=./cas/cas.jsa -Dspring.context.exit=onRefresh -jar cas/cas.war

FROM $BASE_IMAGE AS cas

LABEL "Organization"="Apereo"
LABEL "Description"="Apereo CAS"

RUN cd / \
    && mkdir -p /etc/cas/config \
    && mkdir -p /etc/cas/services \
    && mkdir -p /etc/cas/saml \
    && mkdir -p cas-overlay;

COPY --from=overlay cas-overlay/cas cas-overlay/cas/

COPY etc/cas/ /etc/cas/
COPY etc/cas/config/ /etc/cas/config/
#COPY etc/cas/services/ /etc/cas/services/
#COPY etc/cas/saml/ /etc/cas/saml/

EXPOSE 8080 8443

ENV PATH $PATH:$JAVA_HOME/bin:.

WORKDIR cas-overlay

RUN rm -rf cas/lib/cas-server-support-webconfig-7.2.0-RC1.jar
COPY cas-server-support-webconfig-7.2.0-SNAPSHOT.jar cas/lib/
ENTRYPOINT ["java", "-server", "-noverify", "-Xmx2048M", "-XX:SharedArchiveFile=cas/cas.jsa", "-jar", "cas/cas.war"]
