-- 목적
-- AI 면접 프로젝트에서 1회를 최소 사이클로 잡은 버전 면접 세션 → 질문들 → 답변들 → 최종 결과를 저장하기 위한 스키마 설계안
-- 사용자 로그인 기능은 선택이며, 익명 세션도 허용할 수 있도록 user_id를 NULL 허용으로 구성

-- ----------------------------------------
-- 1) users: 사용자 계정 테이블
-- ----------------------------------------
CREATE TABLE users (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  -- 내부 PK. 다른 테이블에서 user_id로 참조

  username VARCHAR(50) NOT NULL UNIQUE,
  -- 로그인 식별자(아이디). UNIQUE로 중복 방지

  password_hash VARCHAR(255) NOT NULL,
  -- 비밀번호 원문이 아니라 해시(암호화된 문자열)를 저장

  display_name VARCHAR(80) DEFAULT NULL,
  -- 표시용 닉네임/이름(선택)

  role ENUM('user','admin') NOT NULL DEFAULT 'user',
  -- 권한 구분(일반 사용자/관리자)

  status ENUM('active','blocked','deleted') NOT NULL DEFAULT 'active',
  -- 계정 상태(활성/차단/삭제 처리)

  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  -- 계정 생성 시각

  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  -- 계정 정보가 바뀔 때 자동 갱신되는 시각

  last_login_at TIMESTAMP NULL
  -- 마지막 로그인 시각(선택)
);

-- ----------------------------------------
-- 2) interview_sessions: 면접 1회(세션) 부모 테이블
-- ----------------------------------------
CREATE TABLE interview_sessions (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  -- 내부 PK. questions/answers/results가 session_id로 참조

  interview_uid VARCHAR(80) NOT NULL UNIQUE,
  -- 외부 공개용 식별자. 프론트가 들고 다니는 interviewId로 쓰기 좋음

  user_id BIGINT NULL,
  -- 로그인 기능이 없거나 익명 면접을 허용할 경우 NULL 가능
  -- 로그인 기능을 강제하고 싶으면 NOT NULL로 바꾸고, 코드에서 user_id를 반드시 넣어야 함

  job_title VARCHAR(100) NOT NULL,
  -- 지원 직무/직군(예: 백엔드)

  experience_level VARCHAR(50) NULL,
  -- 경력 수준(예: 신입/주니어/시니어). 선택

  intro_text MEDIUMTEXT NULL,
  -- 자기소개/자소서/입력 텍스트. 길어질 수 있어 MEDIUMTEXT 권장

  resume_text MEDIUMTEXT NULL,
  -- 이력서 텍스트(선택). 자소서와 분리해두면 분석/관리 편함

  status ENUM('created','in_progress','submitted','closed') NOT NULL DEFAULT 'created',
  -- 세션 진행 상태
  -- created: 생성됨
  -- in_progress: 질문/답변 진행 중
  -- submitted: 최종 제출 완료
  -- closed: 종료/보관 상태

  submitted_at TIMESTAMP NULL,
  -- 최종 제출 시각(선택)

  client_meta JSON NULL,
  -- 클라이언트 환경(브라우저/OS/언어 등)을 JSON으로 저장(선택)

  source_file_name VARCHAR(255) NULL,
  -- 업로드 파일명이 있을 때 기록(선택)

  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  -- 세션 생성 시각

  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  -- 세션 정보 업데이트 시 자동 갱신

  INDEX idx_sessions_user_created (user_id, created_at),
  -- 사용자별 세션 목록 조회(user_id + 최신순 정렬)에 유리

  INDEX idx_sessions_status_created (status, created_at),
  -- 상태별(진행중/제출완료 등) 조회에 유리

  CONSTRAINT fk_sessions_user
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
  -- user가 삭제되면 해당 세션은 익명(NULL)로 남김
);

-- ----------------------------------------
-- 3) interview_questions: 세션별 질문 목록
-- ----------------------------------------
CREATE TABLE interview_questions (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  -- 질문 PK. answers가 question_id로 참조

  session_id BIGINT NOT NULL,
  -- 어느 면접 세션에 속한 질문인지를 파악

  question_order INT NOT NULL,
  -- 질문 순번(1,2,3...). 세션 내에서 질문의 순서를 고정

  question_text TEXT NOT NULL,
  -- 질문 본문을 저장

  question_type ENUM('job','logic','specific','keyword','attitude','other') NULL,
  -- 질문 분류(선택). 5개 평가 항목 기반으로 분류하면 분석에 도움

  difficulty TINYINT NULL,
  -- 숙련도. 1~5 같은 스케일로 관리 가능

  generated_by_model VARCHAR(50) NULL,
  -- 질문 생성에 사용한 모델명

  generation_prompt MEDIUMTEXT NULL,
  -- 질문 생성 프롬프트. 디버깅/개선용

  generation_raw JSON NULL,
  -- 모델 원 응답을 JSON으로 저장(선택). 추후 재현/품질분석에 도움

  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  -- 질문 생성 시각

  UNIQUE KEY uq_questions_session_order (session_id, question_order),
  -- 같은 세션에서 같은 순번 질문이 2개 생기는 것을 방지

  INDEX idx_questions_session_created (session_id, created_at),
  -- 세션의 질문들을 시간 순으로 조회할 때 유리

  CONSTRAINT fk_questions_session
    FOREIGN KEY (session_id) REFERENCES interview_sessions(id) ON DELETE CASCADE
  -- 세션이 삭제되면 해당 세션의 질문들도 같이 삭제
);

