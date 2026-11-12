-- run_all.sql -- builds everything in order. From SQL*Plus or SQLcl, in this folder:
--   @run_all.sql
SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 100

@@sql/01_schema.sql
@@sql/02_plsql.sql
SELECT name, type, line, text FROM user_errors ORDER BY name, line;   -- should return no rows
@@sql/03_sample_data.sql
@@sql/04_queries.sql
@@sql/05_demo.sql
