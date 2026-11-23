# 맥북 Docker 개발 환경

메인 개발 환경은 윈도우입니다(`docs/01_requirements/요구사항명세_비기능.md` SYS-003).
맥북에서는 같은 버전을 Docker 컨테이너로 띄워서 작업합니다.

|항목|컨테이너 버전|
|--|--|
|JDK|Eclipse Temurin 21.0.11|
|Tomcat|11.0.27 (Servlet 6.1, JSP 4.0)|
|Oracle|Oracle AI Database 26ai Free 23.26.1.0.0 (FREEPDB1, AL32UTF8)|
|JDBC|ojdbc11 23.26.1.0.0 (Tomcat lib 에 포함)|

## 처음 한 번
1. 저장소 루트의 `.env.example` 을 `.env` 로 복사하고 비밀번호를 채운다.
2. `src/main/webapp/WEB-INF/db.properties.example` 을 `db.properties` 로 복사하고,
   `db.url` 을 `jdbc:oracle:thin:@//oracle:1521/FREEPDB1` 로, `db.password` 를 `.env` 의 `APP_DB_PASSWORD` 로 채운다.
3. 아래 "켜기" 를 실행한다. Oracle 은 처음에 DB 를 만드느라 몇 분 걸린다.

## 켜기 / 끄기
```bash
colima start pickup
docker --context colima-pickup compose up -d
```
```bash
docker --context colima-pickup compose stop
colima stop pickup
```

## 작업 흐름
- 코드 수정 후 재배포: `docker --context colima-pickup compose restart app`
  (src/main/java 를 컴파일하고 src/main/webapp 과 함께 ROOT 로 배포)
- 화면 확인: http://localhost:8080/
- DB 접속(SQL Developer): `localhost:1521`, 서비스 이름 `FREEPDB1`, 사용자 `PICKUP`
- Eclipse 디버깅: Debug Configurations → Remote Java Application → `localhost:8000`
- 로그: `docker --context colima-pickup compose logs -f app`

## 주의
- 맥 DB 와 윈도우 DB 는 서로 다른 DB 다. 테이블·기본 데이터는 SQL 파일로 저장소에 올려 양쪽에서 실행한다.
- 컨테이너는 Linux 라 파일 이름의 대소문자를 구분한다. 윈도우에서 되던 경로가 404 가 날 수 있다.
- `docker/oracle/setup` 스크립트는 DB 가 처음 만들어질 때만 실행된다. 다시 실행하려면
  `docker --context colima-pickup compose exec oracle bash /opt/oracle/scripts/setup/01_create_app_user.sh`
- DB 를 완전히 초기화하려면 `docker --context colima-pickup compose down -v` (데이터가 모두 지워진다).
