-- =====================================================
-- 1. MES SYSTEM
-- =====================================================
DROP DATABASE IF EXISTS mes_system;
CREATE DATABASE mes_system CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE mes_system;

CREATE TABLE LOT_INFO (
    lot_id VARCHAR(50) PRIMARY KEY,
    product_type VARCHAR(50),
    start_date DATETIME,
    lot_status VARCHAR(20)
);

CREATE TABLE PROCESS_RECIPE (
    recipe_id VARCHAR(50) PRIMARY KEY,
    product_type VARCHAR(50),
    target_temperature_c DECIMAL(5,2),
    target_force_n DECIMAL(8,2),
    bonding_time_sec DECIMAL(5,2),
    created_date DATETIME
);

CREATE TABLE PROCESS_EXECUTION (
    execution_id VARCHAR(50) PRIMARY KEY,
    lot_id VARCHAR(50),
    recipe_id VARCHAR(50),
    layer_position INT,
    execution_date DATETIME,
    operator_id VARCHAR(50),
    execution_status VARCHAR(20),
    FOREIGN KEY (lot_id) REFERENCES LOT_INFO(lot_id),
    FOREIGN KEY (recipe_id) REFERENCES PROCESS_RECIPE(recipe_id)
);

-- MES DATA
INSERT INTO LOT_INFO VALUES
('LOT_777','PROD_HBM3E_8L_30','2026-02-01 07:00:00','DONE'),
('LOT_901','PROD_HBM3E_12L_25','2026-02-15 08:00:00','DONE'),
('LOT_902','PROD_HBM3_12L_30','2026-02-16 10:30:00','DONE');

INSERT INTO PROCESS_RECIPE VALUES
('RCP_001','PROD_HBM3E_8L_30',280,450,15,'2026-02-01 08:00:00'),
('RCP_002','PROD_HBM3E_12L_25',275,420,18,'2026-02-15 08:30:00'),
('RCP_003','PROD_HBM3_12L_30',285,470,14,'2026-02-16 10:40:00');

INSERT INTO PROCESS_EXECUTION VALUES
('EXEC_001','LOT_777','RCP_001',5,'2026-02-01 10:20:00','OP_KIM','DONE'),
('EXEC_002','LOT_901','RCP_002',7,'2026-02-15 09:45:00','OP_PARK','DONE'),
('EXEC_003','LOT_902','RCP_003',3,'2026-02-16 12:00:00','OP_LEE','DONE');

-- =====================================================
-- 2. FDC SYSTEM
-- =====================================================
DROP DATABASE IF EXISTS fdc_system;
CREATE DATABASE fdc_system CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE fdc_system;

CREATE TABLE EQUIPMENT_INFO (
    equipment_id VARCHAR(50) PRIMARY KEY,
    equipment_name VARCHAR(100),
    equipment_type VARCHAR(50),
    location VARCHAR(100),
    install_date DATETIME,
    status VARCHAR(20)
);

CREATE TABLE SENSOR_DATA (
    sensor_data_id VARCHAR(50) PRIMARY KEY,
    equipment_id VARCHAR(50),
    execution_ref VARCHAR(50),
    measurement_time DATETIME,
    actual_temperature_top_c DECIMAL(5,2),
    actual_temperature_bottom_c DECIMAL(5,2),
    actual_force_n DECIMAL(8,2),
    vacuum_pressure_pa DECIMAL(8,2),
    FOREIGN KEY (equipment_id) REFERENCES EQUIPMENT_INFO(equipment_id)
);

INSERT INTO EQUIPMENT_INFO VALUES
('EQP_TC_01','TC Bonder #1','Thermocompression','FAB2','2024-01-01','ACTIVE'),
('EQP_TC_02','TC Bonder #2','Thermocompression','FAB2','2024-03-01','ACTIVE');

INSERT INTO SENSOR_DATA VALUES
('SEN_001','EQP_TC_01','EXEC_001','2026-02-01 10:30:00',289,287,452,1200),
('SEN_002','EQP_TC_02','EXEC_002','2026-02-15 09:50:00',283,280,425,1180),
('SEN_003','EQP_TC_01','EXEC_003','2026-02-16 12:10:00',295,293,472,1195);

-- =====================================================
-- 3. QMS SYSTEM
-- =====================================================
DROP DATABASE IF EXISTS qms_system;
CREATE DATABASE qms_system CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE qms_system;

CREATE TABLE INSPECTION_RESULT (
    inspection_id VARCHAR(50) PRIMARY KEY,
    execution_ref VARCHAR(50),
    inspection_time DATETIME,
    inspection_type VARCHAR(50),
    inspector_id VARCHAR(50),
    inspection_result VARCHAR(20)
);

CREATE TABLE QUALITY_MEASUREMENT (
    measurement_id VARCHAR(50) PRIMARY KEY,
    inspection_id VARCHAR(50),
    blt_average_um DECIMAL(5,2),
    blt_uniformity_percent DECIMAL(5,2),
    void_area_percent DECIMAL(5,2),
    void_count INT,
    misalignment_x_um DECIMAL(5,2),
    misalignment_y_um DECIMAL(5,2),
    warpage_um DECIMAL(6,2),
    FOREIGN KEY (inspection_id) REFERENCES INSPECTION_RESULT(inspection_id)
);

CREATE TABLE DEFECT_INFO (
    defect_id VARCHAR(50) PRIMARY KEY,
    inspection_id VARCHAR(50),
    defect_type VARCHAR(50),
    defect_severity VARCHAR(20),
    defect_description TEXT,
    pass_fail VARCHAR(10),
    FOREIGN KEY (inspection_id) REFERENCES INSPECTION_RESULT(inspection_id)
);

INSERT INTO INSPECTION_RESULT VALUES
('INS_001','EXEC_001','2026-02-01 11:00:00','X-RAY','QC_PARK','FAIL'),
('INS_002','EXEC_002','2026-02-15 10:30:00','X-RAY','QC_CHO','FAIL'),
('INS_003','EXEC_003','2026-02-16 12:40:00','X-RAY','QC_KIM','PASS');

INSERT INTO QUALITY_MEASUREMENT VALUES
('QM_001','INS_001',3.7,88,4.1,8,0.40,0.35,6.2),
('QM_002','INS_002',3.8,85,4.8,10,0.38,0.42,6.1),
('QM_003','INS_003',3.5,92,2.8,2,0.35,0.30,8.9);

INSERT INTO DEFECT_INFO VALUES
('DEF_001','INS_001','VOID','HIGH','Void 4.1%','FAIL'),
('DEF_002','INS_002','VOID','HIGH','Layer7 Void 집중','FAIL'),
('DEF_003','INS_003','NONE','NONE','정상','PASS');



-- ============================================
-- HBM TC 본딩 사전 예측 시스템 DDL (Revised)
-- MySQL 8.x 기준
-- 핵심: ML + RAG + LLM 통합 + (HISTORY를 RAG 코퍼스로 반영)
-- 추가 반영:
--  1) RAG pre-filter 최적화 인덱스/쿼리
--  2) executed_history_id로 예측↔실제 자동 매칭(학습 루프)
--  3) doc_text 최적 템플릿(짧고 검색 잘 되게)
-- ============================================

/* ============================================================
   Architecture (요약)
 
   - 입력(Recipe) → ML 예측 + RAG(Expert+History) 검색 → LLM 분석 → Prediction 저장
   - RAG는 TC_EXPERT_KNOWLEDGE / TC_BONDING_HISTORY를 직접 뒤지지 않고,
     "RAG_DOCUMENT(단일 코퍼스)"에 통합해 검색/필터링한다.

   ============================================================ */

-- 데이터베이스 생성
DROP DATABASE IF EXISTS tc_bonding_prediction;
CREATE DATABASE tc_bonding_prediction
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE tc_bonding_prediction;

-- ============================================
-- 1. HBM_PRODUCT (HBM 제품 정보)
-- ============================================
CREATE TABLE HBM_PRODUCT (
    product_id VARCHAR(50) PRIMARY KEY COMMENT '제품 ID',
    product_name VARCHAR(100) NOT NULL COMMENT '제품명',
    hbm_generation VARCHAR(20) NOT NULL COMMENT 'HBM 세대 (HBM2E, HBM3, HBM3E)',
    stack_layer_count INT NOT NULL COMMENT '적층 레이어 수 (4, 8, 12, 16)',
    die_thickness_um DECIMAL(6,2) NOT NULL COMMENT '다이 두께 (μm)',
    bonding_material VARCHAR(50) COMMENT '본딩 소재 (Cu-Cu, Hybrid)',
    created_date DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '등록일',

    INDEX idx_hbm_generation (hbm_generation),
    INDEX idx_stack_layer (stack_layer_count)
) COMMENT 'HBM 제품 마스터';


-- ============================================
-- 2. TC_BONDING_RECIPE (TC 본딩 레시피 입력)
--  * executed_history_id 자동 매칭을 위해 Run 식별 메타(LOT/LAYER/EQUIP) 추가
-- ============================================
CREATE TABLE TC_BONDING_RECIPE (
    recipe_id VARCHAR(50) PRIMARY KEY COMMENT '레시피 ID',
    product_id VARCHAR(50) NOT NULL COMMENT '제품 ID',
    input_time DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '입력 시각',

    -- Run 매칭용 메타데이터 (현장 적용시 매우 중요)
    lot_id VARCHAR(50) NULL COMMENT '로트 ID (실제 Run 매칭용)',
    layer_position INT NULL COMMENT '레이어 위치 (실제 Run 매칭용)',
    equipment_id VARCHAR(50) NULL COMMENT '장비 ID (실제 Run 매칭용)',

    -- TC 핵심 파라미터
    bonding_temperature_c DECIMAL(5,2) NOT NULL COMMENT '본딩 온도 (°C)',
    bonding_force_n DECIMAL(8,2) NOT NULL COMMENT '본딩 압력 (N)',
    bonding_time_sec DECIMAL(5,2) NOT NULL COMMENT '본딩 시간 (초)',

    -- 추가 파라미터
    approach_speed_um_s DECIMAL(8,2) COMMENT '접근 속도 (μm/s)',
    alignment_tolerance_um DECIMAL(5,2) COMMENT '정렬 허용 오차 (μm)',
    hold_time_sec DECIMAL(5,2) COMMENT '압력 유지 시간 (초)',
    input_by VARCHAR(50) COMMENT '입력자',

    CONSTRAINT fk_recipe_product
      FOREIGN KEY (product_id) REFERENCES HBM_PRODUCT(product_id),

    INDEX idx_input_time (input_time),
    INDEX idx_product (product_id),
    INDEX idx_recipe_match (product_id, lot_id, layer_position, equipment_id, input_time)
) COMMENT 'TC 본딩 레시피 입력 (예측 요청 입력)';


