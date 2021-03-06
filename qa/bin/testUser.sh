export SCHEMAID=$1
if [ -z ${YADAMU_HOME+x} ]; then export YADAMU_HOME=`pwd`; fi
if [ -z ${YADAMU_INSTALL+x} ]$; then export YADAMU_INSTALL=$YADAMU_HOME/app/install/; fi
if [ -z ${YADAMU_QA_SQL+x} ]$; then export YADAMU_QA_SQL=$YADAMU_HOME/qa/sql; fi
export YADAMU_DB=oracle19c
source $YADAMU_INSTALL/$YADAMU_DB/env/dbConnection.sh
sqlplus $DB_USER/$DB_PWD@$DB_CONNECTION @$YADAMU_QA_SQL/oracle/RECREATE_MSSQL_ALL.sql $YADAMU_LOG_PATH/$YADAMU_DB $SCHEMAID 
sqlplus $DB_USER/$DB_PWD@$DB_CONNECTION @$YADAMU_QA_SQL/oracle/RECREATE_ORACLE_ALL.sql $YADAMU_LOG_PATH/$YADAMU_DB $SCHEMAID 
sqlplus $DB_USER/$DB_PWD@$DB_CONNECTION @$YADAMU_QA_SQL/oracle/RECREATE_SCHEMA.sql $YADAMU_LOG_PAT/$YADAMU_DBH "jtest$SCHEMAID" 
sqlplus $DB_USER/$DB_PWD@$DB_CONNECTION @$YADAMU_QA_SQL/oracle/RECREATE_SCHEMA.sql $YADAMU_LOG_PATH/$YADAMU_DB "sakila$SCHEMAID" 
export YADAMU_DB=oracle18c
source $YADAMU_INSTALL/$YADAMU_DB/env/dbConnection.sh
sqlplus $DB_USER/$DB_PWD@$DB_CONNECTION @$YADAMU_QA_SQL/oracle/RECREATE_MSSQL_ALL.sql $YADAMU_LOG_PATH/$YADAMU_DB $SCHEMAID 
sqlplus $DB_USER/$DB_PWD@$DB_CONNECTION @$YADAMU_QA_SQL/oracle/RECREATE_ORACLE_ALL.sql $YADAMU_LOG_PATH/$YADAMU_DB $SCHEMAID 
sqlplus $DB_USER/$DB_PWD@$DB_CONNECTION @$YADAMU_QA_SQL/oracle/RECREATE_SCHEMA.sql $YADAMU_LOG_PATH/$YADAMU_DB "jtest$SCHEMAID" 
sqlplus $DB_USER/$DB_PWD@$DB_CONNECTION @$YADAMU_QA_SQL/oracle/RECREATE_SCHEMA.sql $YADAMU_LOG_PATH/$YADAMU_DB "sakila$SCHEMAID" 
export YADAMU_DB=oracle12c
source $YADAMU_INSTALL/$YADAMU_DB/env/dbConnection.sh
sqlplus $DB_USER/$DB_PWD@$DB_CONNECTION @$YADAMU_QA_SQL/oracle/RECREATE_MSSQL_ALL.sql $YADAMU_LOG_PAT/$YADAMU_DBH $SCHEMAID 
sqlplus $DB_USER/$DB_PWD@$DB_CONNECTION @$YADAMU_QA_SQL/oracle/RECREATE_ORACLE_ALL.sql $YADAMU_LOG_PATH/$YADAMU_DB $SCHEMAID 
sqlplus $DB_USER/$DB_PWD@$DB_CONNECTION @$YADAMU_QA_SQL/oracle/RECREATE_SCHEMA.sql $YADAMU_LOG_PATH/$YADAMU_DB "jtest$SCHEMAID" 
sqlplus $DB_USER/$DB_PWD@$DB_CONNECTION @$YADAMU_QA_SQL/oracle/RECREATE_SCHEMA.sql $YADAMU_LOG_PATH/$YADAMU_DB "sakila$SCHEMAID" 
export YADAMU_DB=oracle11g
source $YADAMU_INSTALL/$YADAMU_DB/env/dbConnection.sh
sqlplus $DB_USER/$DB_PWD@$DB_CONNECTION @$YADAMU_QA_SQL/oracle/RECREATE_MSSQL_ALL.sql $YADAMU_LOG_PATH/$YADAMU_DB $SCHEMAID 
sqlplus $DB_USER/$DB_PWD@$DB_CONNECTION @$YADAMU_QA_SQL/oracle/RECREATE_ORACLE_ALL.sql $YADAMU_LOG_PATH/$YADAMU_DB $SCHEMAID 
sqlplus $DB_USER/$DB_PWD@$DB_CONNECTION @$YADAMU_QA_SQL/oracle/RECREATE_SCHEMA.sql $YADAMU_LOG_PATH/$YADAMU_DB "jtest$SCHEMAID" 
sqlplus $DB_USER/$DB_PWD@$DB_CONNECTION @$YADAMU_QA_SQL/oracle/RECREATE_SCHEMA.sql $YADAMU_LOG_PATH/$YADAMU_DB "sakila$SCHEMAID" 
export YADAMU_DB=mssql
source $YADAMU_INSTALL/$YADAMU_DB/env/dbConnection.sh
echo ":setvar ID ''" > setvars.sql
export SQLCMDINI=setvars.sql
export DATABASE=$DB_DBNAME
sqlcmd -U$DB_USER -P$DB_PWD -S$DB_HOST -d$DB_DBNAME -I -e -i$YADAMU_QA_SQL/mssql/RECREATE_MSSQL_ALL.sql >$YADAMU_LOG_PATH/$YADAMU_DB/RECREATE_SCHEMA.log
sqlcmd -U$DB_USER -P$DB_PWD -S$DB_HOST -d$DB_DBNAME -I -e -i$YADAMU_QA_SQL/mssql/RECREATE_ORACLE_ALL.sql >>$YADAMU_LOG_PATH/$YADAMU_DB/RECREATE_SCHEMA.log
export MSSQL_SCHEMA=AdventureWorksAll
sqlcmd -U$DB_USER -P$DB_PWD -S$DB_HOST -d$DB_DBNAME -I -e -i$YADAMU_QA_SQL/mssql/RECREATE_SCHEMA.sql >> $YADAMU_LOG_PATH/$YADAMU_DB/RECREATE_SCHEMA.log
export MSSQL_SCHEMA=jtest
sqlcmd -U$DB_USER -P$DB_PWD -S$DB_HOST -d$DB_DBNAME -I -e -i$YADAMU_QA_SQL/mssql/RECREATE_SCHEMA.sql >> $YADAMU_LOG_PATH/$YADAMU_DB/RECREATE_SCHEMA.log
export MSSQL_SCHEMA=sakila
sqlcmd -U$DB_USER -P$DB_PWD -S$DB_HOST -d$DB_DBNAME -I -e -i$YADAMU_QA_SQL/mssql/RECREATE_SCHEMA.sql >> $YADAMU_LOG_PATH/$YADAMU_DB/RECREATE_SCHEMA.log
unset SQLCMDINI
rm setvars.sql
export YADAMU_DB=mysql
source $YADAMU_INSTALL/$YADAMU_DB/env/dbConnection.sh
mysql.exe -u$DB_USER -p$DB_PWD -h$DB_HOST -D$DB_DBNAME -P$DB_PORT -v -f --init-command="set @ID='%SCHEMAID%'" <$YADAMU_QA_SQL/mysql/RECREATE_MSSQL_ALL.sql >$YADAMU_LOG_PATH/$YADAMU_DB/RECREATE_SCHEMA.log
mysql.exe -u$DB_USER -p$DB_PWD -h$DB_HOST -D$DB_DBNAME -P$DB_PORT -v -f --init-command="set @ID='%SCHEMAID%';"<$YADAMU_QA_SQL/mysql/RECREATE_ORACLE_ALL.sql >>$YADAMU_LOG_PATH/$YADAMU_DB/RECREATE_SCHEMA.log
mysql.exe -u$DB_USER -p$DB_PWD -h$DB_HOST -D$DB_DBNAME -P$DB_PORT -v -f --init-command="set @SCHEMA='jtest%SCHEMAID%'" <$YADAMU_QA_SQL/mysql/RECREATE_SCHEMA.sql >>$YADAMU_LOG_PATH/$YADAMU_DB/RECREATE_SCHEMA.log
mysql.exe -u$DB_USER -p$DB_PWD -h$DB_HOST -D$DB_DBNAME -P$DB_PORT -v -f --init-command="set @SCHEMA='sakila%SCHEMAID%'" <$YADAMU_QA_SQL/mysql/RECREATE_SCHEMA.sql >>$YADAMU_LOG_PATH/$YADAMU_DB/RECREATE_SCHEMA.log
export YADAMU_DB=mariadb
source $YADAMU_INSTALL/$YADAMU_DB/env/dbConnection.sh
mysql.exe -u$DB_USER -p$DB_PWD -h$DB_HOST -D$DB_DBNAME -P$DB_PORT -v -f --init-command="set @ID='%SCHEMAID%'" <$YADAMU_QA_SQL/mariadb/RECREATE_MSSQL_ALL.sql >$YADAMU_LOG_PATH/$YADAMU_DB/RECREATE_SCHEMA.log
mysql.exe -u$DB_USER -p$DB_PWD -h$DB_HOST -D$DB_DBNAME -P$DB_PORT -v -f --init-command="set @ID='%SCHEMAID%';"<$YADAMU_QA_SQL/mariadb/RECREATE_ORACLE_ALL.sql >>$YADAMU_LOG_PATH/$YADAMU_DB/RECREATE_SCHEMA.log
mysql.exe -u$DB_USER -p$DB_PWD -h$DB_HOST -D$DB_DBNAME -P$DB_PORT -v -f --init-command="set @SCHEMA='jtest%SCHEMAID%'" <$YADAMU_QA_SQL/mariadb/RECREATE_SCHEMA.sql >>$YADAMU_LOG_PATH/$YADAMU_DB/RECREATE_SCHEMA.log
mysql.exe -u$DB_USER -p$DB_PWD -h$DB_HOST -D$DB_DBNAME -P$DB_PORT -v -f --init-command="set @SCHEMA='sakila%SCHEMAID%'" <$YADAMU_QA_SQL/mariadb/RECREATE_SCHEMA.sql >>$YADAMU_LOG_PATH/$YADAMU_DB/RECREATE_SCHEMA.log
export YADAMU_DB=postgres
source $YADAMU_INSTALL/$YADAMU_DB/env/dbConnection.sh
psql -U $DB_USER -d $DB_DBNAME -h $DB_HOST -a -vID=%SCHEMAID% -f $YADAMU_QA_SQL/postgres/RECREATE_MSSQL_ALL.sql >$YADAMU_LOG_PATH/$YADAMU_DB/RECREATE_SCHEMA.log
psql -U $DB_USER -d $DB_DBNAME -h $DB_HOST -a -vID=%SCHEMAID% -f $YADAMU_QA_SQL/postgres/RECREATE_ORACLE_ALL.sql >>$YADAMU_LOG_PATH/$YADAMU_DB/RECREATE_SCHEMA.log
psql -U $DB_USER -d $DB_DBNAME -h $DB_HOST -a -vSCHEMA=jtest -vID=%SCHEMAID% -f $YADAMU_QA_SQL/postgres/RECREATE_SCHEMA.sql >> $YADAMU_LOG_PATH/$YADAMU_DB/RECREATE_SCHEMA.log
psql -U $DB_USER -d $DB_DBNAME -h $DB_HOST -a -vSCHEMA=sakila -vID=%SCHEMAID% -f $YADAMU_QA_SQL/postgres/RECREATE_SCHEMA.sql >> $YADAMU_LOG_PATH/$YADAMU_DB/RECREATE_SCHEMA.log
