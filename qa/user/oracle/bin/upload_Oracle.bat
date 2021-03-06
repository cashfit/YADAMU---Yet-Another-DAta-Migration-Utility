call qa\bin\initialize.bat %1 %~dp0 oracle upload
@set YADAMU_PARSER=SQL
@set SCHEMAVER=1
sqlplus %DB_USER%/%DB_PWD%@%DB_CONNECTION% @%YADAMU_SQL_PATH%\RECREATE_ORACLE_ALL.sql %YADAMU_LOG_PATH% %SCHEMAVER% 
call %YADAMU_SCRIPT_PATH%\upload_operations_Oracle.bat %YADAMU_INPUT_PATH% %SCHEMAVER% ""
sqlplus %DB_USER%/%DB_PWD%@%DB_CONNECTION% @%YADAMU_SQL_PATH%\COMPARE_ORACLE_ALL.sql %YADAMU_LOG_PATH% "" %SCHEMAVER% %YADAMU_PARSER% %MODE%
call %YADAMU_SCRIPT_PATH%\export_operations_Oracle.bat %YADAMU_OUTPUT_PATH% %SCHEMAVER% %SCHEMAVER% %MODE%
@set SCHEMAVER=2
sqlplus %DB_USER%/%DB_PWD%@%DB_CONNECTION% @%YADAMU_SQL_PATH%\RECREATE_ORACLE_ALL.sql %YADAMU_LOG_PATH% %SCHEMAVER% 
call %YADAMU_SCRIPT_PATH%\upload_operations_Oracle.bat %YADAMU_OUTPUT_PATH% %SCHEMAVER% 1
sqlplus %DB_USER%/%DB_PWD%@%DB_CONNECTION% @%YADAMU_SQL_PATH%\COMPARE_ORACLE_ALL.sql %YADAMU_LOG_PATH% 1 %SCHEMAVER% %YADAMU_PARSER% %MODE%
call %YADAMU_SCRIPT_PATH%\export_operations_Oracle.bat %YADAMU_OUTPUT_PATH% %SCHEMAVER% %SCHEMAVER% %MODE%
node %YADAMU_QA_BIN%\compareFileSizes %YADAMU_LOG_PATH% %YADAMU_INPUT_PATH% %YADAMU_OUTPUT_PATH%
node %YADAMU_QA_BIN%\compareArrayContent %YADAMU_LOG_PATH% %YADAMU_INPUT_PATH% %YADAMU_OUTPUT_PATH% false