-- ============================================
-- 3. TC_BONDING_HISTORY (과거/실제 TC 본딩 이력)
--  * ML 학습 + RAG 코퍼스 원천(=RAG_DOCUMENT로 들어감)
--    여기서는 "실행 가능한" 스키마로 테이블 정의
-- ============================================
-- =============================================
-- TC_BONDING_HISTORY 테이블 생성 및 설정
-- =============================================

-- 1. 테이블 생성
CREATE TABLE TC_BONDING_HISTORY AS
SELECT
    pe.execution_id                  AS history_id,
    pr.product_type                  AS product_id,
    pe.lot_id,
    pe.layer_position,
    pe.execution_date                AS bonding_date,
    pr.target_temperature_c          AS recipe_temperature_c,
    pr.target_force_n                AS recipe_force_n,
    pr.bonding_time_sec              AS recipe_time_sec,
    sd.actual_temperature_top_c      AS actual_peak_temperature_c,
    sd.actual_force_n                AS actual_peak_force_n,
    sd.vacuum_pressure_pa            AS vacuum_level_pa,
    qm.blt_average_um,
    qm.void_area_percent,
    qm.misalignment_x_um,
    qm.misalignment_y_um,
    qm.warpage_um,
    CASE WHEN di.pass_fail = 'PASS' THEN 'A' ELSE 'C' END AS grade,
    di.pass_fail,
    sd.equipment_id,
    'MES+FDC+QMS'                   AS data_source
FROM mes_system.PROCESS_EXECUTION pe
JOIN mes_system.PROCESS_RECIPE pr
    ON pe.recipe_id = pr.recipe_id
LEFT JOIN fdc_system.SENSOR_DATA sd
    ON pe.execution_id = sd.execution_ref
LEFT JOIN qms_system.INSPECTION_RESULT ir
    ON pe.execution_id = ir.execution_ref
LEFT JOIN qms_system.QUALITY_MEASUREMENT qm
    ON ir.inspection_id = qm.inspection_id
LEFT JOIN qms_system.DEFECT_INFO di
    ON ir.inspection_id = di.inspection_id
WHERE pe.execution_date >= DATE_SUB(NOW(), INTERVAL 1 YEAR);


-- 2. 테이블 코멘트
ALTER TABLE TC_BONDING_HISTORY
    COMMENT = 'TC 본딩 과거 이력 (MES+FDC+QMS 통합 데이터, 최근 1년)';


-- 3. 컬럼 코멘트 설정
ALTER TABLE TC_BONDING_HISTORY
    MODIFY history_id               VARCHAR(50)    NOT NULL COMMENT '이력 ID (MES Execution ID)',
    MODIFY product_id               VARCHAR(50)             COMMENT '제품 ID',
    MODIFY lot_id                   VARCHAR(50)             COMMENT '로트 ID',
    MODIFY layer_position           INT                     COMMENT '레이어 위치',
    MODIFY bonding_date             DATETIME                COMMENT '본딩 일시',
    MODIFY recipe_temperature_c     DECIMAL(5,2)            COMMENT '레시피 설정 온도 (°C)',
    MODIFY recipe_force_n           DECIMAL(8,2)            COMMENT '레시피 설정 압력 (N)',
    MODIFY recipe_time_sec          DECIMAL(5,2)            COMMENT '레시피 설정 시간 (초)',
    MODIFY actual_peak_temperature_c DECIMAL(5,2)           COMMENT '실측 최고 온도 (°C)',
    MODIFY actual_peak_force_n      DECIMAL(8,2)            COMMENT '실측 최대 압력 (N)',
    MODIFY vacuum_level_pa          DECIMAL(6,2)            COMMENT '진공도 (Pa)',
    MODIFY blt_average_um           DECIMAL(5,2)            COMMENT 'BLT 평균 (μm)',
    MODIFY void_area_percent        DECIMAL(5,2)            COMMENT 'Void 면적 비율 (%)',
    MODIFY misalignment_x_um        DECIMAL(5,2)            COMMENT 'X축 정렬 오차 (μm)',
    MODIFY misalignment_y_um        DECIMAL(5,2)            COMMENT 'Y축 정렬 오차 (μm)',
    MODIFY warpage_um               DECIMAL(6,2)            COMMENT 'Warpage (μm)',
    MODIFY grade                    VARCHAR(2)              COMMENT '품질 등급 (A/B/C/D)',
    MODIFY pass_fail                VARCHAR(10)             COMMENT '합격 여부 (PASS/FAIL)',
    MODIFY equipment_id             VARCHAR(50)             COMMENT '장비 ID',
    MODIFY data_source              VARCHAR(50)             COMMENT '데이터 출처';


-- 4. PK 및 인덱스 추가
ALTER TABLE TC_BONDING_HISTORY
    ADD PRIMARY KEY (history_id),
    ADD INDEX idx_product_layer (product_id, layer_position);
    
-- 불일치 id 제거
DELETE FROM TC_BONDING_HISTORY
WHERE product_id NOT IN (
    SELECT product_id FROM HBM_PRODUCT
);

-- 5. 외래키 추가
ALTER TABLE TC_BONDING_HISTORY
    ADD CONSTRAINT fk_product
        FOREIGN KEY (product_id) REFERENCES HBM_PRODUCT(product_id);


-- 6. Vector DB 컬럼 및 인덱스 추가
ALTER TABLE TC_BONDING_HISTORY
    ADD COLUMN vector_db_id VARCHAR(100) NULL COMMENT 'Vector DB ID (History RAG용)' AFTER data_source,
    ADD INDEX idx_vector_db (vector_db_id);


-- =============================================
-- 검증 쿼리
-- =============================================

-- 7. MES 원본 건수 확인
SELECT COUNT(DISTINCT execution_id)
FROM mes_system.PROCESS_EXECUTION
WHERE execution_date >= DATE_SUB(NOW(), INTERVAL 1 YEAR);

-- 8. 이관된 건수 확인
SELECT COUNT(DISTINCT history_id)
FROM tc_bonding_prediction.TC_BONDING_HISTORY;

-- 9. 누락 데이터 확인 (MES에는 있으나 이력 테이블에 없는 건)
SELECT pe.execution_id
FROM mes_system.PROCESS_EXECUTION pe
LEFT JOIN tc_bonding_prediction.TC_BONDING_HISTORY th
    ON pe.execution_id = th.history_id
WHERE pe.execution_date >= DATE_SUB(NOW(), INTERVAL 1 YEAR)
  AND th.history_id IS NULL;

-- 10. 중복 데이터 확인
SELECT history_id, COUNT(*)
FROM tc_bonding_prediction.TC_BONDING_HISTORY
GROUP BY history_id
HAVING COUNT(*) > 1;

-- 11. 온도 평균 비교 (MES 원본)
SELECT ROUND(AVG(pr.target_temperature_c), 2)
FROM mes_system.PROCESS_EXECUTION pe
JOIN mes_system.PROCESS_RECIPE pr
    ON pe.recipe_id = pr.recipe_id
WHERE pe.execution_date >= DATE_SUB(NOW(), INTERVAL 1 YEAR);

-- 12. 온도 평균 비교 (이력 테이블)
SELECT ROUND(AVG(recipe_temperature_c), 2)
FROM tc_bonding_prediction.TC_BONDING_HISTORY;

-- 13. 특정 샘플 데이터 확인
SELECT *
FROM tc_bonding_prediction.TC_BONDING_HISTORY
WHERE history_id IN ('EXEC_001', 'EXEC_002');

-- ============================================
-- 4. TC_EXPERT_KNOWLEDGE (전문가 지식 원천)
--  * RAG 코퍼스로는 RAG_DOCUMENT에 upsert되어 사용
-- ============================================
CREATE TABLE TC_EXPERT_KNOWLEDGE (
    knowledge_id VARCHAR(50) PRIMARY KEY COMMENT '지식 ID',
    knowledge_type ENUM('BEST_PRACTICE', 'TROUBLESHOOTING', 'DEFECT_CASE', 'RECIPE_TIP', 'EQUIPMENT_TIP')
        NOT NULL COMMENT '지식 유형',
    title VARCHAR(200) NOT NULL COMMENT '제목',
    expert_name VARCHAR(100) NOT NULL COMMENT '전문가 이름',
    expert_level ENUM('MASTER', 'SENIOR_EXPERT', 'EXPERT', 'ENGINEER')
        NOT NULL COMMENT '전문가 레벨',
    created_date DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '작성일',

    situation_description TEXT NOT NULL COMMENT '상황 설명(임베딩 대상)',
    problem_symptom TEXT COMMENT '문제 증상(임베딩 대상)',
    root_cause_analysis TEXT COMMENT '원인 분석(임베딩 대상)',
    solution_action TEXT NOT NULL COMMENT '해결 방법',
    recipe_recommendation TEXT COMMENT '레시피 권장값',
    caution_note TEXT COMMENT '주의사항',

    related_product_id VARCHAR(50) NULL COMMENT '관련 제품 ID',

    CONSTRAINT fk_expert_product
      FOREIGN KEY (related_product_id) REFERENCES HBM_PRODUCT(product_id),

    INDEX idx_knowledge_type (knowledge_type),
    INDEX idx_expert_level (expert_level),
    INDEX idx_created_date (created_date),

    FULLTEXT idx_fulltext_search (title, situation_description, problem_symptom)
) COMMENT 'TC 본딩 전문가 지식(원천)';


