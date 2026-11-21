#!/usr/bin/env bash
# /workspace(저장소)의 src/main/java, src/main/webapp 을 컴파일해 ROOT 로 배포하고 Tomcat 을 실행한다.
# 코드 수정 후 다시 배포: docker compose restart app
set -euo pipefail

SRC=/workspace/src/main
APP="$CATALINA_HOME/webapps/ROOT"

rm -rf "$APP"
mkdir -p "$APP/WEB-INF/classes"

if [ -d "$SRC/webapp" ]; then
  cp -r "$SRC/webapp/." "$APP/"
fi

if [ -d "$SRC/java" ]; then
  mapfile -t JAVA_FILES < <(find "$SRC/java" -name '*.java')
  if [ "${#JAVA_FILES[@]}" -gt 0 ]; then
    echo "[deploy] ${#JAVA_FILES[@]}개 Java 파일 컴파일"
    javac --release 21 -encoding UTF-8 -parameters \
      -cp "$CATALINA_HOME/lib/*:$APP/WEB-INF/lib/*" \
      -d "$APP/WEB-INF/classes" "${JAVA_FILES[@]}"
  fi
  # .java 가 아닌 리소스(.properties 등)도 classes 로 복사
  (cd "$SRC/java" && find . -type f ! -name '*.java' -exec cp --parents {} "$APP/WEB-INF/classes/" \;)
else
  echo "[deploy] src/main/java 가 없어 컴파일은 건너뜁니다."
fi

# 8000 포트: Eclipse 원격 디버깅(Remote Java Application) 연결용
export JPDA_ADDRESS='*:8000' JPDA_TRANSPORT=dt_socket
exec catalina.sh jpda run
