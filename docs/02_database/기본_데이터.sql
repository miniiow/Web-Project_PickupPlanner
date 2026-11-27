-- 픽업 플래너 기본 데이터 (명일방주 설정값 + 시뮬레이터 시험용 배너)
-- 관련 이슈 : #8
-- 실행 계정 : PICKUP (접속 서비스 FREEPDB1), 테이블_생성.sql 을 먼저 실행한다
-- 실행 방법 : SQL Developer 는 "스크립트 실행(F5)"
-- 다시 넣으려면 테이블_생성.sql 을 다시 실행한 뒤 이 파일을 실행한다.
--
-- 값의 출처
--  - 확률·천장·보장 : 인게임 헤드헌팅 규칙과 공식 확률 안내
--  - 환산 비율(합성옥 600 = 1회, 오리지늄 1 = 합성옥 180) : 위키 기준, 확인 필요
--  - 재화 ID(external_id) : ArkPRTS 코드 기준, 실제 응답으로 확인 필요
--  - 캐릭터, 실제 배너의 ID·기간·픽업 : ArknightsAssets/ArknightsGamedata (kr)
--    배너 이름은 알아보기 쉽게 "종류: 픽업" 형태로 붙였다. 일시는 한국 시간이다.
--  - 예시 배너는 실제 배너가 아니며 일정도 시험용이다
-- 커널 헤드헌팅은 다루지 않는다(요구사항 C6). 커널 규칙·배너·출현 풀은 넣지 않는다.
-- 출현 풀 (character_pool) : STANDARD(표준). 풀이 없으면 픽업일 때만 나온다.
--  - 커널 전용(공개 데이터의 classicPotentialItemId) 5·6성은 캐릭터 정보만 넣고 풀은 없다
--  - 한정 : 공개 데이터의 limitedCharId
--  - 콜라보 : 데이터에 구분 항목이 없어 직접 지정했다. 확인 필요
--  - 콜라보·한정 배너의 픽업 외 캐릭터는 표준 풀로 두었다. 확인 필요
-- 관리자 계정은 비밀번호 해시 방식을 정한 뒤에 추가한다.

SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
  v_count   NUMBER;

  v_game    game.game_id%TYPE;
  v_kr      server.server_id%TYPE;

  v_originium  currency.currency_id%TYPE;
  v_orundum    currency.currency_id%TYPE;
  v_ticket     currency.currency_id%TYPE;
  v_ten_ticket currency.currency_id%TYPE;

  v_r3 rarity.rarity_id%TYPE;
  v_r4 rarity.rarity_id%TYPE;
  v_r5 rarity.rarity_id%TYPE;
  v_r6 rarity.rarity_id%TYPE;

  v_pg_standard pity_group.pity_group_id%TYPE;

  v_rule_standard gacha_rule.rule_id%TYPE;
  v_rule_collab   gacha_rule.rule_id%TYPE;

  v_type_standard banner_type.banner_type_id%TYPE;
  v_type_collab   banner_type.banner_type_id%TYPE;
  v_banner        banner.banner_id%TYPE;

  PROCEDURE add_currency(p_code VARCHAR2, p_name VARCHAR2, p_external VARCHAR2,
                         p_sort NUMBER, p_id OUT NUMBER) IS
  BEGIN
    INSERT INTO currency (game_id, code, name, external_id, sort_order)
    VALUES (v_game, p_code, p_name, p_external, p_sort)
    RETURNING currency_id INTO p_id;
  END;

  PROCEDURE add_rarity(p_code VARCHAR2, p_name VARCHAR2, p_rank NUMBER,
                       p_top CHAR, p_id OUT NUMBER) IS
  BEGIN
    INSERT INTO rarity (game_id, code, name, rank_no, is_top)
    VALUES (v_game, p_code, p_name, p_rank, p_top)
    RETURNING rarity_id INTO p_id;
  END;

  PROCEDURE add_rule(p_name VARCHAR2, p_scope VARCHAR2, p_group NUMBER,
                     p_desc VARCHAR2, p_id OUT NUMBER) IS
  BEGIN
    -- 천장 : 6성이 50번 연속으로 나오지 않으면 다음 뽑기부터 2%씩 오른다
    INSERT INTO gacha_rule (game_id, name, pity_scope, pity_group_id, pity_rarity_id,
                            pity_start_count, pity_step_rate, description)
    VALUES (v_game, p_name, p_scope, p_group, v_r6, 50, 2, p_desc)
    RETURNING rule_id INTO p_id;

    -- 등급별 기본 확률 / 픽업 몫
    INSERT INTO rule_rate (rule_id, rarity_id, base_rate, share_rate) VALUES (p_id, v_r6, 2, 50);
    INSERT INTO rule_rate (rule_id, rarity_id, base_rate, share_rate) VALUES (p_id, v_r5, 8, 50);
    INSERT INTO rule_rate (rule_id, rarity_id, base_rate, share_rate) VALUES (p_id, v_r4, 50, 0);
    INSERT INTO rule_rate (rule_id, rarity_id, base_rate, share_rate) VALUES (p_id, v_r3, 40, 0);
  END;

  PROCEDURE add_guarantee(p_rule NUMBER, p_seq NUMBER, p_kind VARCHAR2, p_count NUMBER,
                          p_rarity NUMBER, p_distinct CHAR, p_desc VARCHAR2) IS
  BEGIN
    INSERT INTO rule_guarantee (rule_id, seq, kind, trigger_count, rarity_id,
                                distinct_from_prev, description)
    VALUES (p_rule, p_seq, p_kind, p_count, p_rarity, p_distinct, p_desc);
  END;

  -- 배너와 한국 서버 일정을 넣고, 이후 픽업이 이 배너에 들어가도록 v_banner 를 바꾼다
  PROCEDURE add_banner(p_type NUMBER, p_rule NUMBER, p_external VARCHAR2, p_name VARCHAR2,
                       p_start TIMESTAMP, p_end TIMESTAMP, p_confirmed CHAR) IS
  BEGIN
    INSERT INTO banner (game_id, banner_type_id, rule_id, external_id, name, status)
    VALUES (v_game, p_type, p_rule, p_external, p_name, 'ACTIVE')
    RETURNING banner_id INTO v_banner;

    INSERT INTO banner_schedule (banner_id, server_id, start_at, end_at, confirmed)
    VALUES (v_banner, v_kr, p_start, p_end, p_confirmed);
  END;

  -- 캐릭터와 출현 풀을 넣는다. p_pools : 'S' 표준, NULL 없음(한정·콜라보·커널 전용)
  PROCEDURE add_character(p_external VARCHAR2, p_name VARCHAR2, p_rarity NUMBER, p_pools VARCHAR2) IS
    v_id game_character.character_id%TYPE;
  BEGIN
    INSERT INTO game_character (game_id, external_id, name, rarity_id)
    VALUES (v_game, p_external, p_name, p_rarity)
    RETURNING character_id INTO v_id;

    IF INSTR(p_pools, 'S') > 0 THEN
      INSERT INTO character_pool (character_id, pool_code) VALUES (v_id, 'STANDARD');
    END IF;
  END;

  -- 지금 배너(v_banner)에 픽업을 넣는다
  PROCEDURE add_pickup(p_external VARCHAR2, p_order NUMBER) IS
  BEGIN
    INSERT INTO banner_pickup (banner_id, character_id, weight, sort_order)
    SELECT v_banner, character_id, 1, p_order
      FROM game_character
     WHERE game_id = v_game AND external_id = p_external;

    IF SQL%ROWCOUNT <> 1 THEN
      RAISE_APPLICATION_ERROR(-20003, '픽업 캐릭터가 없습니다: ' || p_external);
    END IF;
  END;