-- ============================================
-- 5. RAG_DOCUMENT (단일 RAG 코퍼스: Expert + History)
--  * "HISTORY를 RAG로 빼둔 구조"의 핵심 반영 테이블
--  * Pre-filter 최적화 인덱스 포함
-- ============================================
CREATE TABLE RAG_DOCUMENT (
    rag_doc_id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT 'RAG 문서 내부 ID',
    rag_doc_key VARCHAR(80) NOT NULL COMMENT '유니크 키 (예: EXPERT:EK_001, HISTORY:HIS_123)',
    source_type ENUM('EXPERT','HISTORY') NOT NULL COMMENT '원천 타입',
    source_id VARCHAR(50) NOT NULL COMMENT '원천 PK (knowledge_id 또는 history_id)',

    -- Vector DB 연동
    vector_db_id VARCHAR(120) NULL COMMENT 'Vector DB ID (Pinecone/Chroma 등)',
    embedding_model VARCHAR(60) NULL COMMENT '임베딩 모델명',
    indexed_at DATETIME NULL COMMENT '인덱싱 완료 시각',
    index_status ENUM('PENDING','INDEXED','FAILED') DEFAULT 'PENDING' COMMENT '인덱싱 상태',

    -- RAG filter용 메타데이터 (요구사항)
    product_id VARCHAR(50) NULL COMMENT '제품 ID',
    layer_position INT NULL COMMENT '레이어',
    equipment_id VARCHAR(50) NULL COMMENT '장비',
    pass_fail VARCHAR(10) NULL COMMENT 'PASS/FAIL',
    bonding_date DATETIME NULL COMMENT 'History일 때 실행 시각(정렬용)',

    -- 검색 텍스트(짧고 강하게)
    doc_text TEXT NOT NULL COMMENT '임베딩/검색용 텍스트(최적 템플릿)',
    content_hash CHAR(64) NOT NULL COMMENT '내용 변경 감지(SHA2-256)',

    -- 제약/인덱스
    UNIQUE KEY uk_rag_doc_key (rag_doc_key),
    INDEX idx_vector_db_id (vector_db_id),

    -- ✅ pre-filter 최적화: product/layer/equipment/pass_fail + date 정렬
    INDEX idx_rag_prefilter (source_type, product_id, layer_position, equipment_id, pass_fail, bonding_date),

    -- 인덱싱 작업 큐 조회용
    INDEX idx_rag_index_queue (index_status, source_type, indexed_at),

    -- (선택) SQL fallback 검색용 (BM25 대체: MySQL FULLTEXT)
    FULLTEXT idx_rag_doc_text (doc_text)
) COMMENT '단일 RAG 코퍼스(Expert + History 통합)';


-- ============================================
-- 6. TC_SUCCESS_PREDICTION (예측 결과)
--  * executed_history_id로 예측→실제 자동 매칭(학습 루프)
-- ============================================
CREATE TABLE TC_SUCCESS_PREDICTION (
    prediction_id VARCHAR(50) PRIMARY KEY COMMENT '예측 ID',
    recipe_id VARCHAR(50) NOT NULL COMMENT '레시피 입력 ID',
    product_id VARCHAR(50) NOT NULL COMMENT '제품 ID',
    prediction_time DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '예측 시각',

    model_name VARCHAR(100) NULL COMMENT '사용 모델명',

    -- 예측 결과
    estimated_success_score DECIMAL(6,4) NOT NULL COMMENT '성공 확률(0~1)',
    predicted_blt_um DECIMAL(6,2) NULL COMMENT '예측 BLT(μm)',
    predicted_void_percent DECIMAL(6,2) NULL COMMENT '예측 Void(%)',
    predicted_warpage_um DECIMAL(8,2) NULL COMMENT '예측 Warpage(μm)',
    risk_level ENUM('HIGH','MEDIUM','LOW') NOT NULL COMMENT '리스크 레벨',
    confidence_score DECIMAL(6,4) NULL COMMENT '신뢰도',

    -- 권장사항/근거
    recommended_recipe_change TEXT NULL COMMENT '권장 레시피 조정',
    rag_evidence_ids JSON NULL COMMENT 'RAG 근거(문서/사례 ID 목록)',
    llm_analysis TEXT NULL COMMENT 'LLM 종합 분석(근거 포함)',

    -- ✅ 학습 루프: 실제 실행 Run과 연결
    executed_history_id VARCHAR(50) NULL COMMENT '실제 Run(history_id) 매칭 값',
    executed_at DATETIME NULL COMMENT '실제 본딩 시각',

    -- 실제 품질/판정(학습/평가용)
    actual_pass_fail VARCHAR(10) NULL COMMENT '실제 PASS/FAIL',
    actual_blt_um DECIMAL(6,2) NULL COMMENT '실제 BLT(μm)',
    actual_void_percent DECIMAL(6,2) NULL COMMENT '실제 Void(%)',
    actual_warpage_um DECIMAL(8,2) NULL COMMENT '실제 Warpage(μm)',

    closed_loop_status ENUM('OPEN','MATCHED','CLOSED') DEFAULT 'OPEN' COMMENT '루프 상태(OPEN→MATCHED→CLOSED)',

    CONSTRAINT fk_pred_recipe
      FOREIGN KEY (recipe_id) REFERENCES TC_BONDING_RECIPE(recipe_id),
    CONSTRAINT fk_pred_product
      FOREIGN KEY (product_id) REFERENCES HBM_PRODUCT(product_id),
    CONSTRAINT fk_pred_history
      FOREIGN KEY (executed_history_id) REFERENCES TC_BONDING_HISTORY(history_id),

    INDEX idx_prediction_time (prediction_time),
    INDEX idx_risk_level (risk_level),
    INDEX idx_recipe (recipe_id),
    INDEX idx_product (product_id),
    INDEX idx_exec_history (executed_history_id)
) COMMENT 'TC 본딩 예측 결과(폐루프 학습 연결 포함)';


-- ============================================
-- 7. PREDICTION_LOG (처리 로그)
-- ============================================
CREATE TABLE PREDICTION_LOG (
    log_id VARCHAR(50) PRIMARY KEY COMMENT '로그 ID',
    prediction_id VARCHAR(50) NOT NULL COMMENT '예측 ID',
    log_time DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '로그 시각',

    ml_processing_time_ms INT NULL COMMENT 'ML 처리 시간(ms)',
    rag_processing_time_ms INT NULL COMMENT 'RAG 처리 시간(ms)',
    llm_processing_time_ms INT NULL COMMENT 'LLM 처리 시간(ms)',
    total_processing_time_ms INT NULL COMMENT '전체 처리 시간(ms)',

    vector_search_count INT NULL COMMENT 'Vector 검색 횟수',
    llm_call_count INT NULL COMMENT 'LLM 호출 횟수',
    llm_tokens_used INT NULL COMMENT 'LLM 토큰 사용량',

    -- (가볍게 유지) 상세는 JSON으로 바꿔도 됨
    rag_doc_keys VARCHAR(800) NULL COMMENT 'RAG로 사용된 문서키(쉼표 구분)',
    error_message TEXT NULL COMMENT '에러 메시지',
    log_level ENUM('INFO','WARNING','ERROR','CRITICAL') DEFAULT 'INFO' COMMENT '로그 레벨',

    CONSTRAINT fk_log_pred
      FOREIGN KEY (prediction_id) REFERENCES TC_SUCCESS_PREDICTION(prediction_id) ON DELETE CASCADE,

    INDEX idx_prediction (prediction_id),
    INDEX idx_log_time (log_time),
    INDEX idx_log_level (log_level)
) COMMENT '예측 처리 로그(ML/RAG/LLM)';




-- ============================================================
-- (1) RAG 검색 필터 최적화 쿼리 예시
--     product/layer/equipment/pass_fail 기반 pre-filter + top-k
-- ============================================================


-- [Pre-filter] 후보 문서만 먼저 추리기 (예: 최대 200개)
SELECT 
    rag_doc_key, source_type, source_id, vector_db_id, bonding_date 
FROM RAG_DOCUMENT 
WHERE source_type IN ('HISTORY','EXPERT') 
    -- 실제 확인하고 싶은 제품 ID와 조건을 작은따옴표 안에 넣으세요.
    AND product_id = 'PROD_HBM3E_8L_30' 
    AND (NULL IS NULL OR layer_position = NULL) 
    AND (NULL IS NULL OR equipment_id = NULL) 
    AND (NULL IS NULL OR pass_fail = NULL) 
ORDER BY 
    (source_type='EXPERT') DESC, 
    bonding_date DESC 
LIMIT 200;

-- [Top-k] (SQL fallback: FULLTEXT) - Vector DB가 아니라 SQL에서 키워드 top-k 뽑을 때
USE tc_bonding_prediction;

SELECT 
    rag_doc_key, 
    source_type, 
    source_id,
    -- 'query' 글자 대신 실제 검색어(예: 'Void')를 작은따옴표 안에 넣으세요.
    MATCH(doc_text) AGAINST('Void' IN NATURAL LANGUAGE MODE) AS score 
FROM RAG_DOCUMENT 
-- 'product_id' 글자 대신 실제 제품 ID를 넣어야 정확히 필터링됩니다.
WHERE product_id = 'PROD_HBM3E_8L_30' 
  AND (NULL IS NULL OR layer_position = NULL) 
  AND (NULL IS NULL OR equipment_id = NULL)
  AND (NULL IS NULL OR pass_fail = NULL) 
  -- 여기도 마찬가지로 실제 검색어를 넣으세요.
  AND MATCH(doc_text) AGAINST('Void' IN NATURAL LANGUAGE MODE) 
ORDER BY score DESC 
LIMIT 5;



-- ============================================================
-- (2) 예측→실제 자동 매칭 SQL (executed_history_id 채우기)
--     - MySQL 8 Window Function 사용(ROW_NUMBER)
--     - 조건: (product + lot/layer/equip + 시간윈도우 + 파라미터 tolerance)
-- ============================================================


-- tolerance 및 시간 윈도우는 현장에 맞게 조정
USE tc_bonding_prediction;

-- [1] 오차 범위 변수 설정 (반드시 쿼리와 함께 실행해야 합니다)
SET @tol_temp := 1.0;    -- 온도 허용 오차 (°C)
SET @tol_force := 10.0;  -- 압력 허용 오차 (N)
SET @tol_time := 1.0;    -- 시간 허용 오차 (sec)
SET @win_hours := 24;    -- 매칭 시간 윈도우

