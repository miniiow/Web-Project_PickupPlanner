-- 픽업 플래너 테이블 생성 (1차 구현 범위 18개)
-- 관련 이슈 : #8
-- 근거 문서 : 테이블_도출.md (구현 단계), 테이블_정의서.md
-- 실행 계정 : PICKUP (접속 서비스 FREEPDB1)
-- 실행 방법 : SQL Developer 는 "스크립트 실행(F5)"
-- 주의      : 다시 실행하면 아래 테이블을 지우고 새로 만든다. 입력해 둔 데이터도 모두 지워진다.

WHENEVER SQLERROR EXIT SQL.SQLCODE

-- 다른 계정(SYS 등)에서 실행하면 중단한다
BEGIN
  IF USER <> 'PICKUP' THEN
    RAISE_APPLICATION_ERROR(-20001, 'PICKUP 계정으로 접속해서 실행하세요. 현재 계정: ' || USER);
  END IF;
END;
/

-- ------------------------------------------------------------
-- 삭제 (생성의 반대 순서)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS import_item       CASCADE CONSTRAINTS PURGE;
DROP TABLE IF EXISTS import_batch      CASCADE CONSTRAINTS PURGE;
DROP TABLE IF EXISTS banner_pickup     CASCADE CONSTRAINTS PURGE;
DROP TABLE IF EXISTS banner_schedule   CASCADE CONSTRAINTS PURGE;
DROP TABLE IF EXISTS banner            CASCADE CONSTRAINTS PURGE;
DROP TABLE IF EXISTS banner_type       CASCADE CONSTRAINTS PURGE;
DROP TABLE IF EXISTS rule_guarantee    CASCADE CONSTRAINTS PURGE;
DROP TABLE IF EXISTS rule_rate         CASCADE CONSTRAINTS PURGE;
DROP TABLE IF EXISTS gacha_rule        CASCADE CONSTRAINTS PURGE;
DROP TABLE IF EXISTS pity_group        CASCADE CONSTRAINTS PURGE;
DROP TABLE IF EXISTS game_character    CASCADE CONSTRAINTS PURGE;
DROP TABLE IF EXISTS rarity            CASCADE CONSTRAINTS PURGE;
DROP TABLE IF EXISTS pull_cost         CASCADE CONSTRAINTS PURGE;
DROP TABLE IF EXISTS currency_exchange CASCADE CONSTRAINTS PURGE;
DROP TABLE IF EXISTS currency          CASCADE CONSTRAINTS PURGE;
DROP TABLE IF EXISTS server            CASCADE CONSTRAINTS PURGE;
DROP TABLE IF EXISTS member            CASCADE CONSTRAINTS PURGE;
DROP TABLE IF EXISTS game              CASCADE CONSTRAINTS PURGE;

-- ------------------------------------------------------------
-- 회원 (1차에서는 관리자 로그인에만 사용)
-- ------------------------------------------------------------
CREATE TABLE member (
  member_id     NUMBER GENERATED ALWAYS AS IDENTITY,
  login_id      VARCHAR2(20 CHAR)  NOT NULL,
  password_hash VARCHAR2(255 CHAR) NOT NULL,
  name          VARCHAR2(50 CHAR)  NOT NULL,
  email         VARCHAR2(100 CHAR) NOT NULL,
  role          VARCHAR2(10)       DEFAULT 'MEMBER' NOT NULL,
  created_at    TIMESTAMP          DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_member PRIMARY KEY (member_id),
  CONSTRAINT uq_member_login UNIQUE (login_id),
  CONSTRAINT ck_member_role CHECK (role IN ('MEMBER', 'ADMIN'))
);

-- ------------------------------------------------------------
-- 게임 기준 데이터
-- ------------------------------------------------------------
CREATE TABLE game (
  game_id    NUMBER GENERATED ALWAYS AS IDENTITY,
  code       VARCHAR2(30 CHAR)  NOT NULL,
  name       VARCHAR2(100 CHAR) NOT NULL,
  image_path VARCHAR2(500 CHAR),
  active     CHAR(1)            DEFAULT 'Y' NOT NULL,
  CONSTRAINT pk_game PRIMARY KEY (game_id),
  CONSTRAINT uq_game_code UNIQUE (code),
  CONSTRAINT ck_game_active CHECK (active IN ('Y', 'N'))
);

