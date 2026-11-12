-- 05_demo.sql -- shows each rule being enforced. Every change is rolled back at the end.
SET SERVEROUTPUT ON

-- 1. Auto-grading: is_correct was filled in by trg_auto_score, and total_score kept up to date
SELECT a.attempt_id, a.question_id, a.selected_option, a.is_correct
FROM STUDENT_ANSWERS a
WHERE a.attempt_id = 1
ORDER BY a.question_id;

SELECT attempt_id, total_score FROM STUDENT_ATTEMPTS WHERE attempt_id = 1;   -- 7

-- 2. Attempting a test before it opens  -> ORA-20004: Test has not started yet.
BEGIN
   INSERT INTO STUDENT_ATTEMPTS (test_id, student_id) VALUES (3, 8);
EXCEPTION
   WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;
/

-- 3. An instructor trying to take a test  -> ORA-20006: Only students can attempt tests.
BEGIN
   INSERT INTO STUDENT_ATTEMPTS (test_id, student_id) VALUES (1, 1);
EXCEPTION
   WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;
/

-- 4. Adding a pending question to a test  -> ORA-20008: Only approved questions can be added to a test.
BEGIN
   INSERT INTO TEST_QUESTIONS (test_id, question_id, marks) VALUES (1, 6, 1);
EXCEPTION
   WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;
/

-- 5. Answering after submitting  -> ORA-20010: This attempt has already been submitted.
BEGIN
   INSERT INTO STUDENT_ANSWERS (attempt_id, question_id, selected_option) VALUES (3, 1, 'A');
EXCEPTION
   WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;
/

-- 6. Invalid review action  -> ORA-20001: Action must be approved or rejected.
BEGIN
   approve_question(6, 'maybe');
EXCEPTION
   WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;
/

-- 7. Late submission: Divya starts test 2, the deadline passes, then she submits.
--    -> WARNING: Test submitted after deadline.
--       Test submitted successfully.
DECLARE
   v_attempt_id NUMBER;
BEGIN
   INSERT INTO STUDENT_ATTEMPTS (test_id, student_id) VALUES (2, 8)
   RETURNING attempt_id INTO v_attempt_id;
   INSERT INTO STUDENT_ANSWERS (attempt_id, question_id, selected_option)
   VALUES (v_attempt_id, 2, 'c');                      -- lower case is accepted, and it is graded wrong
   UPDATE TESTS SET end_time = SYSTIMESTAMP - INTERVAL '1' MINUTE WHERE test_id = 2;
   submit_test(v_attempt_id);
END;
/

ROLLBACK;