-- [2] 서브쿼리를 이용한 UPDATE JOIN 실행
UPDATE TC_SUCCESS_PREDICTION p
JOIN (
    -- 가장 적합한 이력을 찾아 순번을 매기는 로직을 서브쿼리로 구성
    SELECT 
        p_sub.prediction_id,
        h_sub.history_id,
        ROW_NUMBER() OVER (
            PARTITION BY p_sub.prediction_id
            ORDER BY ABS(TIMESTAMPDIFF(SECOND, h_sub.bonding_date, r_sub.input_time))
        ) AS rn
    FROM TC_SUCCESS_PREDICTION p_sub
    JOIN TC_BONDING_RECIPE r_sub ON p_sub.recipe_id = r_sub.recipe_id
    JOIN TC_BONDING_HISTORY h_sub ON h_sub.product_id = r_sub.product_id
    WHERE p_sub.executed_history_id IS NULL
      AND (r_sub.lot_id IS NULL OR h_sub.lot_id = r_sub.lot_id)
      AND (r_sub.layer_position IS NULL OR h_sub.layer_position = r_sub.layer_position)
      AND (r_sub.equipment_id IS NULL OR h_sub.equipment_id = r_sub.equipment_id)
      AND h_sub.bonding_date BETWEEN r_sub.input_time AND DATE_ADD(r_sub.input_time, INTERVAL @win_hours HOUR)
      AND (h_sub.recipe_temperature_c IS NULL OR ABS(h_sub.recipe_temperature_c - r_sub.bonding_temperature_c) <= @tol_temp)
      AND (h_sub.recipe_force_n IS NULL OR ABS(h_sub.recipe_force_n - r_sub.bonding_force_n) <= @tol_force)
      AND (h_sub.recipe_time_sec IS NULL OR ABS(h_sub.recipe_time_sec - r_sub.bonding_time_sec) <= @tol_time)
) AS c ON p.prediction_id = c.prediction_id AND c.rn = 1
JOIN TC_BONDING_HISTORY h ON h.history_id = c.history_id
SET
  p.executed_history_id = h.history_id,
  p.executed_at         = h.bonding_date,
  p.actual_pass_fail    = h.pass_fail,
  p.actual_blt_um       = h.blt_average_um,
  p.actual_void_percent = h.void_area_percent,
  p.actual_warpage_um   = h.warpage_um,
  p.closed_loop_status  = 'MATCHED'
WHERE p.executed_history_id IS NULL;

-- (선택) 매칭 후, 루프를 CLOSED로 바꾸는 조건은 현장 룰에 맞게:
-- 예: QMS 결과까지 들어왔고 pass_fail이 확정이면 CLOSED
UPDATE TC_SUCCESS_PREDICTION
SET closed_loop_status = 'CLOSED'
WHERE closed_loop_status = 'MATCHED'
  AND actual_pass_fail IS NOT NULL;



-- ============================================================
-- View (조회 편의)
-- ============================================================

CREATE OR REPLACE VIEW v_prediction_detail AS
SELECT
    p.prediction_id,
    p.prediction_time,
    prod.product_name,
    prod.hbm_generation,
    r.lot_id,
    r.layer_position,
    r.equipment_id,
    r.bonding_temperature_c AS input_temperature,
    r.bonding_force_n AS input_force,
    r.bonding_time_sec AS input_time_sec,

    p.estimated_success_score,
    p.risk_level,
    p.model_name,
    p.recommended_recipe_change,

    p.executed_history_id,
    p.actual_pass_fail,
    p.actual_blt_um,
    p.actual_void_percent,
    p.actual_warpage_um,

    l.total_processing_time_ms,
    l.llm_tokens_used
FROM TC_SUCCESS_PREDICTION p
JOIN TC_BONDING_RECIPE r
  ON p.recipe_id = r.recipe_id
JOIN HBM_PRODUCT prod
  ON p.product_id = prod.product_id
LEFT JOIN PREDICTION_LOG l
  ON p.prediction_id = l.prediction_id;


-- ============================================
-- 샘플 데이터 (실행 확인용)
-- ============================================

-- 제품
INSERT INTO HBM_PRODUCT (product_id, product_name, hbm_generation, stack_layer_count, die_thickness_um, bonding_material)
VALUES
('PROD_HBM3E_8L_30', 'HBM3E-8L-30um', 'HBM3E', 8, 30.00, 'Cu-Cu'),
('PROD_HBM3E_12L_25', 'HBM3E-12L-25um', 'HBM3E', 12, 25.00, 'Hybrid'),
('PROD_HBM3E_16L_25', 'HBM3E-16L-25um', 'HBM3E', 16, 25.00, 'Hybrid'),
('PROD_HBM3_12L_30','HBM3-12L-30um','HBM3',12,30.00,'Hybrid'),
('PROD_HBM2E_8L_40','HBM2E-8L-40um','HBM2E',8,40.00,'Cu-Cu');

-- 레시피 입력(예측 요청)
INSERT INTO TC_BONDING_RECIPE (
  recipe_id, product_id, input_time,
  lot_id, layer_position, equipment_id,
  bonding_temperature_c, bonding_force_n, bonding_time_sec,
  approach_speed_um_s, alignment_tolerance_um, hold_time_sec, input_by
) VALUES
('RECIPE_001', 'PROD_HBM3E_8L_30', '2026-02-12 10:00:00', 'LOT_777', 5, 'EQP_TC_01',
 280.00, 450.00, 15.00, 300.00, 0.50, 3.00, 'engineer_kim'),

 ('RECIPE_002','PROD_HBM3E_12L_25','2026-02-15 09:10:00','LOT_901',7,'EQP_TC_02',
 275.00, 420.00, 18.00, 280.00, 0.45, 4.00,'engineer_park'),

('RECIPE_003','PROD_HBM3_12L_30','2026-02-16 11:30:00','LOT_902',3,'EQP_TC_01',
 285.00, 470.00, 14.00, 310.00, 0.40, 3.50,'engineer_lee'),

('RECIPE_004','PROD_HBM2E_8L_40','2026-02-17 08:50:00','LOT_903',6,'EQP_TC_03',
 265.00, 400.00, 20.00, 260.00, 0.60, 5.00,'engineer_kim');

-- 실제 이력(나중에 들어온다고 가정)
INSERT INTO TC_BONDING_HISTORY (
  history_id, product_id, lot_id, layer_position, bonding_date, equipment_id,
  recipe_temperature_c, recipe_force_n, recipe_time_sec,
  actual_peak_temperature_c, actual_peak_force_n, vacuum_level_pa,
  blt_average_um, void_area_percent, misalignment_x_um, misalignment_y_um, warpage_um,
  grade, pass_fail
) VALUES
('HIS_9001', 'PROD_HBM3E_8L_30', 'LOT_777', 5, '2026-02-12 10:40:00', 'EQP_TC_01',
 280.00, 450.00, 15.00,
 289.00, 452.00, 1200.00,
 3.70, 4.10, 0.40, 0.35, 6.20,
 'C', 'FAIL'),

 -- 정상 사례 (HBM2E 안정)
('HIS_9101','PROD_HBM2E_8L_40','LOT_903',6,'2026-02-17 09:30:00','EQP_TC_03',
 265.00,400.00,20.00,
 267.50,398.00,1150.00,
 3.10,1.20,0.20,0.25,3.80,
 'A','PASS'),

-- 고레이어 + EQP_TC_02 → Void 증가
('HIS_9102','PROD_HBM3E_12L_25','LOT_901',7,'2026-02-15 09:50:00','EQP_TC_02',
 275.00,420.00,18.00,
 283.20,425.00,1180.00,
 3.80,4.80,0.38,0.42,6.10,
 'C','FAIL'),

-- 온도 과상승 → Warpage 증가
('HIS_9103','PROD_HBM3_12L_30','LOT_902',3,'2026-02-16 12:10:00','EQP_TC_01',
 285.00,470.00,14.00,
 295.00,472.00,1195.00,
 3.50,2.80,0.35,0.30,8.90,
 'B','PASS'),

-- 16L → 누적 열로 warpage 심화
('HIS_9104','PROD_HBM3E_16L_25','LOT_904',12,'2026-02-18 14:40:00','EQP_TC_02',
 278.00,430.00,17.00,
 290.50,438.00,1170.00,
 4.20,5.50,0.45,0.48,10.50,
 'D','FAIL'),

-- 안정적 조건
('HIS_9105','PROD_HBM3E_12L_25','LOT_905',4,'2026-02-19 10:20:00','EQP_TC_01',
 272.00,410.00,16.00,
 274.80,408.00,1205.00,
 3.30,1.50,0.28,0.26,4.10,
 'A','PASS');

-- 전문가 지식
INSERT INTO TC_EXPERT_KNOWLEDGE (
  knowledge_id, knowledge_type, title, expert_name, expert_level, created_date,
  situation_description, problem_symptom, root_cause_analysis, solution_action,
  recipe_recommendation, caution_note, related_product_id
) VALUES
('EK_001', 'TROUBLESHOOTING', 'HBM3E 5층 Void 다발 해결',
 '김철수', 'MASTER', '2025-11-15 14:30:00',
 'HBM3E 8층 제품, 5층에서 Void 지속',
 '5층부터 공극(Void) 증가, 중앙부 집중',
 '누적 열로 실제 온도 상승(과열)',
 '온도 -7C, 시간 +3s, 압력 -20N, Chuck 점검',
 'Layer5~8: 273C/430N/18s',
 '급격한 온도변화 금지',
 'PROD_HBM3E_8L_30'),

 ('EK_002','DEFECT_CASE','HBM3E 고레이어 Void 급증 사례',
 '박성민','SENIOR_EXPERT',  '2025-12-01 10:00:00',
 'HBM3E 12~16층 제품에서 고레이어 Void 집중 발생',
 'Layer 7 이상에서 Void 4% 초과',
 '상부 열 누적 및 장비 온도 overshoot',
 '온도 -5~8C 조정, 진공 안정화, Pre-heat 시간 단축',
 '273C / 410N / 18s',
 '고레이어는 온도 ramp rate 1.5C/sec 이하 유지',
 'PROD_HBM3E_12L_25'),

('EK_003','RECIPE_TIP','HBM2E 저온 안정 공정 가이드',
 '이준호','MASTER',  '2025-12-03 10:00:00',
 'HBM2E 제품은 과도한 온도 상승 불필요',
 '과열 시 BLT 증가 및 미세 void 발생',
 'die 두께 40um는 열 확산 안정적',
 '265C 유지, 압력 400N 이하 권장',
 '265C / 395N / 20s',
 '과도한 압력은 die crack 위험',
 'PROD_HBM2E_8L_40');

-- 예측 결과(예측 시점)
INSERT INTO TC_SUCCESS_PREDICTION (
  prediction_id, recipe_id, product_id, prediction_time,
  model_name, estimated_success_score, predicted_blt_um, predicted_void_percent, predicted_warpage_um,
  risk_level, confidence_score,
  recommended_recipe_change, rag_evidence_ids, llm_analysis
) VALUES
('PRED_001', 'RECIPE_001', 'PROD_HBM3E_8L_30', '2026-02-12 10:05:00',
 'XGBoost_v1.0', 0.6800, 3.70, 4.10, 6.20,
 'HIGH', 0.8200,
 '온도 273C(-7C), 압력 430N(-20N), 시간 18s(+3s)',
 JSON_ARRAY('EK_001','HISTORY:HIS_9001'),
 '리스크: 5층 누적열 과열 → Void 증가 가능. 전문가 사례(EK_001)와 유사.'),

 ('PRED_002','RECIPE_002','PROD_HBM3E_12L_25', '2026-02-12 10:10:00',
 'XGBoost_v1.1',0.5200,
 3.90,4.50,6.80,
 'HIGH',0.78,
 '온도 -6C, 압력 -10N',
 JSON_ARRAY('EK_002','HISTORY:HIS_9102'),
 '고레이어 누적 열로 Void 증가 가능성 높음.'),