BEGIN
  IF USER <> 'PICKUP' THEN
    RAISE_APPLICATION_ERROR(-20001, 'PICKUP 계정으로 접속해서 실행하세요. 현재 계정: ' || USER);
  END IF;

  SELECT COUNT(*) INTO v_count FROM game WHERE code = 'arknights';
  IF v_count > 0 THEN
    RAISE_APPLICATION_ERROR(-20002, '이미 기본 데이터가 있습니다. 테이블_생성.sql 을 다시 실행한 뒤 넣으세요.');
  END IF;

  -- 게임, 서버
  INSERT INTO game (code, name) VALUES ('arknights', '명일방주')
  RETURNING game_id INTO v_game;

  INSERT INTO server (game_id, code, name, is_base) VALUES (v_game, 'KR', '한국 서버', 'Y')
  RETURNING server_id INTO v_kr;
  INSERT INTO server (game_id, code, name, is_base) VALUES (v_game, 'CN', '중국 서버', 'N');

  -- 재화, 환산 비율, 뽑기 비용
  add_currency('originium',  '오리지늄',        '4002', 1, v_originium);
  add_currency('orundum',    '합성옥',          '4003', 2, v_orundum);
  add_currency('ticket',     '헤드헌팅권',      '7003', 3, v_ticket);
  add_currency('ten_ticket', '10회 헤드헌팅권', '7004', 4, v_ten_ticket);

  INSERT INTO currency_exchange (game_id, from_currency_id, to_currency_id, from_amount, to_amount)
  VALUES (v_game, v_originium, v_orundum, 1, 180);
  INSERT INTO currency_exchange (game_id, from_currency_id, to_currency_id, from_amount, to_amount)
  VALUES (v_game, v_ten_ticket, v_ticket, 1, 10);

  INSERT INTO pull_cost (currency_id, cost_per_pull) VALUES (v_orundum, 600);
  INSERT INTO pull_cost (currency_id, cost_per_pull) VALUES (v_ticket, 1);

  -- 등급
  add_rarity('R3', '3성', 3, 'N', v_r3);
  add_rarity('R4', '4성', 4, 'N', v_r4);
  add_rarity('R5', '5성', 5, 'N', v_r5);
  add_rarity('R6', '6성', 6, 'Y', v_r6);

  -- 천장 묶음
  INSERT INTO pity_group (game_id, code, name) VALUES (v_game, 'standard', '표준 헤드헌팅')
  RETURNING pity_group_id INTO v_pg_standard;

  -- 규칙
  add_rule('표준 규칙', 'GROUP', v_pg_standard, '표준 배너끼리 천장 횟수를 이어서 센다', v_rule_standard);
  add_rule('콜라보 규칙', 'BANNER', NULL, '배너마다 따로 세고 배너가 끝나면 초기화한다', v_rule_collab);

  -- 보장
  add_guarantee(v_rule_standard, 1, 'PICKUP_ONCE', 150, v_r6, 'N', '150회 안에 픽업 6성 1명 확정(1회)');
  add_guarantee(v_rule_standard, 2, 'PICKUP_ONCE', 300, v_r6, 'Y', '300회에 다른 픽업 6성 확정(1회)');
  add_guarantee(v_rule_collab,   1, 'TARGET_REPEAT', 120, v_r6, 'N', '120회마다 콜라보 6성 확정');
  add_guarantee(v_rule_collab,   2, 'RARITY_BY', 50, v_r5, 'N', '처음 50회 안에 픽업 5성이 없으면 다음 5성은 픽업');

  -- 배너 종류 (한정은 규칙을 확인한 뒤 연결한다)
  INSERT INTO banner_type (game_id, code, name, default_rule_id, pool_code)
  VALUES (v_game, 'STANDARD', '표준', v_rule_standard, 'STANDARD')
  RETURNING banner_type_id INTO v_type_standard;
  INSERT INTO banner_type (game_id, code, name, default_rule_id, pool_code)
  VALUES (v_game, 'COLLAB', '콜라보', v_rule_collab, 'STANDARD')
  RETURNING banner_type_id INTO v_type_collab;
  INSERT INTO banner_type (game_id, code, name, default_rule_id, pool_code)
  VALUES (v_game, 'LIMITED', '한정', NULL, 'STANDARD');

  -- 캐릭터 전체 (6성 → 3성)
  add_character('char_003_kalts', '켈시', v_r6, NULL);
  add_character('char_010_chen', '첸', v_r6, NULL);
  add_character('char_017_huang', '블레이즈', v_r6, NULL);
  add_character('char_103_angel', '엑시아', v_r6, NULL);
  add_character('char_112_siege', '시즈', v_r6, NULL);
  add_character('char_113_cqbw', 'W', v_r6, NULL);
  add_character('char_134_ifrit', '이프리트', v_r6, NULL);
  add_character('char_136_hsguma', '호시구마', v_r6, NULL);
  add_character('char_147_shining', '샤이닝', v_r6, NULL);
  add_character('char_172_svrash', '실버애쉬', v_r6, NULL);
  add_character('char_179_cgbird', '나이팅게일', v_r6, NULL);
  add_character('char_180_amgoat', '에이야퍄들라', v_r6, NULL);
  add_character('char_188_helage', '헬라그', v_r6, NULL);
  add_character('char_197_poca', '로사', v_r6, NULL);
  add_character('char_202_demkni', '사리아', v_r6, NULL);
  add_character('char_206_gnosis', '노시스', v_r6, NULL);
  add_character('char_213_mostma', '모스티마', v_r6, NULL);
  add_character('char_222_bpipe', '백파이프', v_r6, NULL);
  add_character('char_225_haak', '아', v_r6, NULL);
  add_character('char_245_cello', '비르투오사', v_r6, NULL);
  add_character('char_248_mgllan', '마젤란', v_r6, NULL);
  add_character('char_249_mlyss', '뮤엘시스', v_r6, NULL);
  add_character('char_250_phatom', '팬텀', v_r6, NULL);
  add_character('char_263_skadi', '스카디', v_r6, NULL);
  add_character('char_264_f12yin', '마운틴', v_r6, NULL);
  add_character('char_291_aglina', '안젤리나', v_r6, NULL);
  add_character('char_293_thorns', '쏜즈', v_r6, NULL);
  add_character('char_300_phenxi', '피아메타', v_r6, NULL);
  add_character('char_311_mudrok', '머드락', v_r6, NULL);
  add_character('char_322_lmlee', '리', v_r6, NULL);
  add_character('char_332_archet', '아르케토', v_r6, NULL);
  add_character('char_340_shwaz', '슈바르츠', v_r6, NULL);
  add_character('char_350_surtr', '수르트', v_r6, NULL);
  add_character('char_358_lisa', '스즈란', v_r6, NULL);
  add_character('char_362_saga', '사가', v_r6, NULL);
  add_character('char_377_gdglow', '골든글로우', v_r6, NULL);
  add_character('char_391_rosmon', '로즈몬티스', v_r6, NULL);
  add_character('char_400_weedy', '위디', v_r6, NULL);
  add_character('char_416_zumama', '유넥티스', v_r6, NULL);
  add_character('char_420_flamtl', '플레임테일', v_r6, NULL);
  add_character('char_423_blemsh', '블레미샤인', v_r6, NULL);
  add_character('char_426_billro', '카넬리안', v_r6, NULL);
  add_character('char_430_fartth', '파투스', v_r6, NULL);
  add_character('char_437_mizuki', '미즈키', v_r6, NULL);
  add_character('char_450_necras', '네크라스', v_r6, 'S');
  add_character('char_456_ash', 'Ash', v_r6, NULL);
  add_character('char_472_pasngr', '패신저', v_r6, NULL);
  add_character('char_479_sleach', '사일라흐', v_r6, NULL);
  add_character('char_485_pallas', '팔라스', v_r6, NULL);
  add_character('char_1012_skadi2', '스카디 더 커럽팅 하트', v_r6, NULL);
  add_character('char_1013_chen2', '첸 더 홀룽데이', v_r6, NULL);
  add_character('char_1014_nearl2', '니어 더 래디언트 나이트', v_r6, NULL);
  add_character('char_1016_agoat2', '에이야퍄들라 더 크비트 아스카', v_r6, NULL);
  add_character('char_1019_siege2', '비나 빅토리아', v_r6, 'S');
  add_character('char_1020_reed2', '리드 더 플레임 섀도우', v_r6, 'S');
  add_character('char_1023_ghost2', '스펙터 디 언체인드', v_r6, NULL);
  add_character('char_1026_gvial2', '가비알 디 인빈서블', v_r6, NULL);
  add_character('char_1028_texas2', '텍사스 디 오메르토사', v_r6, NULL);
  add_character('char_1029_yato2', '키린R 야토', v_r6, NULL);
  add_character('char_1032_excu2', '이그제큐터 디 엑스 포에데레', v_r6, 'S');
  add_character('char_1033_swire2', '스와이어 디 엘리건트 위트', v_r6, 'S');
  add_character('char_1034_jesca2', '제시카 더 리버레이티드', v_r6, 'S');
  add_character('char_1035_wisdel', '위셔델', v_r6, NULL);
  add_character('char_1038_whitw2', '라플란드 더 데카덴차', v_r6, NULL);
  add_character('char_1039_thorn2', '쏜즈 더 로드스타', v_r6, 'S');
  add_character('char_1040_blaze2', '블레이즈 디 이그나이팅 스파크', v_r6, 'S');
  add_character('char_1041_angel2', '엑시아 더 뉴 커버넌트', v_r6, NULL);
  add_character('char_1042_phatm2', '트라고디아', v_r6, 'S');
  add_character('char_1043_leizi2', '레이즈 더 썬더브링어', v_r6, 'S');
  add_character('char_1044_hsgma2', '호시구마 더 브리처', v_r6, NULL);
  add_character('char_1045_svash2', '실버애쉬 더 레인프로스트', v_r6, NULL);
  add_character('char_1046_sbell2', '프라마닉스 더 프레리타', v_r6, 'S');
  add_character('char_1048_orchd2', '염호룡 오키드', v_r6, NULL);
  add_character('char_1050_chen3', '첸 더 던스트릭', v_r6, 'S');
  add_character('char_1051_headb2', '지마 더 레이징 타이드', v_r6, 'S');
  add_character('char_1052_kalts2', '켈시 에스페란타', v_r6, NULL);
  add_character('char_2012_typhon', '티폰', v_r6, 'S');
  add_character('char_2013_cerber', '케오베', v_r6, NULL);
  add_character('char_2014_nian', '니엔', v_r6, NULL);
  add_character('char_2015_dusk', '시', v_r6, NULL);
  add_character('char_2023_ling', '링', v_r6, NULL);
  add_character('char_2024_chyue', '총웨', v_r6, NULL);
  add_character('char_2025_shu', '슈', v_r6, NULL);
  add_character('char_2026_yu', '위', v_r6, NULL);
  add_character('char_2027_wang', '왕', v_r6, NULL);
  add_character('char_4009_irene', '아이린', v_r6, NULL);
  add_character('char_4010_etlchi', '엔텔레키아', v_r6, 'S');
  add_character('char_4026_vulpis', '불피스폴리아', v_r6, 'S');
  add_character('char_4027_heyak', '오올헤약', v_r6, 'S');
  add_character('char_4037_demetr', '벨로네', v_r6, 'S');
  add_character('char_4039_horn', '혼', v_r6, NULL);
  add_character('char_4046_ebnhlz', '에벤홀츠', v_r6, NULL);
  add_character('char_4048_doroth', '도로시', v_r6, NULL);
  add_character('char_4055_bgsnow', '파죰카', v_r6, 'S');
  add_character('char_4056_titi', '티티', v_r6, 'S');
  add_character('char_4058_pepe', '페페', v_r6, NULL);
  add_character('char_4064_mlynar', '무에나', v_r6, 'S');
  add_character('char_4065_judge', '페넌스', v_r6, 'S');
  add_character('char_4072_ironmn', '스테인리스', v_r6, 'S');
  add_character('char_4080_lin', '린', v_r6, 'S');
  add_character('char_4082_qiubai', '치우바이', v_r6, 'S');
  add_character('char_4087_ines', '이네스', v_r6, 'S');
  add_character('char_4088_hodrer', '외드레르', v_r6, 'S');
  add_character('char_4098_vvana', '비비아나', v_r6, 'S');
  add_character('char_4116_blkkgt', '데겐블레허', v_r6, 'S');
  add_character('char_4117_ray', '레이', v_r6, 'S');
  add_character('char_4121_zuole', '좌락', v_r6, 'S');
  add_character('char_4123_ela', 'Ela', v_r6, NULL);
  add_character('char_4132_ascln', '아스카론', v_r6, 'S');
  add_character('char_4133_logos', '로고스', v_r6, 'S');
  add_character('char_4138_narant', '나란투야', v_r6, 'S');
  add_character('char_4141_marcil', '마르실', v_r6, NULL);
  add_character('char_4145_ulpia', '울피아누스', v_r6, 'S');
  add_character('char_4146_nymph', '님프', v_r6, 'S');
  add_character('char_4179_monstr', 'Mon3tr', v_r6, 'S');
  add_character('char_4182_oblvns', '토가와 사키코', v_r6, NULL);
  add_character('char_4193_lemuen', '르무엔', v_r6, 'S');
  add_character('char_4202_haruka', '하루카', v_r6, 'S');
  add_character('char_4204_mantra', '만트라', v_r6, 'S');
  add_character('char_4212_nasti', '내스티', v_r6, 'S');
  add_character('char_4228_closur', '클로저', v_r6, 'S');
  add_character('char_101_sora', '소라', v_r5, NULL);
  add_character('char_102_texas', '텍사스', v_r5, NULL);
  add_character('char_106_franka', '프란카', v_r5, NULL);
  add_character('char_107_liskam', '리스캄', v_r5, NULL);
  add_character('char_108_silent', '사일런스', v_r5, NULL);
  add_character('char_115_headbr', '지마', v_r5, NULL);
  add_character('char_128_plosis', '프틸롭시스', v_r5, NULL);
  add_character('char_129_bluep', '블루포이즌', v_r5, NULL);
  add_character('char_140_whitew', '라플란드', v_r5, NULL);
  add_character('char_143_ghost', '스펙터', v_r5, NULL);
  add_character('char_144_red', '레드', v_r5, NULL);
  add_character('char_145_prove', '프로방스', v_r5, NULL);
  add_character('char_148_nearl', '니어', v_r5, NULL);
  add_character('char_155_tiger', '인드라', v_r5, 'S');
  add_character('char_158_milu', '파이어워치', v_r5, NULL);
  add_character('char_163_hpsts', '벌컨', v_r5, 'S');
  add_character('char_164_nightm', '나이트메어', v_r5, NULL);
  add_character('char_166_skfire', '스카이파이어', v_r5, NULL);
  add_character('char_171_bldsk', '와파린', v_r5, NULL);
  add_character('char_173_slchan', '클리프하트', v_r5, NULL);
  add_character('char_174_slbell', '프라마닉스', v_r5, NULL);
  add_character('char_194_leto', '레토', v_r5, 'S');
  add_character('char_195_glassb', '이스티나', v_r5, NULL);
  add_character('char_201_moeshd', '크루아상', v_r5, NULL);
  add_character('char_204_platnm', '플래티넘', v_r5, NULL);
  add_character('char_214_kafka', '카프카', v_r5, NULL);
  add_character('char_215_mantic', '맨티코어', v_r5, NULL);
  add_character('char_218_cuttle', '안드레아나', v_r5, NULL);
  add_character('char_219_meteo', '메테오라이트', v_r5, NULL);
  add_character('char_226_hmau', '훔', v_r5, NULL);
  add_character('char_241_panda', '에프이터', v_r5, NULL);
  add_character('char_242_otter', '메이어', v_r5, NULL);
  add_character('char_243_waaifu', '와이후', v_r5, NULL);
  add_character('char_254_vodfox', '샤마르', v_r5, NULL);
  add_character('char_261_sddrag', '리드', v_r5, NULL);
  add_character('char_274_astesi', '아스테시아', v_r5, NULL);
  add_character('char_279_excu', '이그제큐터', v_r5, NULL);
  add_character('char_294_ayer', '에이어스카르페', v_r5, NULL);
  add_character('char_297_hamoni', '아르모니', v_r5, 'S');
  add_character('char_306_leizi', '레이즈', v_r5, NULL);
  add_character('char_308_swire', '스와이어', v_r5, NULL);
  add_character('char_326_glacus', '글라우쿠스', v_r5, NULL);
  add_character('char_338_iris', '아이리스', v_r5, NULL);
  add_character('char_341_sntlla', '산탈라', v_r5, 'S');
  add_character('char_343_tknogi', '츠키노기', v_r5, NULL);
  add_character('char_344_beewax', '비즈왁스', v_r5, NULL);
  add_character('char_346_aosta', '아오스타', v_r5, NULL);
  add_character('char_349_chiave', '키아베', v_r5, NULL);
  add_character('char_356_broca', '브로카', v_r5, NULL);
  add_character('char_363_toddi', '토디폰스', v_r5, NULL);
  add_character('char_365_aprl', '에이프릴', v_r5, NULL);
  add_character('char_367_swllow', '그레이스롯', v_r5, NULL);
  add_character('char_373_lionhd', '레온하르트', v_r5, NULL);
  add_character('char_378_asbest', '아스베스토스', v_r5, NULL);
  add_character('char_379_sesa', '세사', v_r5, NULL);
  add_character('char_401_elysm', '엘리시움', v_r5, NULL);
  add_character('char_415_flint', '플린트', v_r5, NULL);
  add_character('char_421_crow', '라 플루마', v_r5, NULL);
  add_character('char_422_aurora', '오로라', v_r5, NULL);
  add_character('char_431_ashlok', '애쉬락', v_r5, NULL);
  add_character('char_433_windft', '윈드플릿', v_r5, NULL);
  add_character('char_436_whispr', '위스퍼레인', v_r5, NULL);
  add_character('char_446_aroma', '아로마', v_r5, 'S');
  add_character('char_455_nothin', '우요우', v_r5, NULL);
  add_character('char_457_blitz', 'Blitz', v_r5, NULL);
  add_character('char_458_rfrost', 'Frost', v_r5, NULL);
  add_character('char_464_cement', '시멘트', v_r5, 'S');
  add_character('char_473_mberry', '멀베리', v_r5, NULL);
  add_character('char_475_akafyu', '아카후유', v_r5, NULL);
  add_character('char_476_blkngt', '블랙나이트', v_r5, NULL);
  add_character('char_478_kirara', '키라라', v_r5, NULL);
  add_character('char_487_bobb', '보빙', v_r5, 'S');
  add_character('char_488_buildr', '폰사이러스', v_r5, 'S');
  add_character('char_489_serum', '코로세럼', v_r5, NULL);
  add_character('char_492_quercu', '퀘르쿠스', v_r5, NULL);
  add_character('char_493_firwhl', '파이어휘슬', v_r5, 'S');
  add_character('char_494_vendla', '벤델라', v_r5, 'S');
  add_character('char_497_ctable', '칸타빌레', v_r5, 'S');
  add_character('char_1022_flwr2', '퍼퓨머 더 디스틸트', v_r5, 'S');
  add_character('char_1024_hbisc2', '히비스커스 더 퓨리파이어', v_r5, NULL);
  add_character('char_1027_greyy2', '그레이 더 라이트닝베어러', v_r5, NULL);
  add_character('char_1030_noirc2', '레우스S 느와르 코르네', v_r5, NULL);
  add_character('char_1036_fang2', '팽 더 파이어 샤픈드', v_r5, 'S');
  add_character('char_1049_catap2', '진오우S 캐터펄트', v_r5, NULL);
  add_character('char_4006_melnte', '멜라나이트', v_r5, 'S');
  add_character('char_4014_lunacu', '루나컵', v_r5, 'S');
  add_character('char_4015_spuria', '스푸리아', v_r5, 'S');
  add_character('char_4016_kazema', '카제마루', v_r5, NULL);
  add_character('char_4031_liesel', '리프레사', v_r5, 'S');
  add_character('char_4032_provs', '프로바이조', v_r5, 'S');
  add_character('char_4040_rockr', '락락', v_r5, NULL);
  add_character('char_4052_surfer', '서퍼', v_r5, 'S');
  add_character('char_4071_peper', '파프리카', v_r5, 'S');
  add_character('char_4079_haini', '루실라', v_r5, 'S');
  add_character('char_4081_warmy', '워미', v_r5, 'S');
  add_character('char_4083_chimes', '윈드차임스', v_r5, 'S');
  add_character('char_4105_almond', '아몬드', v_r5, 'S');
  add_character('char_4109_baslin', '베이스라인', v_r5, 'S');
  add_character('char_4122_grabds', '그레인버즈', v_r5, 'S');
  add_character('char_4124_iana', 'Iana', v_r5, NULL);
  add_character('char_4125_rdoc', 'Doc', v_r5, NULL);
  add_character('char_4140_lasher', '샌드레코너', v_r5, 'S');
  add_character('char_4142_laios', '라이오스', v_r5, NULL);
  add_character('char_4144_chilc', '칠책', v_r5, NULL);
  add_character('char_4147_mitm', '미틈', v_r5, 'S');
  add_character('char_4155_talr', '피구리노', v_r5, 'S');
  add_character('char_4164_tecno', '테크노', v_r5, 'S');
  add_character('char_4171_wulfen', '울페나이트', v_r5, 'S');
  add_character('char_4173_nowell', '노웰', v_r5, 'S');
  add_character('char_4178_alanna', '알라나', v_r5, 'S');
  add_character('char_4183_mortis', '와카바 무츠미', v_r5, NULL);
  add_character('char_4184_dolris', '미스미 우이카', v_r5, NULL);
  add_character('char_4187_graceb', '그레이스베어러', v_r5, 'S');
  add_character('char_4191_tippi', '티피', v_r5, 'S');
  add_character('char_4196_reckpr', '레코드키퍼', v_r5, 'S');
  add_character('char_4203_kichi', '키치세이', v_r5, 'S');
  add_character('char_4207_branch', '베토치키', v_r5, 'S');
  add_character('char_4211_snhunt', '스노우헌터', v_r5, 'S');
  add_character('char_4214_cairn', '케언', v_r5, 'S');
  add_character('char_4222_taraxa', '타락사쿰', v_r5, 'S');
  add_character('char_4223_botany', '보타니', v_r5, 'S');
  add_character('char_4224_turdus', '우쿠시크', v_r5, 'S');
  add_character('char_4225_tanya', '크랙본', v_r5, 'S');
  add_character('char_109_fmout', '기타노', v_r4, 'S');
  add_character('char_110_deepcl', '딥컬러', v_r4, 'S');
  add_character('char_117_myrrh', '미르', v_r4, 'S');
  add_character('char_118_yuki', '시라유키', v_r4, 'S');
  add_character('char_126_shotst', '메테오', v_r4, 'S');
  add_character('char_127_estell', '에스텔', v_r4, 'S');
  add_character('char_130_doberm', '도베르만', v_r4, 'S');
  add_character('char_133_mm', '메이', v_r4, 'S');
  add_character('char_137_brownb', '비헌터', v_r4, 'S');
  add_character('char_141_nights', '헤이즈', v_r4, 'S');
  add_character('char_149_scave', '스캐빈저', v_r4, 'S');
  add_character('char_150_snakek', '쿠오라', v_r4, 'S');
  add_character('char_151_myrtle', '머틀', v_r4, 'S');
  add_character('char_181_flower', '퍼퓨머', v_r4, 'S');
  add_character('char_183_skgoat', '어스스피릿', v_r4, 'S');
  add_character('char_185_frncat', '무스', v_r4, 'S');
  add_character('char_190_clour', '버메일', v_r4, 'S');
  add_character('char_193_frostl', '프로스트리프', v_r4, 'S');
  add_character('char_196_sunbr', '굼', v_r4, 'S');
  add_character('char_199_yak', '마터호른', v_r4, 'S');
  add_character('char_235_jesica', '제시카', v_r4, 'S');
  add_character('char_236_rope', '로프', v_r4, 'S');
  add_character('char_237_gravel', '그라벨', v_r4, 'S');
  add_character('char_253_greyy', '그레이', v_r4, 'S');
  add_character('char_258_podego', '포덴코', v_r4, 'S');
  add_character('char_271_spikes', '아렌', v_r4, 'S');
  add_character('char_272_strong', '제이', v_r4, 'S');
  add_character('char_277_sqrrel', '쇼', v_r4, 'S');
  add_character('char_289_gyuki', '마토이마루', v_r4, 'S');
  add_character('char_290_vigna', '비그나', v_r4, 'S');
  add_character('char_298_susuro', '수수로', v_r4, 'S');
  add_character('char_301_cutter', '커터', v_r4, 'S');
  add_character('char_302_glaze', '엠브리엘', v_r4, 'S');
  add_character('char_328_cammou', '클릭', v_r4, 'S');
  add_character('char_337_utage', '우타게', v_r4, 'S');
  add_character('char_347_jaksel', '재키', v_r4, 'S');
  add_character('char_366_acdrop', '애시드드롭', v_r4, 'S');
  add_character('char_381_bubble', '버블', v_r4, 'S');
  add_character('char_440_pinecn', '파인콘', v_r4, 'S');
  add_character('char_445_wscoot', '윈드스쿠트', v_r4, 'S');
  add_character('char_452_bstalk', '빈스토크', v_r4, 'S');
  add_character('char_469_indigo', '인디고', v_r4, 'S');
  add_character('char_484_robrta', '로베르타', v_r4, 'S');
  add_character('char_491_humus', '휴머스', v_r4, 'S');
  add_character('char_4041_chnut', '체스트넛', v_r4, 'S');
  add_character('char_4062_totter', '토터', v_r4, 'S');
  add_character('char_4107_vrdant', '버던트', v_r4, 'S');
  add_character('char_4130_luton', '루토나다', v_r4, 'S');
  add_character('char_4208_wintim', '스네구로치카', v_r4, 'S');
  add_character('char_120_hibisc', '히비스커스', v_r3, 'S');
  add_character('char_121_lava', '라바', v_r3, 'S');
  add_character('char_122_beagle', '비글', v_r3, 'S');
  add_character('char_123_fang', '팽', v_r3, 'S');
  add_character('char_124_kroos', '크루스', v_r3, 'S');
  add_character('char_192_falco', '플룸', v_r3, 'S');
  add_character('char_208_melan', '멜란사', v_r3, 'S');
  add_character('char_209_ardign', '카디건', v_r3, 'S');
  add_character('char_210_stward', '스튜어드', v_r3, 'S');
  add_character('char_211_adnach', '아드나키엘', v_r3, 'S');
  add_character('char_212_ansel', '안셀', v_r3, 'S');
  add_character('char_240_wyvern', '바닐라', v_r3, 'S');
  add_character('char_278_orchid', '오키드', v_r3, 'S');
  add_character('char_281_popka', '포푸카', v_r3, 'S');
  add_character('char_282_catap', '캐터펄트', v_r3, 'S');
  add_character('char_283_midn', '미드나이트', v_r3, 'S');
  add_character('char_284_spot', '스팟', v_r3, 'S');

  -- 예시 배너 (시험용, 실제 배너 아님)
  add_banner(v_type_standard, v_rule_standard, NULL, '예시 표준 헤드헌팅',
             TIMESTAMP '2026-11-01 00:00:00', TIMESTAMP '2026-12-31 23:59:59', 'N');
  add_pickup('char_4072_ironmn', 1);
  add_pickup('char_4064_mlynar', 2);
  add_pickup('char_4105_almond', 3);
  add_pickup('char_4079_haini', 4);
  add_pickup('char_4071_peper', 5);

  add_banner(v_type_collab, v_rule_collab, 'LINKAGE_KR_42_0_5', '콜라보: 비경의 사냥꾼',
             TIMESTAMP '2026-11-16 16:00:00', TIMESTAMP '2026-11-30 03:59:59', 'Y');
  add_pickup('char_1048_orchd2', 1);

  COMMIT;
