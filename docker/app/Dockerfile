# 픽업플래너 앱 서버: JDK 21.0.11 + Tomcat 11.0.27 (요구사항명세_비기능 SYS-003)
FROM eclipse-temurin:21.0.11_10-jdk-noble

ARG TOMCAT_VERSION=11.0.27
ARG TOMCAT_SHA512=a617896307cada4884b24f80c4e977ddad8b3e0f88ce0e2a6eea29d5f332498e276ae5976c227a9c8daecf05c7c90def684a3766dd5a81f47a56d8b1adf43dc3
ARG OJDBC_VERSION=23.26.1.0.0

ENV CATALINA_HOME=/usr/local/tomcat \
    TZ=Asia/Seoul \
    LANG=C.UTF-8
ENV PATH=$CATALINA_HOME/bin:$PATH

RUN set -eux; \
    curl -fsSLo /tmp/tomcat.tar.gz "https://archive.apache.org/dist/tomcat/tomcat-11/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"; \
    echo "${TOMCAT_SHA512}  /tmp/tomcat.tar.gz" | sha512sum -c -; \
    mkdir -p "$CATALINA_HOME"; \
    tar -xzf /tmp/tomcat.tar.gz -C "$CATALINA_HOME" --strip-components=1; \
    rm -rf /tmp/tomcat.tar.gz "$CATALINA_HOME"/webapps/*; \
    base="https://repo1.maven.org/maven2/com/oracle/database/jdbc/ojdbc11/${OJDBC_VERSION}/ojdbc11-${OJDBC_VERSION}.jar"; \
    curl -fsSLo "$CATALINA_HOME/lib/ojdbc11.jar" "$base"; \
    echo "$(curl -fsSL "$base.sha1")  $CATALINA_HOME/lib/ojdbc11.jar" | sha1sum -c -

COPY deploy-and-run.sh /usr/local/bin/deploy-and-run.sh
RUN chmod +x /usr/local/bin/deploy-and-run.sh

WORKDIR /workspace
EXPOSE 8080 8000
CMD ["deploy-and-run.sh"]