('PRED_003','RECIPE_003','PROD_HBM3_12L_30', '2026-02-14 10:10:00',
 'XGBoost_v1.1',0.7600,
 3.40,2.50,7.50,
 'MEDIUM',0.81,
 '온도 -3C 조정 권장',
 JSON_ARRAY('HISTORY:HIS_9103'),
 '온도 overshoot로 Warpage 상승 경향.');

-- 로그
INSERT INTO PREDICTION_LOG (
  log_id, prediction_id, log_time,
  ml_processing_time_ms, rag_processing_time_ms, llm_processing_time_ms, total_processing_time_ms,
  vector_search_count, llm_call_count, llm_tokens_used,
  rag_doc_keys, error_message, log_level
) VALUES
('LOG_001', 'PRED_001', '2026-02-12 10:05:00',
 45, 320, 1850, 2215,
 2, 1, 1250,
 'EXPERT:EK_001,HISTORY:HIS_9001',
 NULL, 'INFO'),

('LOG_002', 'PRED_002', '2026-02-15 09:12:10',
 52, 410, 1920, 2382,
 3, 1, 1430,
 'EXPERT:EK_002,HISTORY:HIS_9102',
 NULL, 'INFO'),

('LOG_003', 'PRED_003', '2026-02-16 11:32:45',
 48, 370, 1800, 2218,
 2, 1, 1290,
 'HISTORY:HIS_9103',
 NULL, 'INFO');

-- RAG_DOCUMENT upsert 실행(샘플 데이터 기준)
-- (위에서 이미 INSERT...SELECT가 실행되도록 작성되어 있음)
-- 만약 Workbench에서 순서 때문에 필요하면, 위 upsert 블록을 여기로 내려도 됨.

-- ============================================================
-- (A) RAG_DOCUMENT 자동 등록(Upsert) - EXPERT → RAG_DOCUMENT
-- ============================================================
INSERT INTO RAG_DOCUMENT (
  rag_doc_key, source_type, source_id,
  vector_db_id, embedding_model, indexed_at, index_status,
  product_id, layer_position, equipment_id, pass_fail, bonding_date,
  doc_text, content_hash
)
SELECT
  CONCAT('EXPERT:', ek.knowledge_id) AS rag_doc_key,
  'EXPERT' AS source_type,
  ek.knowledge_id AS source_id,

  NULL AS vector_db_id,
  NULL AS embedding_model,
  NULL AS indexed_at,
  'PENDING' AS index_status,

  ek.related_product_id AS product_id,
  NULL AS layer_position,
  NULL AS equipment_id,
  NULL AS pass_fail,
  ek.created_date AS bonding_date,

  -- ✅ doc_text 템플릿 A(압축형) - 길이 제한(예: 900자)
  LEFT(CONCAT(
    '[EXPERT] ',
    'type=', ek.knowledge_type,
    ' | title=', ek.title,
    ' | expert=', ek.expert_name, '(', ek.expert_level, ')',
    ' | product=', IFNULL(ek.related_product_id,'NA'),
    ' | symptom=', IFNULL(LEFT(ek.problem_symptom,120),'NA'),
    ' | cause=', IFNULL(LEFT(ek.root_cause_analysis,160),'NA'),
    ' | action=', IFNULL(LEFT(ek.solution_action,220),'NA'),
    ' | recipe=', IFNULL(LEFT(ek.recipe_recommendation,180),'NA'),
    ' | tags=Void/공극,BLT,Warpage/뒤틀림,Misalignment/정렬'
  ), 900) AS doc_text,

  SHA2(CONCAT(
      ek.knowledge_id,'|',ek.knowledge_type,'|',ek.title,'|',ek.expert_name,'|',ek.expert_level,'|',
      IFNULL(ek.related_product_id,''),'|',
      IFNULL(LEFT(ek.problem_symptom,120),''),'|',
      IFNULL(LEFT(ek.root_cause_analysis,160),''),'|',
      IFNULL(LEFT(ek.solution_action,220),''),'|',
      IFNULL(LEFT(ek.recipe_recommendation,180),'')
  ), 256) AS content_hash

FROM TC_EXPERT_KNOWLEDGE ek
ON DUPLICATE KEY UPDATE
  product_id   = VALUES(product_id),
  doc_text     = VALUES(doc_text),
  content_hash = VALUES(content_hash),
  index_status = CASE
                  WHEN RAG_DOCUMENT.content_hash <> VALUES(content_hash) THEN 'PENDING'
                  ELSE RAG_DOCUMENT.index_status
                END,
  indexed_at   = CASE
                  WHEN RAG_DOCUMENT.content_hash <> VALUES(content_hash) THEN NULL
                  ELSE RAG_DOCUMENT.indexed_at
                END;


-- ============================================================
-- (B) RAG_DOCUMENT 자동 등록(Upsert) - HISTORY → RAG_DOCUMENT
--     (너가 말한 INSERT...SELECT 블록 = 이거)
-- ============================================================
INSERT INTO RAG_DOCUMENT (
  rag_doc_key, source_type, source_id,
  vector_db_id, embedding_model, indexed_at, index_status,
  product_id, layer_position, equipment_id, pass_fail, bonding_date,
  doc_text, content_hash
)
SELECT
  CONCAT('HISTORY:', h.history_id) AS rag_doc_key,
  'HISTORY' AS source_type,
  h.history_id AS source_id,

  NULL AS vector_db_id,
  NULL AS embedding_model,
  NULL AS indexed_at,
  'PENDING' AS index_status,

  h.product_id,
  h.layer_position,
  h.equipment_id,
  h.pass_fail,
  h.bonding_date,

  -- ✅ doc_text 템플릿 A(압축형) - 현장용(짧고 키워드 강함)
  LEFT(CONCAT(
    '[HISTORY] ',
    'product=', IFNULL(h.product_id,'NA'),
    ' | lot=', IFNULL(h.lot_id,'NA'),
    ' | layer=', IFNULL(h.layer_position,'NA'),
    ' | equip=', IFNULL(h.equipment_id,'NA'),
    ' | date=', IFNULL(DATE_FORMAT(h.bonding_date,'%Y-%m-%d %H:%i:%s'),'NA'),

    ' | recipe:T=', IFNULL(h.recipe_temperature_c,'NA'),'C',
              ',F=', IFNULL(h.recipe_force_n,'NA'),'N',
              ',t=', IFNULL(h.recipe_time_sec,'NA'),'s',

    ' | actual:T=', IFNULL(h.actual_peak_temperature_c,'NA'),'C',
              ',F=', IFNULL(h.actual_peak_force_n,'NA'),'N',

    ' | quality:BLT=', IFNULL(h.blt_average_um,'NA'),'um',
              ',Void=', IFNULL(h.void_area_percent,'NA'),'%',
              ',Warp=', IFNULL(h.warpage_um,'NA'),'um',
              ',MisX=', IFNULL(h.misalignment_x_um,'NA'),'um',
              ',MisY=', IFNULL(h.misalignment_y_um,'NA'),'um',

    ' | result=', IFNULL(h.pass_fail,'UNKNOWN'),
    ' | tags=Void/공극,BLT,Warpage/뒤틀림,Misalignment/정렬'
  ), 900) AS doc_text,

  SHA2(CONCAT(
      h.history_id,'|',IFNULL(h.product_id,''),'|',IFNULL(h.lot_id,''),'|',IFNULL(h.layer_position,''),
      '|',IFNULL(h.equipment_id,''),'|',IFNULL(DATE_FORMAT(h.bonding_date,'%Y-%m-%d %H:%i:%s'),''),
      '|',IFNULL(h.recipe_temperature_c,''),'|',IFNULL(h.recipe_force_n,''),'|',IFNULL(h.recipe_time_sec,''),
      '|',IFNULL(h.actual_peak_temperature_c,''),'|',IFNULL(h.actual_peak_force_n,''),'|',IFNULL(h.vacuum_level_pa,''),
      '|',IFNULL(h.blt_average_um,''),'|',IFNULL(h.void_area_percent,''),'|',IFNULL(h.warpage_um,''),
      '|',IFNULL(h.misalignment_x_um,''),'|',IFNULL(h.misalignment_y_um,''),
      '|',IFNULL(h.pass_fail,''),'|',IFNULL(h.grade,'')
  ), 256) AS content_hash

FROM TC_BONDING_HISTORY h
ON DUPLICATE KEY UPDATE
  product_id     = VALUES(product_id),
  layer_position = VALUES(layer_position),
  equipment_id   = VALUES(equipment_id),
  pass_fail      = VALUES(pass_fail),
  bonding_date   = VALUES(bonding_date),
  doc_text       = VALUES(doc_text),
  content_hash   = VALUES(content_hash),
  index_status   = CASE
                    WHEN RAG_DOCUMENT.content_hash <> VALUES(content_hash) THEN 'PENDING'
                    ELSE RAG_DOCUMENT.index_status
                  END,
  indexed_at     = CASE
                    WHEN RAG_DOCUMENT.content_hash <> VALUES(content_hash) THEN NULL
                    ELSE RAG_DOCUMENT.indexed_at
                  END;


SELECT '✅ Revised TC Bonding Prediction DB created' AS message;

USE tc_bonding_prediction;

INSERT IGNORE INTO HBM_PRODUCT
(product_id, product_name, hbm_generation, stack_layer_count, die_thickness_um, bonding_material)
VALUES
-- HBM2E (주로 8HI, 두꺼운 die)
('PROD_HBM2E_8L_40_CU',   'HBM2E-8HI-40um (Cu-Cu)',   'HBM2E', 8,  40.00, 'Cu-Cu'),
('PROD_HBM2E_8L_38_HY',   'HBM2E-8HI-38um (Hybrid)',  'HBM2E', 8,  38.00, 'Hybrid'),

-- HBM3 (8HI/12HI, 중간 두께)
('PROD_HBM3_8L_35_HY',    'HBM3-8HI-35um (Hybrid)',   'HBM3',  8,  35.00, 'Hybrid'),
('PROD_HBM3_12L_30_HY',   'HBM3-12HI-30um (Hybrid)',  'HBM3',  12, 30.00, 'Hybrid'),
('PROD_HBM3_12L_32_HY',   'HBM3-12HI-32um (Hybrid)',  'HBM3',  12, 32.00, 'Hybrid'),