CREATE TABLE server (
  server_id NUMBER GENERATED ALWAYS AS IDENTITY,
  game_id   NUMBER            NOT NULL,
  code      VARCHAR2(10)      NOT NULL,
  name      VARCHAR2(50 CHAR) NOT NULL,
  is_base   CHAR(1)           DEFAULT 'N' NOT NULL,
  CONSTRAINT pk_server PRIMARY KEY (server_id),
  CONSTRAINT fk_server_game FOREIGN KEY (game_id) REFERENCES game (game_id),
  CONSTRAINT uq_server_code UNIQUE (game_id, code),
  CONSTRAINT ck_server_base CHECK (is_base IN ('Y', 'N'))
);

CREATE TABLE currency (
  currency_id NUMBER GENERATED ALWAYS AS IDENTITY,
  game_id     NUMBER            NOT NULL,
  code        VARCHAR2(30 CHAR) NOT NULL,
  name        VARCHAR2(50 CHAR) NOT NULL,
  external_id VARCHAR2(100 CHAR),
  image_path  VARCHAR2(500 CHAR),
  sort_order  NUMBER            DEFAULT 0 NOT NULL,
  active      CHAR(1)           DEFAULT 'Y' NOT NULL,
  CONSTRAINT pk_currency PRIMARY KEY (currency_id),
  CONSTRAINT fk_currency_game FOREIGN KEY (game_id) REFERENCES game (game_id),
  CONSTRAINT uq_currency_code UNIQUE (game_id, code),
  CONSTRAINT ck_currency_active CHECK (active IN ('Y', 'N'))
);

CREATE TABLE currency_exchange (
  exchange_id      NUMBER GENERATED ALWAYS AS IDENTITY,
  game_id          NUMBER NOT NULL,
  from_currency_id NUMBER NOT NULL,
  to_currency_id   NUMBER NOT NULL,
  from_amount      NUMBER NOT NULL,
  to_amount        NUMBER NOT NULL,
  CONSTRAINT pk_currency_exchange PRIMARY KEY (exchange_id),
  CONSTRAINT fk_exchange_game FOREIGN KEY (game_id) REFERENCES game (game_id),
  CONSTRAINT fk_exchange_from FOREIGN KEY (from_currency_id) REFERENCES currency (currency_id),
  CONSTRAINT fk_exchange_to FOREIGN KEY (to_currency_id) REFERENCES currency (currency_id),
  CONSTRAINT ck_exchange_amount CHECK (from_amount > 0 AND to_amount > 0)
);

CREATE TABLE pull_cost (
  pull_cost_id  NUMBER GENERATED ALWAYS AS IDENTITY,
  currency_id   NUMBER NOT NULL,
  cost_per_pull NUMBER NOT NULL,
  CONSTRAINT pk_pull_cost PRIMARY KEY (pull_cost_id),
  CONSTRAINT fk_pull_cost_currency FOREIGN KEY (currency_id) REFERENCES currency (currency_id),
  CONSTRAINT uq_pull_cost_currency UNIQUE (currency_id),
  CONSTRAINT ck_pull_cost_amount CHECK (cost_per_pull > 0)
);

CREATE TABLE rarity (
  rarity_id NUMBER GENERATED ALWAYS AS IDENTITY,
  game_id   NUMBER            NOT NULL,
  code      VARCHAR2(20 CHAR) NOT NULL,
  name      VARCHAR2(30 CHAR) NOT NULL,
  rank_no   NUMBER            NOT NULL,
  is_top    CHAR(1)           DEFAULT 'N' NOT NULL,
  CONSTRAINT pk_rarity PRIMARY KEY (rarity_id),
  CONSTRAINT fk_rarity_game FOREIGN KEY (game_id) REFERENCES game (game_id),
  CONSTRAINT uq_rarity_code UNIQUE (game_id, code),
  CONSTRAINT uq_rarity_rank UNIQUE (game_id, rank_no),
  CONSTRAINT ck_rarity_top CHECK (is_top IN ('Y', 'N'))
);

