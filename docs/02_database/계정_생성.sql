-- 픽업 플래너 전용 DB 계정(PICKUP) 생성
-- 관련 이슈 : #8
-- 실행 계정  : SYS (SYSDBA), 접속 서비스 FREEPDB1
-- 실행 방법  : SQL Developer 는 "스크립트 실행(F5)", SQL*Plus 는 @계정_생성.sql
-- 비밀번호는 실행할 때 입력한다. 이 파일에 적지 않는다.
-- 맥(Docker)은 docker/oracle/setup 스크립트가 같은 계정을 만들므로 실행하지 않는다.

WHENEVER SQLERROR EXIT SQL.SQLCODE

ALTER SESSION SET CONTAINER = FREEPDB1;

ACCEPT pickup_password CHAR PROMPT 'PICKUP 계정 비밀번호 입력: ' HIDE

CREATE USER PICKUP IDENTIFIED BY "&pickup_password"
  DEFAULT TABLESPACE USERS
  QUOTA UNLIMITED ON USERS;

-- docker/oracle/setup/01_create_app_user.sh 와 같은 권한
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE,
      CREATE PROCEDURE, CREATE TRIGGER, CREATE SYNONYM TO PICKUP;

UNDEFINE pickup_password

-- 확인: PICKUP 계정이 OPEN 상태로 한 줄 나오면 성공
SELECT username, account_status, default_tablespace
  FROM dba_users
 WHERE username = 'PICKUP';
