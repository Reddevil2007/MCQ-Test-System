-- 03_sample_data.sql -- demo data. Run on a fresh schema (01_schema.sql), so the
-- identity columns start at 1 and the ids used below line up.
-- All accounts are fictional. Every demo password is 'demo-password'.
SET SERVEROUTPUT ON

------------------------------------------------------------------------ users (ids 1-8)
INSERT INTO USERS (name, email, password_hash, role) VALUES
   ('Prof. Sharma',  'sharma@college.edu', RAWTOHEX(STANDARD_HASH('demo-password', 'SHA256')), 'instructor');
INSERT INTO USERS (name, email, password_hash, role) VALUES
   ('Prof. Mehra',   'mehra@college.edu',  RAWTOHEX(STANDARD_HASH('demo-password', 'SHA256')), 'instructor');
INSERT INTO USERS (name, email, password_hash, role) VALUES
   ('Ankit TA',      'ankit@college.edu',  RAWTOHEX(STANDARD_HASH('demo-password', 'SHA256')), 'ta');
INSERT INTO USERS (name, email, password_hash, role) VALUES
   ('Priya TA',      'priya@college.edu',  RAWTOHEX(STANDARD_HASH('demo-password', 'SHA256')), 'ta');
INSERT INTO USERS (name, email, password_hash, role) VALUES
   ('Rahul Student', 'rahul@student.edu',  RAWTOHEX(STANDARD_HASH('demo-password', 'SHA256')), 'student');
INSERT INTO USERS (name, email, password_hash, role) VALUES
   ('Sneha Student', 'sneha@student.edu',  RAWTOHEX(STANDARD_HASH('demo-password', 'SHA256')), 'student');
INSERT INTO USERS (name, email, password_hash, role) VALUES
   ('Arjun Student', 'arjun@student.edu',  RAWTOHEX(STANDARD_HASH('demo-password', 'SHA256')), 'student');
INSERT INTO USERS (name, email, password_hash, role) VALUES
   ('Divya Student', 'divya@student.edu',  RAWTOHEX(STANDARD_HASH('demo-password', 'SHA256')), 'student');

------------------------------------------------------------------------ questions (ids 1-6)
-- TAs submit questions, which start as 'pending'.
INSERT INTO QUESTIONS (question_text, option_a, option_b, option_c, option_d,
                       correct_option, subject, difficulty, created_by) VALUES
   ('Which SQL clause filters rows before grouping?',
    'HAVING', 'WHERE', 'ORDER BY', 'GROUP BY', 'B', 'SQL', 'easy', 3);
INSERT INTO QUESTIONS (question_text, option_a, option_b, option_c, option_d,
                       correct_option, subject, difficulty, created_by) VALUES
   ('What is the time complexity of binary search?',
    'O(n)', 'O(log n)', 'O(n log n)', 'O(1)', 'B', 'Algorithms', 'medium', 3);
INSERT INTO QUESTIONS (question_text, option_a, option_b, option_c, option_d,
                       correct_option, subject, difficulty, created_by) VALUES
   ('Which normal form removes transitive dependency?',
    '1NF', '2NF', '3NF', 'None of these', 'C', 'DBMS', 'medium', 4);
INSERT INTO QUESTIONS (question_text, option_a, option_b, option_c, option_d,
                       correct_option, subject, difficulty, created_by) VALUES
   ('Which JOIN returns all rows from both tables?',
    'INNER JOIN', 'LEFT JOIN', 'CROSS JOIN', 'FULL OUTER JOIN', 'D', 'SQL', 'easy', 3);
INSERT INTO QUESTIONS (question_text, option_a, option_b, option_c, option_d,
                       correct_option, subject, difficulty, created_by) VALUES
   ('Which key uniquely identifies each row of a table?',
    'Primary key', 'Foreign key', 'Candidate attribute', 'Composite index', 'A', 'DBMS', 'easy', 4);
INSERT INTO QUESTIONS (question_text, option_a, option_b, option_c, option_d,
                       correct_option, subject, difficulty, created_by) VALUES
   ('Which data structure does breadth-first search use?',
    'Stack', 'Queue', 'Heap', 'Hash table', 'B', 'Algorithms', 'easy', 4);