CREATE TABLE game_character (
  character_id NUMBER GENERATED ALWAYS AS IDENTITY,
  game_id      NUMBER             NOT NULL,
  external_id  VARCHAR2(100 CHAR),
  name         VARCHAR2(100 CHAR) NOT NULL,
  rarity_id    NUMBER             NOT NULL,
  image_path   VARCHAR2(500 CHAR),
  active       CHAR(1)            DEFAULT 'Y' NOT NULL,
  CONSTRAINT pk_game_character PRIMARY KEY (character_id),
  CONSTRAINT fk_character_game FOREIGN KEY (game_id) REFERENCES game (game_id),
  CONSTRAINT fk_character_rarity FOREIGN KEY (rarity_id) REFERENCES rarity (rarity_id),
  CONSTRAINT ck_character_active CHECK (active IN ('Y', 'N'))
);

-- ------------------------------------------------------------
-- 확률·천장 규칙
-- ------------------------------------------------------------
CREATE TABLE pity_group (
  pity_group_id NUMBER GENERATED ALWAYS AS IDENTITY,
  game_id       NUMBER            NOT NULL,
  code          VARCHAR2(30 CHAR) NOT NULL,
  name          VARCHAR2(50 CHAR) NOT NULL,
  CONSTRAINT pk_pity_group PRIMARY KEY (pity_group_id),
  CONSTRAINT fk_pity_group_game FOREIGN KEY (game_id) REFERENCES game (game_id),
  CONSTRAINT uq_pity_group_code UNIQUE (game_id, code)
);

CREATE TABLE gacha_rule (
  rule_id          NUMBER GENERATED ALWAYS AS IDENTITY,
  game_id          NUMBER             NOT NULL,
  name             VARCHAR2(100 CHAR) NOT NULL,
  pity_scope       VARCHAR2(10)       NOT NULL,
  pity_group_id    NUMBER,
  pity_rarity_id   NUMBER             NOT NULL,
  pity_start_count NUMBER             NOT NULL,
  pity_step_rate   NUMBER(5,2)        NOT NULL,
  description      VARCHAR2(1000 CHAR),
  active           CHAR(1)            DEFAULT 'Y' NOT NULL,
  CONSTRAINT pk_gacha_rule PRIMARY KEY (rule_id),
  CONSTRAINT fk_rule_game FOREIGN KEY (game_id) REFERENCES game (game_id),
  CONSTRAINT fk_rule_pity_group FOREIGN KEY (pity_group_id) REFERENCES pity_group (pity_group_id),
  CONSTRAINT fk_rule_pity_rarity FOREIGN KEY (pity_rarity_id) REFERENCES rarity (rarity_id),
  CONSTRAINT ck_rule_scope CHECK (
    (pity_scope = 'GROUP' AND pity_group_id IS NOT NULL) OR
    (pity_scope = 'BANNER' AND pity_group_id IS NULL)),
  CONSTRAINT ck_rule_pity CHECK (pity_start_count >= 0 AND pity_step_rate BETWEEN 0 AND 100),
  CONSTRAINT ck_rule_active CHECK (active IN ('Y', 'N'))
);

-- 한 규칙의 base_rate 합이 100 인지는 관리자 입력 화면에서 검사한다
CREATE TABLE rule_rate (
  rule_id    NUMBER      NOT NULL,
  rarity_id  NUMBER      NOT NULL,
  base_rate  NUMBER(5,2) NOT NULL,
  share_rate NUMBER(5,2) DEFAULT 0 NOT NULL,
  CONSTRAINT pk_rule_rate PRIMARY KEY (rule_id, rarity_id),
  CONSTRAINT fk_rate_rule FOREIGN KEY (rule_id) REFERENCES gacha_rule (rule_id),
  CONSTRAINT fk_rate_rarity FOREIGN KEY (rarity_id) REFERENCES rarity (rarity_id),
  CONSTRAINT ck_rate_range CHECK (base_rate BETWEEN 0 AND 100 AND share_rate BETWEEN 0 AND 100)
);

