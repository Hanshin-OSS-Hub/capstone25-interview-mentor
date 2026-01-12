CREATE TABLE users (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,          -- 사용자 아이디(로그인 ID)
  password_hash VARCHAR(255) NOT NULL,           -- 비밀번호 해시(원문 저장 금지)
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- 계정 생성 시각
);

CREATE TABLE interview_sessions (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,                        -- users.id 참조
  interview_uid VARCHAR(80) NOT NULL UNIQUE,       -- 코드의 interviewId 저장용(세션 외부 식별자)
  job_title VARCHAR(100) NOT NULL,                 -- 직무
  experience_level VARCHAR(50) DEFAULT NULL,       -- 경력
  intro_text MEDIUMTEXT,                           -- cover_letter + 파일 텍스트 합쳐진 최종 입력
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  -- 세션 생성 시각
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE interview_questions (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  session_id BIGINT NOT NULL,                      -- interview_sessions.id 참조
  question_order INT NOT NULL,                     -- 1~5 (질문 순서)
  question_text TEXT NOT NULL,                     -- 질문 내용
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  -- 질문 저장 시각
  FOREIGN KEY (session_id) REFERENCES interview_sessions(id),
  UNIQUE (session_id, question_order)              -- 한 세션에 같은 순번 중복 방지
);

CREATE TABLE interview_answers (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  session_id BIGINT NOT NULL,                      -- interview_sessions.id 참조
  question_id BIGINT NOT NULL,                     -- interview_questions.id 참조
  answer_text MEDIUMTEXT NOT NULL,                 -- 사용자 답변
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  -- 답변 저장 시각
  FOREIGN KEY (session_id) REFERENCES interview_sessions(id),
  FOREIGN KEY (question_id) REFERENCES interview_questions(id),
  UNIQUE (session_id, question_id)                 -- 같은 질문에 답변 중복 방지
);

CREATE TABLE interview_results (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  session_id BIGINT NOT NULL UNIQUE,               -- 세션당 결과 1개(1:1)
  total_score INT NOT NULL,                        -- 최종 점수(0~100)
  grade VARCHAR(20) NOT NULL,                      -- 우수/양호/보통/미흡
  radar_job DECIMAL(5,2) NOT NULL,                 -- 직무 레이더 점수
  radar_logic DECIMAL(5,2) NOT NULL,               -- 논리 레이더 점수
  radar_specific DECIMAL(5,2) NOT NULL,            -- 구체성 레이더 점수
  radar_keyword DECIMAL(5,2) NOT NULL,             -- 키워드 레이더 점수
  radar_attitude DECIMAL(5,2) NOT NULL,            -- 태도 레이더 점수
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  -- 결과 저장 시각
  FOREIGN KEY (session_id) REFERENCES interview_sessions(id)
);