-- Instructors review them. Question 6 is left pending.
BEGIN
   approve_question(1, 'approved');
   approve_question(2, 'approved');
   approve_question(3, 'approved');
   approve_question(4, 'approved');
   approve_question(5, 'approved');
END;
/

------------------------------------------------------------------------ tests (ids 1-3)
-- Tests 1 and 2 are open now, and test 3 opens in a week.
DECLARE
   v_test_id NUMBER;
BEGIN
   create_test('DBMS Mid-Semester Test', 30, SYSTIMESTAMP - INTERVAL '1' HOUR,
               SYSTIMESTAMP + INTERVAL '7' DAY, 1, v_test_id);
   create_test('Algorithms Quiz 1', 20, SYSTIMESTAMP - INTERVAL '1' HOUR,
               SYSTIMESTAMP + INTERVAL '7' DAY, 2, v_test_id);
   create_test('Compiler Design Quiz', 15, SYSTIMESTAMP + INTERVAL '7' DAY,
               SYSTIMESTAMP + INTERVAL '8' DAY, 1, v_test_id);
END;
/

INSERT INTO TEST_QUESTIONS (test_id, question_id, marks) VALUES (1, 1, 2);
INSERT INTO TEST_QUESTIONS (test_id, question_id, marks) VALUES (1, 3, 2);
INSERT INTO TEST_QUESTIONS (test_id, question_id, marks) VALUES (1, 4, 2);
INSERT INTO TEST_QUESTIONS (test_id, question_id, marks) VALUES (1, 5, 3);
INSERT INTO TEST_QUESTIONS (test_id, question_id, marks) VALUES (2, 2, 2);

------------------------------------------------------------------------ attempts (ids 1-4)
INSERT INTO STUDENT_ATTEMPTS (test_id, student_id) VALUES (1, 5);   -- Rahul
INSERT INTO STUDENT_ATTEMPTS (test_id, student_id) VALUES (1, 6);   -- Sneha
INSERT INTO STUDENT_ATTEMPTS (test_id, student_id) VALUES (1, 7);   -- Arjun
INSERT INTO STUDENT_ATTEMPTS (test_id, student_id) VALUES (2, 5);   -- Rahul

------------------------------------------------------------------------ answers
-- trg_auto_score grades each answer and updates total_score.
-- Rahul, test 1: 3 of 4 correct -> 7
INSERT INTO STUDENT_ANSWERS (attempt_id, question_id, selected_option) VALUES (1, 1, 'B');
INSERT INTO STUDENT_ANSWERS (attempt_id, question_id, selected_option) VALUES (1, 3, 'B');
INSERT INTO STUDENT_ANSWERS (attempt_id, question_id, selected_option) VALUES (1, 4, 'D');
INSERT INTO STUDENT_ANSWERS (attempt_id, question_id, selected_option) VALUES (1, 5, 'A');
-- Sneha, test 1: all correct -> 9
INSERT INTO STUDENT_ANSWERS (attempt_id, question_id, selected_option) VALUES (2, 1, 'B');
INSERT INTO STUDENT_ANSWERS (attempt_id, question_id, selected_option) VALUES (2, 3, 'C');
INSERT INTO STUDENT_ANSWERS (attempt_id, question_id, selected_option) VALUES (2, 4, 'D');
INSERT INTO STUDENT_ANSWERS (attempt_id, question_id, selected_option) VALUES (2, 5, 'A');
-- Arjun, test 1: 2 of 4 correct -> 4
INSERT INTO STUDENT_ANSWERS (attempt_id, question_id, selected_option) VALUES (3, 1, 'B');
INSERT INTO STUDENT_ANSWERS (attempt_id, question_id, selected_option) VALUES (3, 3, 'A');
INSERT INTO STUDENT_ANSWERS (attempt_id, question_id, selected_option) VALUES (3, 4, 'D');
INSERT INTO STUDENT_ANSWERS (attempt_id, question_id, selected_option) VALUES (3, 5, 'C');
-- Rahul, test 2: correct -> 2
INSERT INTO STUDENT_ANSWERS (attempt_id, question_id, selected_option) VALUES (4, 2, 'B');

BEGIN
   submit_test(1);
   submit_test(2);
   submit_test(3);
   submit_test(4);
END;
/

COMMIT;