CREATE TABLE rule_guarantee (
  guarantee_id       NUMBER GENERATED ALWAYS AS IDENTITY,
  rule_id            NUMBER       NOT NULL,
  seq                NUMBER       NOT NULL,
  kind               VARCHAR2(20) NOT NULL,
  trigger_count      NUMBER       NOT NULL,
  rarity_id          NUMBER,
  distinct_from_prev CHAR(1)      DEFAULT 'N' NOT NULL,
  description        VARCHAR2(500 CHAR),
  CONSTRAINT pk_rule_guarantee PRIMARY KEY (guarantee_id),
  CONSTRAINT fk_guarantee_rule FOREIGN KEY (rule_id) REFERENCES gacha_rule (rule_id),
  CONSTRAINT fk_guarantee_rarity FOREIGN KEY (rarity_id) REFERENCES rarity (rarity_id),
  CONSTRAINT uq_guarantee_seq UNIQUE (rule_id, seq),
  CONSTRAINT ck_guarantee_kind CHECK (kind IN ('PICKUP_ONCE', 'TARGET_REPEAT', 'RARITY_BY')),
  CONSTRAINT ck_guarantee_count CHECK (trigger_count > 0),
  CONSTRAINT ck_guarantee_distinct CHECK (distinct_from_prev IN ('Y', 'N'))
);

-- ------------------------------------------------------------
-- 배너
-- ------------------------------------------------------------
CREATE TABLE banner_type (
  banner_type_id  NUMBER GENERATED ALWAYS AS IDENTITY,
  game_id         NUMBER            NOT NULL,
  code            VARCHAR2(30 CHAR) NOT NULL,
  name            VARCHAR2(50 CHAR) NOT NULL,
  default_rule_id NUMBER,
  CONSTRAINT pk_banner_type PRIMARY KEY (banner_type_id),
  CONSTRAINT fk_banner_type_game FOREIGN KEY (game_id) REFERENCES game (game_id),
  CONSTRAINT fk_banner_type_rule FOREIGN KEY (default_rule_id) REFERENCES gacha_rule (rule_id),
  CONSTRAINT uq_banner_type_code UNIQUE (game_id, code)
);

-- 가져온 배너는 규칙을 정하기 전에 PENDING 으로 들어오지만, rule_id 는 종류의 기본 규칙으로 채운다
CREATE TABLE banner (
  banner_id      NUMBER GENERATED ALWAYS AS IDENTITY,
  game_id        NUMBER             NOT NULL,
  banner_type_id NUMBER             NOT NULL,
  rule_id        NUMBER             NOT NULL,
  external_id    VARCHAR2(100 CHAR),
  name           VARCHAR2(200 CHAR) NOT NULL,
  image_path     VARCHAR2(500 CHAR),
  status         VARCHAR2(10)       NOT NULL,
  created_at     TIMESTAMP          DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_banner PRIMARY KEY (banner_id),
  CONSTRAINT fk_banner_game FOREIGN KEY (game_id) REFERENCES game (game_id),
  CONSTRAINT fk_banner_type FOREIGN KEY (banner_type_id) REFERENCES banner_type (banner_type_id),
  CONSTRAINT fk_banner_rule FOREIGN KEY (rule_id) REFERENCES gacha_rule (rule_id),
  CONSTRAINT ck_banner_status CHECK (status IN ('PENDING', 'ACTIVE', 'INACTIVE'))
);

CREATE TABLE banner_schedule (
  banner_id NUMBER    NOT NULL,
  server_id NUMBER    NOT NULL,
  start_at  TIMESTAMP NOT NULL,
  end_at    TIMESTAMP NOT NULL,
  confirmed CHAR(1)   DEFAULT 'N' NOT NULL,
  CONSTRAINT pk_banner_schedule PRIMARY KEY (banner_id, server_id),
  CONSTRAINT fk_schedule_banner FOREIGN KEY (banner_id) REFERENCES banner (banner_id),
  CONSTRAINT fk_schedule_server FOREIGN KEY (server_id) REFERENCES server (server_id),
  CONSTRAINT ck_schedule_period CHECK (end_at >= start_at),
  CONSTRAINT ck_schedule_confirmed CHECK (confirmed IN ('Y', 'N'))
);

CREATE TABLE banner_pickup (
  banner_id    NUMBER      NOT NULL,
  character_id NUMBER      NOT NULL,
  weight       NUMBER(5,2) DEFAULT 1 NOT NULL,
  sort_order   NUMBER      DEFAULT 0 NOT NULL,
  CONSTRAINT pk_banner_pickup PRIMARY KEY (banner_id, character_id),
  CONSTRAINT fk_pickup_banner FOREIGN KEY (banner_id) REFERENCES banner (banner_id),
  CONSTRAINT fk_pickup_character FOREIGN KEY (character_id) REFERENCES game_character (character_id),
  CONSTRAINT ck_pickup_weight CHECK (weight > 0)
);

