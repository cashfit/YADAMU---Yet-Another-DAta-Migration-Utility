set echo on
DEF SCHEMA = SH
spool logs/TABLE_JSON_SQL_&SCHEMA..log
--
set pages 0
set lines 256
set long 1000000000
--
column SQL_STATEMENT FORMAT A256
column JSON_DOCUMENT FORMAT A256
--
VAR JSON CLOB
--
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = TIMES
--
@@TABLE_SQL_JSON
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = PRODUCTS
--
@@TABLE_SQL_JSON
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = CHANNELS
--
@@TABLE_SQL_JSON
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = PROMOTIONS
--
@@TABLE_SQL_JSON
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = CUSTOMERS
--
@@TABLE_SQL_JSON
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = COUNTRIES
--
@@TABLE_SQL_JSON
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = SALES
--
@@TABLE_SQL_JSON
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = COSTS
--
@@TABLE_SQL_JSON
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
quit
