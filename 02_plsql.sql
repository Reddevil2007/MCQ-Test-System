-- 02_plsql.sql -- stored functions, procedures and triggers.
--
-- Error codes raised by this file:
--   -20001 invalid approval action          -20007 test already submitted
--   -20002 question not found               -20008 question is not approved
--   -20003 only instructors can create tests -20009 question is not part of this test
--   -20004 test has not started yet         -20010 answer after submission
--   -20005 test window has closed           -20011 unknown user, test or attempt
--   -20006 only students can attempt tests  -20012 end time must be after start time

------------------------------------------------------------------------ functions

-- Total score of a student on a test (NULL if they have not attempted it).
CREATE OR REPLACE FUNCTION get_student_score (
   p_student_id IN NUMBER,
   p_test_id    IN NUMBER
) RETURN NUMBER
IS
   v_score STUDENT_ATTEMPTS.total_score%TYPE;
BEGIN
   SELECT total_score INTO v_score
   FROM STUDENT_ATTEMPTS
   WHERE student_id = p_student_id AND test_id = p_test_id;
   RETURN v_score;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN NULL;
END;
/

-- Maximum marks available in a test.
CREATE OR REPLACE FUNCTION get_test_max_marks (
   p_test_id IN NUMBER
) RETURN NUMBER
IS
   v_max NUMBER;
BEGIN
   SELECT NVL(SUM(marks), 0) INTO v_max
   FROM TEST_QUESTIONS
   WHERE test_id = p_test_id;
   RETURN v_max;
END;
/

------------------------------------------------------------------------ procedures

-- An instructor approves or rejects a pending question.
CREATE OR REPLACE PROCEDURE approve_question (
   p_question_id IN NUMBER,
   p_action      IN VARCHAR2
)
IS
BEGIN
   IF p_action IS NULL OR LOWER(p_action) NOT IN ('approved', 'rejected') THEN
      RAISE_APPLICATION_ERROR(-20001, 'Action must be approved or rejected.');
   END IF;

   UPDATE QUESTIONS
   SET status = LOWER(p_action)
   WHERE question_id = p_question_id;

   IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20002, 'Question not found.');
   END IF;
END;
/

-- An instructor creates a test. The new test_id is returned in p_test_id.
CREATE OR REPLACE PROCEDURE create_test (
   p_title         IN  VARCHAR2,
   p_duration_mins IN  NUMBER,
   p_scheduled_at  IN  TIMESTAMP,
   p_end_time      IN  TIMESTAMP,
   p_instructor_id IN  NUMBER,
   p_test_id       OUT NUMBER
)
IS
   v_role USERS.role%TYPE;
BEGIN
   SELECT role INTO v_role FROM USERS WHERE user_id = p_instructor_id;

   IF v_role <> 'instructor' THEN
      RAISE_APPLICATION_ERROR(-20003, 'Only instructors can create tests.');
   END IF;
   IF p_end_time <= p_scheduled_at THEN
      RAISE_APPLICATION_ERROR(-20012, 'End time must be after the start time.');
   END IF;

   INSERT INTO TESTS (title, duration_mins, scheduled_at, end_time, created_by)
   VALUES (p_title, p_duration_mins, p_scheduled_at, p_end_time, p_instructor_id)
   RETURNING test_id INTO p_test_id;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20011, 'Unknown user.');
END;
/

-- A student submits an attempt. Late submissions are accepted with a warning.
CREATE OR REPLACE PROCEDURE submit_test (
   p_attempt_id IN NUMBER
)
IS
   v_started   STUDENT_ATTEMPTS.started_at%TYPE;
   v_submitted STUDENT_ATTEMPTS.submitted_at%TYPE;
   v_end       TESTS.end_time%TYPE;
   v_duration  TESTS.duration_mins%TYPE;
   v_now       TIMESTAMP := SYSTIMESTAMP;
