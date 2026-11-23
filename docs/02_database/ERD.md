# ERD

- 근거 문서 : [요구사항명세_기능.md](../01_requirements/요구사항명세_기능.md), [요구사항명세_비기능.md](../01_requirements/요구사항명세_비기능.md) (Data-001~005, Sec-001·006), [기능명세서.md](../01_requirements/기능명세서.md)
- 테이블 목록 : [테이블_도출.md](테이블_도출.md)
- 컬럼 상세 : [테이블_정의서.md](테이블_정의서.md)
- 관련 이슈 : #6
- 현재 버전 : v0.1
- 변경 내용 : v0.1 - ERD 작성
- 대상 DB : Oracle (요구사항명세_비기능.md의 개발 환경 기준)

```mermaid
erDiagram
    member ||--o{ pity_state : "천장 상태"
    member ||--o{ banner_progress : "배너 진행"
    member ||--o{ banner_guarantee_use : "보장 사용"
    member ||--o{ sim_record : "기록"
    member ||--o{ plan : "재화 계획"

    game ||--o{ server : ""
    game ||--o{ currency : ""
    game ||--o{ rarity : ""
    game ||--o{ game_character : ""
    game ||--o{ pity_group : ""
    game ||--o{ gacha_rule : ""
    game ||--o{ banner_type : ""
    game ||--o{ banner : ""
    game ||--o{ income : ""
    game ||--o{ game_event : ""
    game ||--o{ package : ""
    game ||--o{ currency_product : ""
    currency ||--o{ currency_exchange : "환산"
    currency ||--o{ pull_cost : "뽑기 비용"

    pity_group ||--o{ gacha_rule : "묶음"
    gacha_rule ||--o{ rule_rate : "등급별 확률"
    gacha_rule ||--o{ rule_pickup_share : "픽업 몫"
    gacha_rule ||--o{ rule_guarantee : "보장"
    banner_type ||--o{ banner : "종류"
    gacha_rule ||--o{ banner : "적용 규칙"
    banner ||--o{ banner_schedule : "서버별 일정"
    server ||--o{ banner_schedule : ""
    banner ||--o{ banner_pickup : "픽업"
    game_character ||--o{ banner_pickup : ""

    game_event ||--o{ event_schedule : ""
    game_event ||--o{ event_reward : ""
    package ||--o{ package_schedule : ""
    package ||--o{ package_item : ""
    game_event ||--o{ package : "이벤트 패키지"
    currency ||--o{ income : ""
    currency ||--o{ event_reward : ""
    currency ||--o{ package_item : ""
    currency ||--o{ currency_product : ""

    pity_group ||--o{ pity_state : ""
    banner ||--o{ banner_progress : ""
    banner ||--o{ banner_guarantee_use : ""
    rule_guarantee ||--o{ banner_guarantee_use : ""

    sim_record ||--o{ sim_result : "결과"
    banner ||--o{ sim_record : ""
    game_character ||--o{ sim_result : ""

    plan ||--o{ plan_currency : ""
    plan ||--o{ plan_target : ""
    plan ||--o{ plan_event : ""
    plan ||--o{ plan_package : ""
    plan ||--o{ plan_product : ""
    banner ||--o{ plan : "목표 배너"

    import_batch ||--o{ import_item : ""
```
