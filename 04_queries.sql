-- 04_queries.sql -- reports and analytics.

------------------------------------------------------------------------ basic queries

-- Approved questions with the TA who contributed them
SELECT q.question_id, q.question_text, q.subject, q.difficulty,
       u.name AS contributed_by
FROM QUESTIONS q
JOIN USERS u ON u.user_id = q.created_by
WHERE q.status = 'approved'
ORDER BY q.question_id;

-- Questions waiting for an instructor's review
SELECT q.question_id, q.question_text, u.name AS submitted_by
FROM QUESTIONS q
JOIN USERS u ON u.user_id = q.created_by
WHERE q.status = 'pending';

-- Questions and marks in each test
SELECT t.title, q.question_text, tq.marks
FROM TESTS t
JOIN TEST_QUESTIONS tq ON tq.test_id = t.test_id
JOIN QUESTIONS q ON q.question_id = tq.question_id
ORDER BY t.test_id, tq.tq_id;

------------------------------------------------------------------------ analytical queries

-- Leaderboard for each test
SELECT t.title, u.name, sa.total_score,
       RANK() OVER (PARTITION BY sa.test_id ORDER BY sa.total_score DESC) AS rank
FROM STUDENT_ATTEMPTS sa
JOIN USERS u ON u.user_id = sa.student_id
JOIN TESTS t ON t.test_id = sa.test_id
ORDER BY sa.test_id, rank;

-- Student scorecard as a percentage of the maximum marks
SELECT u.name, t.title, sa.total_score,
       get_test_max_marks(sa.test_id) AS max_marks,
       ROUND(100 * sa.total_score / NULLIF(get_test_max_marks(sa.test_id), 0), 1) AS score_pct
FROM STUDENT_ATTEMPTS sa
JOIN USERS u ON u.user_id = sa.student_id
JOIN TESTS t ON t.test_id = sa.test_id
ORDER BY u.name, t.title;

-- Average, highest and lowest score per test
SELECT t.title,
       COUNT(*)                     AS attempts,
       ROUND(AVG(sa.total_score), 2) AS avg_score,
       MAX(sa.total_score)          AS best,
       MIN(sa.total_score)          AS worst
FROM STUDENT_ATTEMPTS sa
JOIN TESTS t ON t.test_id = sa.test_id
GROUP BY t.title
ORDER BY t.title;

-- Question performance: how often each question is answered correctly
SELECT sa_q.question_id, q.question_text,
       COUNT(*)                                AS attempts,
       SUM(sa_q.is_correct)                    AS correct_count,
       ROUND(100 * AVG(sa_q.is_correct), 1)    AS percent_correct
FROM STUDENT_ANSWERS sa_q
JOIN QUESTIONS q ON q.question_id = sa_q.question_id
GROUP BY sa_q.question_id, q.question_text
ORDER BY percent_correct;

-- Students who scored above their test's average (correlated subquery)
SELECT u.name, t.title, sa.total_score
FROM STUDENT_ATTEMPTS sa
JOIN USERS u ON u.user_id = sa.student_id
JOIN TESTS t ON t.test_id = sa.test_id
WHERE sa.total_score > (SELECT AVG(x.total_score)
                        FROM STUDENT_ATTEMPTS x
                        WHERE x.test_id = sa.test_id);

-- Function calls
SELECT get_student_score(6, 1) AS sneha_test1,
       get_test_max_marks(1)   AS test1_max
FROM dual;