BEGIN
   SELECT sa.started_at, sa.submitted_at, t.end_time, t.duration_mins
   INTO v_started, v_submitted, v_end, v_duration
   FROM STUDENT_ATTEMPTS sa
   JOIN TESTS t ON t.test_id = sa.test_id
   WHERE sa.attempt_id = p_attempt_id;

   IF v_submitted IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(-20007, 'Test has already been submitted.');
   END IF;

   UPDATE STUDENT_ATTEMPTS
   SET submitted_at = v_now
   WHERE attempt_id = p_attempt_id;

   IF v_now > v_end OR v_now > v_started + NUMTODSINTERVAL(v_duration, 'MINUTE') THEN
      DBMS_OUTPUT.PUT_LINE('WARNING: Test submitted after deadline.');
   END IF;
   DBMS_OUTPUT.PUT_LINE('Test submitted successfully.');
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20011, 'Unknown attempt.');
END;
/

------------------------------------------------------------------------ triggers

-- Only approved questions can be added to a test.
CREATE OR REPLACE TRIGGER trg_check_question_approved
BEFORE INSERT OR UPDATE OF question_id ON TEST_QUESTIONS
FOR EACH ROW
DECLARE
   v_status QUESTIONS.status%TYPE;
BEGIN
   SELECT status INTO v_status FROM QUESTIONS WHERE question_id = :NEW.question_id;
   IF v_status <> 'approved' THEN
      RAISE_APPLICATION_ERROR(-20008, 'Only approved questions can be added to a test.');
   END IF;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20002, 'Question not found.');
END;
/

-- A test can only be attempted by a student, and only inside its scheduled window.
CREATE OR REPLACE TRIGGER trg_validate_attempt
BEFORE INSERT ON STUDENT_ATTEMPTS
FOR EACH ROW
DECLARE
   v_role  USERS.role%TYPE;
   v_start TESTS.scheduled_at%TYPE;
   v_end   TESTS.end_time%TYPE;
BEGIN
   SELECT role INTO v_role FROM USERS WHERE user_id = :NEW.student_id;
   IF v_role <> 'student' THEN
      RAISE_APPLICATION_ERROR(-20006, 'Only students can attempt tests.');
   END IF;

   SELECT scheduled_at, end_time INTO v_start, v_end FROM TESTS WHERE test_id = :NEW.test_id;

   :NEW.started_at := NVL(:NEW.started_at, SYSTIMESTAMP);
   IF :NEW.started_at < v_start THEN
      RAISE_APPLICATION_ERROR(-20004, 'Test has not started yet.');
   END IF;
   IF :NEW.started_at > v_end THEN
      RAISE_APPLICATION_ERROR(-20005, 'Test window has closed.');
   END IF;

   :NEW.submitted_at := NULL;
   :NEW.total_score  := 0;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20011, 'Unknown student or test.');
END;
/

-- Grades every answer as it is inserted and adds its marks to the attempt's total.
CREATE OR REPLACE TRIGGER trg_auto_score
BEFORE INSERT ON STUDENT_ANSWERS
FOR EACH ROW
DECLARE
   v_test_id   STUDENT_ATTEMPTS.test_id%TYPE;
   v_submitted STUDENT_ATTEMPTS.submitted_at%TYPE;
   v_marks     TEST_QUESTIONS.marks%TYPE;
   v_correct   QUESTIONS.correct_option%TYPE;
BEGIN
   BEGIN
      SELECT test_id, submitted_at INTO v_test_id, v_submitted
      FROM STUDENT_ATTEMPTS WHERE attempt_id = :NEW.attempt_id;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         RAISE_APPLICATION_ERROR(-20011, 'Unknown attempt.');
   END;

   IF v_submitted IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(-20010, 'This attempt has already been submitted.');
   END IF;

   BEGIN
      SELECT marks INTO v_marks
      FROM TEST_QUESTIONS
      WHERE test_id = v_test_id AND question_id = :NEW.question_id;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         RAISE_APPLICATION_ERROR(-20009, 'Question is not part of this test.');
   END;

   SELECT correct_option INTO v_correct FROM QUESTIONS WHERE question_id = :NEW.question_id;

   :NEW.selected_option := UPPER(:NEW.selected_option);
   IF :NEW.selected_option = v_correct THEN
      :NEW.is_correct := 1;
      UPDATE STUDENT_ATTEMPTS
      SET total_score = total_score + v_marks
      WHERE attempt_id = :NEW.attempt_id;
   ELSE
      :NEW.is_correct := 0;          -- wrong or skipped (NULL) answer
   END IF;
END;
/
