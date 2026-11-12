-- 01_schema.sql -- tables and constraints for the Online MCQ Test Management System (Oracle).
-- Safe to re-run: drops the six tables first.

BEGIN
   FOR t IN (SELECT table_name FROM user_tables
             WHERE table_name IN ('STUDENT_ANSWERS', 'STUDENT_ATTEMPTS', 'TEST_QUESTIONS',
                                  'TESTS', 'QUESTIONS', 'USERS')) LOOP
      EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
   END LOOP;
END;
/

-- Instructors, teaching assistants and students.
CREATE TABLE USERS (
   user_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
   name          VARCHAR2(100) NOT NULL,
   email         VARCHAR2(150) NOT NULL UNIQUE,
   password_hash VARCHAR2(255) NOT NULL,
   role          VARCHAR2(20)  NOT NULL CHECK (role IN ('instructor', 'ta', 'student')),
   created_at    TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- Question bank. TAs submit questions as 'pending', and instructors approve or reject them.
CREATE TABLE QUESTIONS (
   question_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
   question_text  VARCHAR2(1000) NOT NULL,
   option_a       VARCHAR2(500)  NOT NULL,
   option_b       VARCHAR2(500)  NOT NULL,
   option_c       VARCHAR2(500)  NOT NULL,
   option_d       VARCHAR2(500)  NOT NULL,
   correct_option CHAR(1)        NOT NULL CHECK (correct_option IN ('A', 'B', 'C', 'D')),
   subject        VARCHAR2(100)  NOT NULL,
   difficulty     VARCHAR2(10)   CHECK (difficulty IN ('easy', 'medium', 'hard')),
   created_by     NUMBER         NOT NULL,
   status         VARCHAR2(20)   DEFAULT 'pending' NOT NULL
                                 CHECK (status IN ('pending', 'approved', 'rejected')),
   CONSTRAINT fk_q_creator FOREIGN KEY (created_by) REFERENCES USERS (user_id)
);

-- A test can only be attempted between scheduled_at and end_time.
CREATE TABLE TESTS (
   test_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
   title         VARCHAR2(200) NOT NULL,
   duration_mins NUMBER        NOT NULL CHECK (duration_mins > 0),
   scheduled_at  TIMESTAMP     NOT NULL,
   end_time      TIMESTAMP     NOT NULL,
   created_by    NUMBER        NOT NULL,
   created_at    TIMESTAMP DEFAULT SYSTIMESTAMP,
   CONSTRAINT chk_test_window CHECK (end_time > scheduled_at),
   CONSTRAINT fk_test_creator FOREIGN KEY (created_by) REFERENCES USERS (user_id)
);

-- Which questions are in which test, and how many marks each is worth.
CREATE TABLE TEST_QUESTIONS (
   tq_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
   test_id     NUMBER NOT NULL,
   question_id NUMBER NOT NULL,
   marks       NUMBER DEFAULT 1 NOT NULL CHECK (marks > 0),
   CONSTRAINT uq_tq UNIQUE (test_id, question_id),
   CONSTRAINT fk_tq_test FOREIGN KEY (test_id) REFERENCES TESTS (test_id) ON DELETE CASCADE,
   CONSTRAINT fk_tq_question FOREIGN KEY (question_id) REFERENCES QUESTIONS (question_id)
);

-- One attempt per student per test. total_score is kept up to date by trg_auto_score.
CREATE TABLE STUDENT_ATTEMPTS (
   attempt_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
   test_id      NUMBER    NOT NULL,
   student_id   NUMBER    NOT NULL,
   started_at   TIMESTAMP DEFAULT SYSTIMESTAMP,
   submitted_at TIMESTAMP,
   total_score  NUMBER    DEFAULT 0 NOT NULL,
   CONSTRAINT uq_attempt UNIQUE (test_id, student_id),
   CONSTRAINT fk_sa_test FOREIGN KEY (test_id) REFERENCES TESTS (test_id),
   CONSTRAINT fk_sa_student FOREIGN KEY (student_id) REFERENCES USERS (user_id)
);

-- One answer per question per attempt. is_correct is set by trg_auto_score.
CREATE TABLE STUDENT_ANSWERS (
   answer_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
   attempt_id      NUMBER  NOT NULL,
   question_id     NUMBER  NOT NULL,
   selected_option CHAR(1) CHECK (selected_option IN ('A', 'B', 'C', 'D')),
   is_correct      NUMBER(1) CHECK (is_correct IN (0, 1)),
   CONSTRAINT uq_answer UNIQUE (attempt_id, question_id),
   CONSTRAINT fk_ans_attempt FOREIGN KEY (attempt_id)
      REFERENCES STUDENT_ATTEMPTS (attempt_id) ON DELETE CASCADE,
   CONSTRAINT fk_ans_question FOREIGN KEY (question_id) REFERENCES QUESTIONS (question_id)
);