-- ----------------------------------------
-- 4) interview_answers: 질문별 사용자 답변
-- ----------------------------------------
CREATE TABLE interview_answers (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  -- 답변 PK. answer_reviews가 answer_id로 참조

  session_id BIGINT NOT NULL,
  -- 어느 세션의 답변인지

  question_id BIGINT NOT NULL,
  -- 어느 질문에 대한 답변인지

  attempt_no INT NOT NULL DEFAULT 1,
  -- 동일 질문에 대한 재시도 번호(1,2,3...)
  -- 답변 수정/재제출 히스토리를 남기고 싶을 때 사용

  is_final TINYINT(1) NOT NULL DEFAULT 1,
  -- 현재 최종 답변 여부(1: 최종, 0: 과거 버전)
  -- attempt_no를 쓰는 경우, 최신 attempt만 is_final=1로 유지하는 방식 권장

  answer_text MEDIUMTEXT NOT NULL,
  -- 답변 본문(길 수 있으므로 MEDIUMTEXT 권장)

  answered_at TIMESTAMP NULL,
  -- 사용자가 실제로 답변한 시각(선택)
  -- created_at과 구분해두면 프론트에서 입력 완료 시점만 따로 기록 가능

  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  -- DB에 레코드가 생성된 시각

  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  -- 레코드가 수정될 경우 자동 갱신

  UNIQUE KEY uq_answers_question_attempt (question_id, attempt_no),
  -- 질문 1개에 대해 attempt_no가 중복되지 않도록 보장
  -- 세션을 더 엄격히 묶고 싶으면 (session_id, question_id, attempt_no)로 바꿔도 됨

  INDEX idx_answers_session_created (session_id, created_at),
  -- 세션별 답변 목록 조회에 유리

  INDEX idx_answers_question (question_id),
  -- 질문 기준으로 답변을 찾을 때 유리

  CONSTRAINT fk_answers_session
    FOREIGN KEY (session_id) REFERENCES interview_sessions(id) ON DELETE CASCADE,
  -- 세션 삭제 시 답변도 같이 삭제

  CONSTRAINT fk_answers_question
    FOREIGN KEY (question_id) REFERENCES interview_questions(id) ON DELETE CASCADE
  -- 질문 삭제 시 해당 답변도 같이 삭제
);

-- ----------------------------------------
-- 5) interview_results: 세션 최종 결과(세션당 1개)
-- ----------------------------------------
CREATE TABLE interview_results (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  -- 결과 PK

  session_id BIGINT NOT NULL UNIQUE,
  -- 세션당 결과는 1개만 허용(UNIQUE)

  total_score INT NOT NULL,
  -- 총점(정수형)

  grade VARCHAR(20) NOT NULL,
  -- 등급(예: A/B/C 또는 PASS/FAIL 등)

  radar_job DECIMAL(5,2) NOT NULL,
  radar_logic DECIMAL(5,2) NOT NULL,
  radar_specific DECIMAL(5,2) NOT NULL,
  radar_keyword DECIMAL(5,2) NOT NULL,
  radar_attitude DECIMAL(5,2) NOT NULL,
  -- 5개 평가 항목 점수(소수점 2자리까지)

  feedback_text MEDIUMTEXT NULL,
  -- 최종 피드백 텍스트(선택)

  eval_model VARCHAR(50) NULL,
  -- 평가에 사용한 모델명(선택)

  eval_raw JSON NULL,
  -- 평가 원 응답(JSON) 저장(선택). 품질 분석에 유리

  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  -- 결과 생성 시각

  CONSTRAINT fk_results_session
    FOREIGN KEY (session_id) REFERENCES interview_sessions(id) ON DELETE CASCADE
  -- 세션 삭제 시 결과도 같이 삭제
);

-- ----------------------------------------
-- 6) answer_reviews: 질문 단위 평가(선택)
-- ----------------------------------------
CREATE TABLE answer_reviews (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  -- 질문별 평가 PK

  answer_id BIGINT NOT NULL UNIQUE,
  -- 답변 1개당 평가 1개(UNIQUE)

  score_job DECIMAL(5,2) NULL,
  score_logic DECIMAL(5,2) NULL,
  score_specific DECIMAL(5,2) NULL,
  score_keyword DECIMAL(5,2) NULL,
  score_attitude DECIMAL(5,2) NULL,
  -- 질문 단위로도 5개 항목 점수를 저장하고 싶을 때 사용(선택)

  strengths TEXT NULL,
  weaknesses TEXT NULL,
  suggestions TEXT NULL,
  -- 장점/단점/개선점(선택)

  eval_model VARCHAR(50) NULL,
  -- 질문 단위 평가에 사용한 모델명(선택)

  eval_raw JSON NULL,
  -- 질문 단위 평가 원 응답(선택)

  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  -- 평가 생성 시각

  CONSTRAINT fk_reviews_answer
    FOREIGN KEY (answer_id) REFERENCES interview_answers(id) ON DELETE CASCADE
  -- 답변 삭제 시 해당 평가도 같이 삭제
);