-- ------------------------------------------------------------
-- 가져오기
-- ------------------------------------------------------------
CREATE TABLE import_batch (
  batch_id    NUMBER GENERATED ALWAYS AS IDENTITY,
  game_id     NUMBER       NOT NULL,
  source      VARCHAR2(10) NOT NULL,
  executed_by NUMBER,
  executed_at TIMESTAMP    DEFAULT SYSTIMESTAMP NOT NULL,
  result      VARCHAR2(10) NOT NULL,
  message     VARCHAR2(1000 CHAR),
  CONSTRAINT pk_import_batch PRIMARY KEY (batch_id),
  CONSTRAINT fk_batch_game FOREIGN KEY (game_id) REFERENCES game (game_id),
  CONSTRAINT fk_batch_member FOREIGN KEY (executed_by) REFERENCES member (member_id),
  CONSTRAINT ck_batch_source CHECK (source IN ('AUTO', 'FILE')),
  CONSTRAINT ck_batch_result CHECK (result IN ('SUCCESS', 'FAIL'))
);

CREATE TABLE import_item (
  item_id     NUMBER GENERATED ALWAYS AS IDENTITY,
  batch_id    NUMBER             NOT NULL,
  entity_type VARCHAR2(10)       NOT NULL,
  external_id VARCHAR2(100 CHAR) NOT NULL,
  change_type VARCHAR2(10)       NOT NULL,
  payload     CLOB               NOT NULL,
  status      VARCHAR2(10)       DEFAULT 'WAITING' NOT NULL,
  reviewed_by NUMBER,
  reviewed_at TIMESTAMP,
  CONSTRAINT pk_import_item PRIMARY KEY (item_id),
  CONSTRAINT fk_item_batch FOREIGN KEY (batch_id) REFERENCES import_batch (batch_id),
  CONSTRAINT fk_item_member FOREIGN KEY (reviewed_by) REFERENCES member (member_id),
  CONSTRAINT ck_item_entity CHECK (entity_type IN ('BANNER', 'EVENT', 'CHARACTER')),
  CONSTRAINT ck_item_change CHECK (change_type IN ('NEW', 'CHANGED')),
  CONSTRAINT ck_item_status CHECK (status IN ('WAITING', 'APPLIED', 'EXCLUDED'))
);

-- ------------------------------------------------------------
-- 인덱스
-- ------------------------------------------------------------
-- 외부 ID 는 같은 게임 안에서 중복 금지. 외부 ID 가 없는 행은 여러 개 허용해야 한다.
-- (복합 UNIQUE 제약은 external_id 가 NULL 인 행끼리도 중복으로 막으므로 함수 기반 인덱스를 쓴다)
CREATE UNIQUE INDEX uq_currency_external ON currency
  (CASE WHEN external_id IS NOT NULL THEN game_id END, external_id);
CREATE UNIQUE INDEX uq_character_external ON game_character
  (CASE WHEN external_id IS NOT NULL THEN game_id END, external_id);
CREATE UNIQUE INDEX uq_banner_external ON banner
  (CASE WHEN external_id IS NOT NULL THEN game_id END, external_id);

CREATE INDEX ix_banner_game_status ON banner (game_id, status);
CREATE INDEX ix_schedule_server_period ON banner_schedule (server_id, start_at, end_at);
CREATE INDEX ix_item_batch_status ON import_item (batch_id, status);

-- ------------------------------------------------------------
-- 확인: 18개 테이블이 나오면 성공
-- ------------------------------------------------------------
SELECT COUNT(*) AS table_count
  FROM user_tables
 WHERE table_name IN (
   'MEMBER', 'GAME', 'SERVER', 'CURRENCY', 'CURRENCY_EXCHANGE', 'PULL_COST',
   'RARITY', 'GAME_CHARACTER', 'PITY_GROUP', 'GACHA_RULE', 'RULE_RATE',
   'RULE_GUARANTEE', 'BANNER_TYPE', 'BANNER', 'BANNER_SCHEDULE', 'BANNER_PICKUP',
   'IMPORT_BATCH', 'IMPORT_ITEM');
