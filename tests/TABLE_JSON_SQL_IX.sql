set echo on
DEF SCHEMA = IX
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
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = ORDERS_QUEUETABLE

@@TABLE_SQL_JSON
--
desc IX.STREAMS_QUEUE_TABLE
--
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = STREAMS_QUEUE_TABLE
--
@@TABLE_SQL_JSON
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = AQ$_ORDERS_QUEUETABLE_G
--
@@TABLE_SQL_JSON
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = AQ$_ORDERS_QUEUETABLE_H
--
@@TABLE_SQL_JSON
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = AQ$_ORDERS_QUEUETABLE_I
--
@@TABLE_SQL_JSON
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = AQ$_ORDERS_QUEUETABLE_L
--
@@TABLE_SQL_JSON
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = AQ$_ORDERS_QUEUETABLE_S
--
@@TABLE_SQL_JSON
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = AQ$_ORDERS_QUEUETABLE_T
--
@@TABLE_SQL_JSON
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = AQ$_STREAMS_QUEUE_TABLE_C
--
@@TABLE_SQL_JSON
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = AQ$_STREAMS_QUEUE_TABLE_H
--
@@TABLE_SQL_JSON
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = AQ$_STREAMS_QUEUE_TABLE_I
--
@@TABLE_SQL_JSON
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = AQ$_STREAMS_QUEUE_TABLE_L
--
@@TABLE_SQL_JSON
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = AQ$_STREAMS_QUEUE_TABLE_S
--
@@TABLE_SQL_JSON
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
DEF TABLE = AQ$_STREAMS_QUEUE_TABLE_T
--
@@TABLE_SQL_JSON
--
set lines 256
spool logs/TABLE_JSON_SQL_&SCHEMA..log APPEND
--
quit