-- HBM3E (8HI/12HI/16HI, 얇은 die, Hybrid 중심)
('PROD_HBM3E_8L_30_CU',   'HBM3E-8HI-30um (Cu-Cu)',   'HBM3E', 8,  30.00, 'Cu-Cu'),
('PROD_HBM3E_8L_28_HY',   'HBM3E-8HI-28um (Hybrid)',  'HBM3E', 8,  28.00, 'Hybrid'),
('PROD_HBM3E_12L_25_HY',  'HBM3E-12HI-25um (Hybrid)', 'HBM3E', 12, 25.00, 'Hybrid'),
('PROD_HBM3E_12L_27_HY',  'HBM3E-12HI-27um (Hybrid)', 'HBM3E', 12, 27.00, 'Hybrid'),
('PROD_HBM3E_16L_25_HY',  'HBM3E-16HI-25um (Hybrid)', 'HBM3E', 16, 25.00, 'Hybrid');

USE tc_bonding_prediction;

INSERT INTO TC_BONDING_HISTORY (
  history_id,
  product_id,
  lot_id,
  layer_position,
  bonding_date,
  equipment_id,
  recipe_temperature_c,
  recipe_force_n,
  recipe_time_sec,
  actual_peak_temperature_c,
  actual_peak_force_n,
  vacuum_level_pa,
  blt_average_um,
  void_area_percent,
  misalignment_x_um,
  misalignment_y_um,
  warpage_um,
  grade,
  pass_fail
)
SELECT
  CONCAT('HIS_PAT_', LPAD(n, 4, '0')) AS history_id,

  -- ✅ 10개 제품군 균등 분포
  CASE ((n - 1) % 10)
    WHEN 0 THEN 'PROD_HBM2E_8L_40_CU'
    WHEN 1 THEN 'PROD_HBM2E_8L_38_HY'
    WHEN 2 THEN 'PROD_HBM3_8L_35_HY'
    WHEN 3 THEN 'PROD_HBM3_12L_30_HY'
    WHEN 4 THEN 'PROD_HBM3_12L_32_HY'
    WHEN 5 THEN 'PROD_HBM3E_8L_30_CU'
    WHEN 6 THEN 'PROD_HBM3E_8L_28_HY'
    WHEN 7 THEN 'PROD_HBM3E_12L_25_HY'
    WHEN 8 THEN 'PROD_HBM3E_12L_27_HY'
    ELSE      'PROD_HBM3E_16L_25_HY'
  END AS product_id,

  CONCAT('LOT_', LPAD(1000 + n, 5, '0')) AS lot_id,

  -- ✅ stack_layer_count에 맞춘 layer_position
  1 + ((n - 1) % (
      CASE ((n - 1) % 10)
        WHEN 0 THEN 8 WHEN 1 THEN 8
        WHEN 2 THEN 8
        WHEN 3 THEN 12 WHEN 4 THEN 12
        WHEN 5 THEN 8 WHEN 6 THEN 8
        WHEN 7 THEN 12 WHEN 8 THEN 12
        ELSE 16
      END
  )) AS layer_position,

  -- ✅ 날짜 분포(최근 20일, 하루 10개)
  DATE_ADD(
    DATE_SUB(NOW(), INTERVAL FLOOR((n - 1) / 10) DAY),
    INTERVAL ((n - 1) % 10) * 60 MINUTE
  ) AS bonding_date,

  -- ✅ 장비 분포
  CASE
    WHEN (n % 10) IN (0,1,2,3,4) THEN 'EQP_TC_01'   -- 50%
    WHEN (n % 10) IN (5,6,7)     THEN 'EQP_TC_02'   -- 30% (문제 장비)
    ELSE                              'EQP_TC_03'   -- 20% (안정)
  END AS equipment_id,

  -- ✅ 레시피(T/F/t): 세대별 기준 + 소음
  ROUND(
    CASE
      WHEN (CASE ((n - 1) % 10) WHEN 0 THEN 'HBM2E' WHEN 1 THEN 'HBM2E' WHEN 2 THEN 'HBM3' WHEN 3 THEN 'HBM3'
                               WHEN 4 THEN 'HBM3'  WHEN 5 THEN 'HBM3E' WHEN 6 THEN 'HBM3E' WHEN 7 THEN 'HBM3E'
                               WHEN 8 THEN 'HBM3E' ELSE 'HBM3E' END) = 'HBM2E'
        THEN 265.0 + (RAND(n*101) * 2.0 - 1.0)
      WHEN (CASE ((n - 1) % 10) WHEN 0 THEN 'HBM2E' WHEN 1 THEN 'HBM2E' WHEN 2 THEN 'HBM3' WHEN 3 THEN 'HBM3'
                               WHEN 4 THEN 'HBM3'  WHEN 5 THEN 'HBM3E' WHEN 6 THEN 'HBM3E' WHEN 7 THEN 'HBM3E'
                               WHEN 8 THEN 'HBM3E' ELSE 'HBM3E' END) = 'HBM3'
        THEN 280.0 + (RAND(n*101) * 6.0 - 3.0)
      ELSE 275.0 + (RAND(n*101) * 10.0 - 5.0)
    END
  ,2) AS recipe_temperature_c,

  ROUND(
    CASE
      WHEN (CASE ((n - 1) % 10) WHEN 0 THEN 'HBM2E' WHEN 1 THEN 'HBM2E' WHEN 2 THEN 'HBM3' WHEN 3 THEN 'HBM3'
                               WHEN 4 THEN 'HBM3'  WHEN 5 THEN 'HBM3E' WHEN 6 THEN 'HBM3E' WHEN 7 THEN 'HBM3E'
                               WHEN 8 THEN 'HBM3E' ELSE 'HBM3E' END) = 'HBM2E'
        THEN 395.0 + (RAND(n*103) * 20.0 - 10.0)
      WHEN (CASE ((n - 1) % 10) WHEN 0 THEN 'HBM2E' WHEN 1 THEN 'HBM2E' WHEN 2 THEN 'HBM3' WHEN 3 THEN 'HBM3'
                               WHEN 4 THEN 'HBM3'  WHEN 5 THEN 'HBM3E' WHEN 6 THEN 'HBM3E' WHEN 7 THEN 'HBM3E'
                               WHEN 8 THEN 'HBM3E' ELSE 'HBM3E' END) = 'HBM3'
        THEN 450.0 + (RAND(n*103) * 40.0 - 20.0)
      ELSE 430.0 + (RAND(n*103) * 50.0 - 25.0)
    END
  ,2) AS recipe_force_n,

  ROUND(
    CASE
      WHEN (CASE ((n - 1) % 10) WHEN 0 THEN 'HBM2E' WHEN 1 THEN 'HBM2E' WHEN 2 THEN 'HBM3' WHEN 3 THEN 'HBM3'
                               WHEN 4 THEN 'HBM3'  WHEN 5 THEN 'HBM3E' WHEN 6 THEN 'HBM3E' WHEN 7 THEN 'HBM3E'
                               WHEN 8 THEN 'HBM3E' ELSE 'HBM3E' END) = 'HBM2E'
        THEN 20.0 + (RAND(n*107) * 4.0 - 2.0)
      WHEN (CASE ((n - 1) % 10) WHEN 0 THEN 'HBM2E' WHEN 1 THEN 'HBM2E' WHEN 2 THEN 'HBM3' WHEN 3 THEN 'HBM3'
                               WHEN 4 THEN 'HBM3'  WHEN 5 THEN 'HBM3E' WHEN 6 THEN 'HBM3E' WHEN 7 THEN 'HBM3E'
                               WHEN 8 THEN 'HBM3E' ELSE 'HBM3E' END) = 'HBM3'
        THEN 16.0 + (RAND(n*107) * 4.0 - 2.0)
      ELSE 17.0 + (RAND(n*107) * 6.0 - 3.0)
    END
  ,2) AS recipe_time_sec,

  -- ✅ actual peak: EQP_TC_02 overshoot + 소음
  ROUND(
    (CASE
      WHEN (CASE ((n - 1) % 10) WHEN 0 THEN 'HBM2E' WHEN 1 THEN 'HBM2E' WHEN 2 THEN 'HBM3' WHEN 3 THEN 'HBM3'
                               WHEN 4 THEN 'HBM3'  WHEN 5 THEN 'HBM3E' WHEN 6 THEN 'HBM3E' WHEN 7 THEN 'HBM3E'
                               WHEN 8 THEN 'HBM3E' ELSE 'HBM3E' END) = 'HBM2E'
        THEN 265.0 + (RAND(n*101) * 2.0 - 1.0)
      WHEN (CASE ((n - 1) % 10) WHEN 0 THEN 'HBM2E' WHEN 1 THEN 'HBM2E' WHEN 2 THEN 'HBM3' WHEN 3 THEN 'HBM3'
                               WHEN 4 THEN 'HBM3'  WHEN 5 THEN 'HBM3E' WHEN 6 THEN 'HBM3E' WHEN 7 THEN 'HBM3E'
                               WHEN 8 THEN 'HBM3E' ELSE 'HBM3E' END) = 'HBM3'
        THEN 280.0 + (RAND(n*101) * 6.0 - 3.0)
      ELSE 275.0 + (RAND(n*101) * 10.0 - 5.0)
    END)
    + CASE WHEN (CASE WHEN (n % 10) IN (5,6,7) THEN 'EQP_TC_02' ELSE 'OK' END) = 'EQP_TC_02' THEN 3.0 ELSE 0.0 END
    + (RAND(n*109) * 3.0 - 1.5)
  ,2) AS actual_peak_temperature_c,

  ROUND(
    (CASE
      WHEN (CASE ((n - 1) % 10) WHEN 0 THEN 'HBM2E' WHEN 1 THEN 'HBM2E' WHEN 2 THEN 'HBM3' WHEN 3 THEN 'HBM3'
                               WHEN 4 THEN 'HBM3'  WHEN 5 THEN 'HBM3E' WHEN 6 THEN 'HBM3E' WHEN 7 THEN 'HBM3E'
                               WHEN 8 THEN 'HBM3E' ELSE 'HBM3E' END) = 'HBM2E'
        THEN 395.0 + (RAND(n*103) * 20.0 - 10.0)
      WHEN (CASE ((n - 1) % 10) WHEN 0 THEN 'HBM2E' WHEN 1 THEN 'HBM2E' WHEN 2 THEN 'HBM3' WHEN 3 THEN 'HBM3'
                               WHEN 4 THEN 'HBM3'  WHEN 5 THEN 'HBM3E' WHEN 6 THEN 'HBM3E' WHEN 7 THEN 'HBM3E'
                               WHEN 8 THEN 'HBM3E' ELSE 'HBM3E' END) = 'HBM3'
        THEN 450.0 + (RAND(n*103) * 40.0 - 20.0)
      ELSE 430.0 + (RAND(n*103) * 50.0 - 25.0)
    END)
    + CASE WHEN (CASE WHEN (n % 10) IN (5,6,7) THEN 'EQP_TC_02' ELSE 'OK' END) = 'EQP_TC_02' THEN 8.0 ELSE 0.0 END
    + (RAND(n*113) * 12.0 - 6.0)
  ,2) AS actual_peak_force_n,

  -- ✅ vacuum
  ROUND(
    CASE WHEN (n % 10) IN (5,6,7)
      THEN 1180 + (RAND(n*127) * 180)
      ELSE 1120 + (RAND(n*127) * 140)
    END
  ,2) AS vacuum_level_pa,

  -- ✅ BLT (단순 연동)
  ROUND(
    2.90
    + (RAND(n*157) * 0.90)
    + CASE WHEN ((n - 1) % 10) IN (0,1) THEN 0.15 ELSE 0 END       -- HBM2E 약간↑
    + CASE WHEN ((n - 1) % 10) = 9 THEN 0.30 ELSE 0 END           -- HBM3E 16HI↑
    + CASE WHEN (n % 10) IN (5,6,7) THEN 0.10 ELSE 0 END          -- EQP_TC_02↑
  ,2) AS blt_average_um,

  -- ✅ Void (현실 패턴: 장비/레이어/온도 영향)
  ROUND(
    GREATEST(0.30,
      0.80
      + CASE
          WHEN ((n - 1) % 10) IN (0,1) THEN (RAND(n*131) * 1.2)   -- HBM2E
          WHEN ((n - 1) % 10) IN (2,3,4) THEN (RAND(n*131) * 2.0) -- HBM3
          ELSE (RAND(n*131) * 2.8)                                -- HBM3E
        END
      + CASE WHEN (n % 10) IN (5,6,7) THEN 1.0 ELSE 0.0 END       -- EQP_TC_02
      + GREATEST(0.0,
          CASE
            WHEN ((n - 1) % 10) = 9 THEN (((1 + ((n - 1) % 16)) - 8) * 0.25)  -- 16HI
            WHEN ((n - 1) % 10) IN (5,6,7,8) THEN (((1 + ((n - 1) % (
                CASE ((n - 1) % 10)
                  WHEN 5 THEN 8 WHEN 6 THEN 8 WHEN 7 THEN 12 WHEN 8 THEN 12 ELSE 16 END
            ))) - 6) * 0.18)
            WHEN ((n - 1) % 10) IN (2,3,4) THEN (((1 + ((n - 1) % (
                CASE ((n - 1) % 10)
                  WHEN 2 THEN 8 WHEN 3 THEN 12 WHEN 4 THEN 12 ELSE 8 END
            ))) - 6) * 0.12)
            ELSE 0.0
          END
      )
      + CASE WHEN ( ( (CASE
          WHEN ((n - 1) % 10) IN (0,1) THEN 265.0 + (RAND(n*101) * 2.0 - 1.0)
          WHEN ((n - 1) % 10) IN (2,3,4) THEN 280.0 + (RAND(n*101) * 6.0 - 3.0)
          ELSE 275.0 + (RAND(n*101) * 10.0 - 5.0)
        END)
        + CASE WHEN (n % 10) IN (5,6,7) THEN 3.0 ELSE 0 END
      ) > 285 ) THEN 0.80 ELSE 0.0 END
    )
  ,2) AS void_area_percent,

  -- ✅ Misalignment
  ROUND(0.15 + (RAND(n*137) * 0.35) + CASE WHEN (n % 10) IN (5,6,7) THEN 0.12 ELSE 0 END, 2) AS misalignment_x_um,
  ROUND(0.15 + (RAND(n*139) * 0.35) + CASE WHEN (n % 10) IN (5,6,7) THEN 0.12 ELSE 0 END, 2) AS misalignment_y_um,

  -- ✅ Warpage
  ROUND(
    GREATEST(1.50,
      2.50
      + (RAND(n*149) * 3.0)
      + CASE WHEN (n % 10) IN (5,6,7) THEN 2.0 ELSE 0.0 END
      + GREATEST(0.0,
          CASE
            WHEN ((n - 1) % 10) = 9 THEN (((1 + ((n - 1) % 16)) - 8) * 0.40)
            WHEN ((n - 1) % 10) IN (5,6,7,8) THEN (((1 + ((n - 1) % (
                CASE ((n - 1) % 10)
                  WHEN 5 THEN 8 WHEN 6 THEN 8 WHEN 7 THEN 12 WHEN 8 THEN 12 ELSE 16 END
            ))) - 6) * 0.30)
            WHEN ((n - 1) % 10) IN (2,3,4) THEN (((1 + ((n - 1) % (
                CASE ((n - 1) % 10)
                  WHEN 2 THEN 8 WHEN 3 THEN 12 WHEN 4 THEN 12 ELSE 8 END
            ))) - 6) * 0.20)
            ELSE (((1 + ((n - 1) % 8)) - 6) * 0.10)
          END
      )
      + CASE WHEN ( ( (CASE
          WHEN ((n - 1) % 10) IN (0,1) THEN 265.0 + (RAND(n*101) * 2.0 - 1.0)
          WHEN ((n - 1) % 10) IN (2,3,4) THEN 280.0 + (RAND(n*101) * 6.0 - 3.0)
          ELSE 275.0 + (RAND(n*101) * 10.0 - 5.0)
        END)
        + CASE WHEN (n % 10) IN (5,6,7) THEN 3.0 ELSE 0 END
      ) > 288 ) THEN 2.00 ELSE 0.0 END
    )
  ,2) AS warpage_um,

  -- ✅ Grade / PassFail (단순 룰: void/warpage/misalignment)
  CASE
    WHEN (
      (ROUND(
        GREATEST(0.30,
          0.80
          + CASE
              WHEN ((n - 1) % 10) IN (0,1) THEN (RAND(n*131) * 1.2)
              WHEN ((n - 1) % 10) IN (2,3,4) THEN (RAND(n*131) * 2.0)
              ELSE (RAND(n*131) * 2.8)
            END
          + CASE WHEN (n % 10) IN (5,6,7) THEN 1.0 ELSE 0.0 END
        )
      ,2) > 3.50)
      OR (ROUND(
        GREATEST(1.50, 2.50 + (RAND(n*149) * 3.0) + CASE WHEN (n % 10) IN (5,6,7) THEN 2.0 ELSE 0.0 END)
      ,2) > 9.00)
      OR (ROUND(0.15 + (RAND(n*137) * 0.35) + CASE WHEN (n % 10) IN (5,6,7) THEN 0.12 ELSE 0 END,2) > 0.60)
    )
    THEN 'C'
    ELSE 'A'
  END AS grade,

  CASE
    WHEN (
      (ROUND(
        GREATEST(0.30,
          0.80
          + CASE
              WHEN ((n - 1) % 10) IN (0,1) THEN (RAND(n*131) * 1.2)
              WHEN ((n - 1) % 10) IN (2,3,4) THEN (RAND(n*131) * 2.0)
              ELSE (RAND(n*131) * 2.8)
            END
          + CASE WHEN (n % 10) IN (5,6,7) THEN 1.0 ELSE 0.0 END
        )
      ,2) > 3.50)
      OR (ROUND(
        GREATEST(1.50, 2.50 + (RAND(n*149) * 3.0) + CASE WHEN (n % 10) IN (5,6,7) THEN 2.0 ELSE 0.0 END)
      ,2) > 9.00)
      OR (ROUND(0.15 + (RAND(n*137) * 0.35) + CASE WHEN (n % 10) IN (5,6,7) THEN 0.12 ELSE 0 END,2) > 0.60)
    )
    THEN 'FAIL'
    ELSE 'PASS'
  END AS pass_fail