END;
/

-- ------------------------------------------------------------
-- 확인
-- ------------------------------------------------------------
-- 배너 2, 캐릭터 310, 픽업 6, 규칙 2, 확률 8, 보장 4
SELECT (SELECT COUNT(*) FROM banner)         AS banners,
       (SELECT COUNT(*) FROM game_character) AS characters,
       (SELECT COUNT(*) FROM banner_pickup)  AS pickups,
       (SELECT COUNT(*) FROM gacha_rule)     AS rules,
       (SELECT COUNT(*) FROM rule_rate)      AS rates,
       (SELECT COUNT(*) FROM rule_guarantee) AS guarantees
  FROM dual;

-- 규칙마다 기본 확률의 합이 100
SELECT g.name, SUM(r.base_rate) AS total_rate
  FROM gacha_rule g
  JOIN rule_rate r ON r.rule_id = g.rule_id
 GROUP BY g.name;

-- 풀별·등급별 캐릭터 수
SELECT p.pool_code, r.name AS rarity, COUNT(*) AS characters
  FROM character_pool p
  JOIN game_character c ON c.character_id = p.character_id
  JOIN rarity r ON r.rarity_id = c.rarity_id
 GROUP BY p.pool_code, r.name, r.rank_no
 ORDER BY p.pool_code, r.rank_no DESC;
