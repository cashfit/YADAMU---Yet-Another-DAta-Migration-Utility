call qa\bin\initialize.bat %1 %~dp0 mysql upload
@set YADAMU_PARSER=SQL
@set FILENAME=sakila
@set SCHEMA=sakila
@set SCHEMAVER=1
sqlplus %DB_USER%/%DB_PWD%@%DB_CONNECTION% @%YADAMU_SQL_PATH%\RECREATE_SCHEMA.sql %YADAMU_LOG_PATH% %SCHEMA%%SCHEMAVER% 
node %YADAMU_BIN%\upload rdbms=%YADAMU_DB% userid=%DB_USER%/%DB_PWD%@%DB_CONNECTION% file=%YADAMU_INPUT_PATH%\%FILENAME%.json to_user=\"%SCHEMA%%SCHEMAVER%\" mode=%MODE% log_file=%YADAMU_IMPORT_LOG%
node %YADAMU_BIN%\export rdbms=%YADAMU_DB% userid=%DB_USER%/%DB_PWD%@%DB_CONNECTION% file=%YADAMU_OUTPUT_PATH%\%FILENAME%%SCHEMAVER%.json overwrite=yes from_user=\"%SCHEMA%%SCHEMAVER%\" mode=%MODE% log_file=%YADAMU_EXPORT_LOG%
@set SCHEMAVER=2
sqlplus %DB_USER%/%DB_PWD%@%DB_CONNECTION% @%YADAMU_SQL_PATH%\RECREATE_SCHEMA.sql %YADAMU_LOG_PATH% %SCHEMA%%SCHEMAVER% 
node %YADAMU_BIN%\upload rdbms=%YADAMU_DB% userid=%DB_USER%/%DB_PWD%@%DB_CONNECTION% file=%YADAMU_OUTPUT_PATH%\%FILENAME%1.json to_user=\"%SCHEMA%%SCHEMAVER%\" mode=%MODE% log_file=%YADAMU_IMPORT_LOG%
sqlplus %DB_USER%/%DB_PWD%@%DB_CONNECTION% @%YADAMU_SQL_PATH%\COMPARE_SCHEMA.sql %YADAMU_LOG_PATH% %SCHEMA% 1 %SCHEMAVER% %YADAMU_PARSER% %MODE%
node %YADAMU_BIN%\export rdbms=%YADAMU_DB% userid=%DB_USER%/%DB_PWD%@%DB_CONNECTION% file=%YADAMU_OUTPUT_PATH%\%FILENAME%%SCHEMAVER%.json overwrite=yes from_user=\"%SCHEMA%%SCHEMAVER%\" mode=%MODE% log_file=%YADAMU_EXPORT_LOG%
@set SCHEMA=jtest
@set SCHEMAVER=1
@set FILENAME=jsonExample
sqlplus %DB_USER%/%DB_PWD%@%DB_CONNECTION% @%YADAMU_SQL_PATH%\RECREATE_SCHEMA.sql %YADAMU_LOG_PATH% %SCHEMA%%SCHEMAVER% 
node %YADAMU_BIN%\upload rdbms=%YADAMU_DB% userid=%DB_USER%/%DB_PWD%@%DB_CONNECTION% file=%YADAMU_INPUT_PATH%\%FILENAME%.json to_user=\"%SCHEMA%%SCHEMAVER%\" mode=%MODE% log_file=%YADAMU_IMPORT_LOG%
node %YADAMU_BIN%\export rdbms=%YADAMU_DB% userid=%DB_USER%/%DB_PWD%@%DB_CONNECTION% file=%YADAMU_OUTPUT_PATH%\%FILENAME%%SCHEMAVER%.json overwrite=yes from_user=\"%SCHEMA%%SCHEMAVER%\" mode=%MODE% log_file=%YADAMU_EXPORT_LOG%
@set SCHEMAVER=2
sqlplus %DB_USER%/%DB_PWD%@%DB_CONNECTION% @%YADAMU_SQL_PATH%\RECREATE_SCHEMA.sql %YADAMU_LOG_PATH% %SCHEMA%%SCHEMAVER% 
node %YADAMU_BIN%\upload rdbms=%YADAMU_DB% userid=%DB_USER%/%DB_PWD%@%DB_CONNECTION% file=%YADAMU_OUTPUT_PATH%\%FILENAME%1.json to_user=\"%SCHEMA%%SCHEMAVER%\" mode=%MODE% log_file=%YADAMU_IMPORT_LOG%
sqlplus %DB_USER%/%DB_PWD%@%DB_CONNECTION% @%YADAMU_SQL_PATH%\COMPARE_SCHEMA.sql %YADAMU_LOG_PATH% %SCHEMA% 1 %SCHEMAVER% %YADAMU_PARSER% %MODE%
node %YADAMU_BIN%\export rdbms=%YADAMU_DB% userid=%DB_USER%/%DB_PWD%@%DB_CONNECTION% file=%YADAMU_OUTPUT_PATH%\%FILENAME%%SCHEMAVER%.json overwrite=yes from_user=\"%SCHEMA%%SCHEMAVER%\" mode=%MODE% log_file=%YADAMU_EXPORT_LOG%
node %YADAMU_QA_BIN%\compareFileSizes %YADAMU_LOG_PATH% %YADAMU_INPUT_PATH% %YADAMU_OUTPUT_PATH%
node %YADAMU_QA_BIN%\compareArrayContent %YADAMU_LOG_PATH% %YADAMU_INPUT_PATH% %YADAMU_OUTPUT_PATH% false