FROM (
  -- 1~200 생성: 0~199를 만들어 +1
  SELECT (t.i + 1) AS n
  FROM (
    SELECT (a.a + 10*b.b + 100*c.c) AS i
    FROM
      (SELECT 0 a UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
       UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
    CROSS JOIN
      (SELECT 0 b UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
       UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
    CROSS JOIN
      (SELECT 0 c UNION ALL SELECT 1) c
  ) t
  WHERE t.i < 200
) seq;

USE tc_bonding_prediction;

INSERT INTO TC_EXPERT_KNOWLEDGE (
  knowledge_id, knowledge_type, title, expert_name, expert_level, created_date,
  situation_description, problem_symptom, root_cause_analysis, solution_action,
  recipe_recommendation, caution_note, related_product_id
) VALUES

-- =========================
-- HBM2E: 안정 공정 가이드 (저온/저압)
-- =========================
('EK_SYN_001','RECIPE_TIP','HBM2E 8HI 저온 안정 레시피 가이드','이준호','MASTER', NOW(),
 'HBM2E 8HI 공정은 과열보다 안정적 열확산 유지가 중요하다.',
 '온도 상승 시 BLT 증가 및 미세 공극 발생',
 '과도한 온도/압력으로 인해 접합부 변형 및 잔류응력 증가',
 '온도 264~266C 유지, 압력 385~405N 범위에서 안정화. 진공 변동이 큰 경우 챔버 누설 점검',
 'T=265C, F=395N, t=20s (±2C/±10N/±2s)',
 '압력 과다 시 die crack 위험',
 'PROD_HBM2E_8L_40_CU'),

('EK_SYN_002','TROUBLESHOOTING','HBM2E 8HI Void 상승 시 점검 순서','김민수','SENIOR_EXPERT', NOW(),
 'HBM2E 8HI에서 Void가 3% 이상으로 상승하는 경우.',
 'Void 면적 비율 증가, 중심부 공극 집중',
 '진공 불안정 또는 장비 chuck 평탄도 저하가 주요 원인',
 '진공 라인/필터 점검 → Chuck 청소/평탄도 확인 → 온도 1~2C 하향',
 'T=264~265C, F=390~400N, t=20s',
 '진공 변동이 지속되면 레시피 조정보다 설비 점검 우선',
 'PROD_HBM2E_8L_38_HY'),

('EK_SYN_003','EQUIPMENT_TIP','EQP_TC_03 안정 운전 포인트 (HBM2E)','박성민','EXPERT', NOW(),
 'EQP_TC_03에서 HBM2E 공정을 안정화하는 운영 포인트.',
 'Warpage는 낮으나 간헐적 misalignment 발생',
 'alignment 센서 오프셋 누적 및 stage backlash 가능',
 '주 1회 alignment calibration, stage 윤활 점검, alignment_tolerance 0.05um 보수 적용',
 'T=265C, F=395N, t=20s',
 '캘리브레이션 주기 준수',
 'PROD_HBM2E_8L_40_CU'),

-- =========================
-- HBM3: 12HI 중심 (중간 난이도)
-- =========================
('EK_SYN_004','RECIPE_TIP','HBM3 12HI 표준 레시피 범위','정다은','SENIOR_EXPERT', NOW(),
 'HBM3 12HI는 접합 강도와 warpage의 균형이 중요하다.',
 '온도 상승 시 warpage 증가, 압력 과다 시 misalignment 증가',
 '열 누적 + 압력 overshoot가 동시에 발생하면 품질 급락',
 '온도 277~283C 범위 유지, 압력 430~470N, 시간 14~18s에서 안정 구간을 찾는다.',
 'T=280C, F=450N, t=16s',
 'EQP_TC_02 사용 시 overshoot 감안해 온도/압력 상한을 낮출 것',
 'PROD_HBM3_12L_30_HY'),

('EK_SYN_005','DEFECT_CASE','HBM3 12HI EQP_TC_02에서 Void 급증 사례','김철수','MASTER', NOW(),
 'HBM3 12HI를 EQP_TC_02로 운전 시 특정 lot에서 Void가 급증.',
 'Void 4% 이상, warpage 9um 이상 동반',
 'EQP_TC_02 온도 overshoot(피크 상승) + 진공 변동',
 '온도 -3C, 압력 -10N 조정 + 진공 안정화(라인 누설/필터) + pre-heat 완화',
 'T=278C, F=440N, t=16s',
 '동일 장비에서 연속 생산 시 열 누적에 유의',
 'PROD_HBM3_12L_32_HY'),

('EK_SYN_006','TROUBLESHOOTING','HBM3 misalignment 증가 시 압력/정렬 점검','오세훈','EXPERT', NOW(),
 'HBM3에서 misalignment가 0.6um 근처까지 증가하는 경우.',
 'X/Y 정렬 오차 증가, 국부적 접합 불량',
 '압력 상승 + alignment tolerance 완화 + stage drift가 겹침',
 '압력 상한을 450N 근처로 제한, alignment_tolerance 강화(0.4~0.5um), stage drift 점검',
 'F=440~455N, tolerance<=0.5um',
 'misalignment는 레시피보다 설비/정렬이 원인인 경우가 많음',
 'PROD_HBM3_8L_35_HY'),

-- =========================
-- HBM3E: 8HI/12HI/16HI (고난이도)
-- =========================
('EK_SYN_007','RECIPE_TIP','HBM3E 8HI 표준 레시피와 과열 방지','박성민','MASTER', NOW(),
 'HBM3E 8HI는 얇은 die로 인해 과열 시 void/warpage가 급격히 증가한다.',
 'Void 증가, warpage 증가',
 '실측 피크 온도 상승(overshoot) 및 열 누적',
 '피크온도 285C 이상이면 온도 2~4C 하향, EQP_TC_02면 overshoot 고려해 추가 하향',
 'T=274~278C, F=420~445N, t=15~18s',
 '피크 온도 모니터링을 우선 적용',
 'PROD_HBM3E_8L_28_HY'),

('EK_SYN_008','DEFECT_CASE','HBM3E 8HI EQP_TC_02 overshoot로 FAIL 증가','김민수','SENIOR_EXPERT', NOW(),
 'HBM3E 8HI에서 EQP_TC_02 운전 시 FAIL이 집중 발생.',
 'Void>3.5%, warpage>9um 동시 발생',
 'EQP_TC_02의 온도/압력 overshoot 및 진공 변동',
 '온도 -4C, 압력 -15N, 진공 안정화 후 재측정. 필요 시 hold_time 증가',
 'T=272~276C, F=410~430N, t=17~19s',
 '장비 상태가 불안정하면 레시피 조정만으로 해결되지 않음',
 'PROD_HBM3E_8L_30_CU'),

('EK_SYN_009','TROUBLESHOOTING','HBM3E 12HI 고레이어 Void 증가 대응','정다은','EXPERT', NOW(),
 'HBM3E 12HI에서 layer 8 이상에서 void가 증가.',
 '상부 레이어에서 void 집중',
 '누적열 + 램프레이트 과다',
 '온도 ramp rate 1.5C/sec 이하, layer 8+는 온도 2~3C 하향. pre-heat 단축',
 'T=272~276C, F=415~440N, t=17~19s',
 '고레이어는 “열 관리”가 최우선',
 'PROD_HBM3E_12L_25_HY'),

('EK_SYN_010','RECIPE_TIP','HBM3E 12HI(27um) 레시피 안정 구간','이준호','MASTER', NOW(),
 'HBM3E 12HI 27um는 25um 대비 약간 안정적이나 여전히 과열 민감.',
 '온도 상승 시 warpage 증가',
 'die 얇음 + 열 누적으로 피크온도 상승',
 '피크 288C 이상이면 온도 3C 하향. EQP_TC_01 기준 안정 구간을 먼저 찾고 타 장비로 확장',
 'T=275C, F=430N, t=17s',
 '장비별 오프셋 반영 필요',
 'PROD_HBM3E_12L_27_HY'),

-- =========================
-- HBM3E 16HI (가장 위험, 고레이어 패턴)
-- =========================
('EK_SYN_011','DEFECT_CASE','HBM3E 16HI layer12+ warpage 급증 사례','김철수','MASTER', NOW(),
 'HBM3E 16HI에서 layer 12 이상 구간에서 warpage가 급증.',
 'Warpage 10um 이상, FAIL 증가',
 '상부 열 누적 + 압력 overshoot + 진공 변동',
 '고레이어는 온도 3~6C 하향, 압력 10~20N 하향, 진공 안정화. 필요 시 시간 +1~2s',
 'T=270~274C, F=410~425N, t=18~20s',
 '16HI는 레시피보다 운전 전략(열/진공/장비)이 중요',
 'PROD_HBM3E_16L_25_HY'),

('EK_SYN_012','TROUBLESHOOTING','HBM3E 16HI EQP_TC_02 사용 금지 조건','오세훈','SENIOR_EXPERT', NOW(),
 'HBM3E 16HI를 EQP_TC_02로 운전할 때 FAIL이 과도하게 증가하는 경우.',
 'Void/Warpage 동시 증가',
 'EQP_TC_02 overshoot + 열 누적이 고레이어와 결합',
 '가능하면 EQP_TC_01/03로 전환. 불가 시 온도 -6C, 압력 -20N, ramp rate 제한',
 'T<=272C, F<=420N, t=19~20s',
 '설비 조건이 맞지 않으면 레시피 튜닝만으로 품질 확보 어려움',
 'PROD_HBM3E_16L_25_HY'),

-- =========================
-- 공통 Best Practice / 메타 가이드
-- =========================
('EK_SYN_013','BEST_PRACTICE','PASS 확보를 위한 공통 우선순위(진공→피크온도→정렬)','박성민','MASTER', NOW(),
 'PASS 확보를 위한 공통 운영 우선순위를 정리한다.',
 '동일 레시피인데 PASS/FAIL이 흔들림',
 '진공/피크온도/정렬이 변동하면 레시피보다 영향이 큼',
 '1) 진공 안정화(누설/필터) 2) 피크온도 모니터링 3) alignment 캘리브레이션 후 레시피 미세조정',
 '우선 진공/피크온도/정렬을 고정한 후 레시피 변경',
 '근본원인 미해결 상태에서 레시피만 건드리면 재발',
 'PROD_HBM3E_12L_25_HY'),

('EK_SYN_014','EQUIPMENT_TIP','EQP_TC_02 overshoot 완화 체크리스트','정다은','SENIOR_EXPERT', NOW(),
 'EQP_TC_02에서 온도/압력 overshoot를 줄이는 점검 항목.',
 '피크온도 상승, 압력 피크가 반복',
 '제어 파라미터/센서 보정/열 누적',
 '제어 파라미터 재튜닝, 센서 캘리브레이션, 연속 run 시 cool-down 삽입',
 'EQP_TC_02 사용 시 온도/압력 상한을 낮출 것',
 '장비 이슈는 레시피로 숨기기 어려움',
 'PROD_HBM3E_8L_28_HY'),

('EK_SYN_015','RECIPE_TIP','질문: PASS 가능한 레시피 요청 시 응답 템플릿','이준호','MASTER', NOW(),
 '사용자가 PASS 가능한 레시피를 요청하는 경우 응답 구조를 표준화.',
 '레시피 추천이 두루뭉술해짐',
 '제품/레이어/장비 조건 누락',
 'product_id/layer/equipment를 먼저 확인하고, PASS 사례의 T/F/t 범위를 제시한 후 위험 요인을 함께 안내',
 'PASS 사례 기반: T/F/t 범위 + 위험 조건(피크온도, 진공)',
 '조건 없이 “PASS 레시피”는 존재하지 않음',
 'PROD_HBM3_12L_30_HY');
 
 INSERT INTO RAG_DOCUMENT (
  rag_doc_key, source_type, source_id, index_status, doc_text, content_hash
)
SELECT
  CONCAT('EXPERT:', knowledge_id),
  'EXPERT',
  knowledge_id,
  'PENDING',
  CONCAT('[EXPERT] 제목: ', title, ' | 원인: ', IFNULL(root_cause_analysis,'NA'), ' | 해결: ', solution_action),
  SHA2(CONCAT(knowledge_id, title), 256)
FROM TC_EXPERT_KNOWLEDGE
ON DUPLICATE KEY UPDATE doc_text = VALUES(doc_text), content_hash = VALUES(content_hash);

INSERT INTO RAG_DOCUMENT (
  rag_doc_key, source_type, source_id, index_status, product_id, layer_position, equipment_id, pass_fail, bonding_date, doc_text, content_hash
)
SELECT
  CONCAT('HISTORY:', history_id),
  'HISTORY',
  history_id,
  'PENDING',
  product_id,
  layer_position,
  equipment_id,
  pass_fail,
  bonding_date,
  CONCAT('[HISTORY] 제품: ', product_id, ' | 결과: ', pass_fail, ' | Void: ', void_area_percent, '%'),
  SHA2(CONCAT(history_id, pass_fail), 256)
FROM TC_BONDING_HISTORY
ON DUPLICATE KEY UPDATE doc_text = VALUES(doc_text), content_hash = VALUES(content_hash);

SELECT DATABASE() AS current_db;
SET autocommit = 1;
COMMIT;
