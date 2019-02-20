"use strict";

const Yadamu = require('../../common/yadamuCore.js');
const mariadb = require('mariadb');

const sqlGenerateMetadata = 
// Cannot use JSON_ARRAYAGG for DATA_TYPES and SIZE_CONSTRAINTS beacuse MYSQL implementation of JSON_ARRAYAGG does not support ordering
 
`select c.table_schema "TABLE_SCHEMA"
       ,c.table_name "TABLE_NAME"
       ,group_concat(concat('"',column_name,'"') order by ordinal_position separator ',')  "COLUMN_LIST"
       ,concat('[',group_concat(json_quote(data_type) order by ordinal_position separator ','),']')  "DATA_TYPES"
       ,concat('[',group_concat(json_quote(
                            case when (numeric_precision is not null) and (numeric_scale is not null)
                                   then concat(numeric_precision,',',numeric_scale) 
                                 when (numeric_precision is not null)
                                   then case
                                          when column_type like '%unsigned' 
                                            then numeric_precision
                                          else
                                            numeric_precision + 1
                                        end
                                 when (datetime_precision is not null)
                                   then datetime_precision
                                 when (character_maximum_length is not null)
                                   then character_maximum_length
                                 else   
                                   ''   
                            end
                           ) 
                           order by ordinal_position separator ','
                    ),']') "SIZE_CONSTRAINTS"
       ,concat(
          'select json_array('
          ,group_concat(
            case 
              when data_type = 'date'
                -- Force ISO 8601 rendering of value 
                then concat('DATE_FORMAT(convert_tz("', column_name, '", @@session.time_zone, ''+00:00''),''%Y-%m-%dT%TZ'')')
              when data_type = 'timestamp'
                -- Force ISO 8601 rendering of value 
                then concat('DATE_FORMAT(convert_tz("', column_name, '", @@session.time_zone, ''+00:00''),''%Y-%m-%dT%T.%fZ'')')
              when data_type = 'datetime'
                -- Force ISO 8601 rendering of value 
                then concat('DATE_FORMAT("', column_name, '", ''%Y-%m-%dT%T.%f'')')
              when data_type = 'year'
                -- Prevent rendering of value as base64:type13: 
                then concat('CAST("', column_name, '"as DECIMAL)')
              when data_type like '%blob'
                -- Force HEXBINARY rendering of value
                then concat('HEX("', column_name, '")')
              when data_type = 'varbinary'
                -- Force HEXBINARY rendering of value
                then concat('HEX("', column_name, '")')
              when data_type = 'binary'
                -- Force HEXBINARY rendering of value
                then concat('HEX("', column_name, '")')
              when data_type = 'geometry'
                -- Force WKT rendering of value
                then concat('ST_asText("', column_name, '")')
              else
                concat('"',column_name,'"')
            end
            order by ordinal_position separator ','
          )
          ,') "json" from "'
          ,c.table_schema
          ,'"."'
          ,c.table_name
          ,'"'
        ) "SQL_STATEMENT"
   from information_schema.columns c, information_schema.tables t
  where t.table_name = c.table_name 
     and c.extra <> 'VIRTUAL GENERATED'
    and t.table_schema = c.table_schema
    and t.table_type = 'BASE TABLE'
    and t.table_schema = ?
	  group by t.table_schema, t.table_name`;

async function setMaxAllowedPacketSize(pool,conn,status,logWriter) {

  const maxAllowedPacketSize = 1 * 1024 * 1024 * 1024;
  const sqlQueryPacketSize = `SELECT @@max_allowed_packet`;
  const sqlSetPacketSize = `SET GLOBAL max_allowed_packet=${maxAllowedPacketSize}`
    
  if (status.sqlTrace) {
    status.sqlTrace.write(`${sqlQueryPacketSize};\n--\n`);
  }
  let results = await conn.query(sqlQueryPacketSize);
    
  if (parseInt(results[0]['@@max_allowed_packet']) <  maxAllowedPacketSize) {
    logWriter.write(`${new Date().toISOString()}: Increasing MAX_ALLOWED_PACKET to 1G.\n`);
    if (status.sqlTrace) {
      status.sqlTrace.write(`${sqlSetPacketSize};\n--\n`);
    }
    results = await conn.query(sqlSetPacketSize);
    await conn.end();
    await pool.end();
    return true;
  }    
  return false;
}

async function configureSession(conn,status) {

   const sqlAnsiQuotes = `SET SESSION SQL_MODE=ANSI_QUOTES`;
   if (status.sqlTrace) {
     status.sqlTrace.write(`${sqlAnsiQuotes};\n--\n`);
   }
   await conn.query(sqlAnsiQuotes);
   
   const sqlTimeZone = `SET TIME_ZONE = '+00:00'`;
   if (status.sqlTrace) {
     status.sqlTrace.write(`${sqlTimeZone};\n--\n`);
   }
   await conn.query(sqlTimeZone);

   const setGroupConcatLength = `SET SESSION group_concat_max_len = 1024000`
   if (status.sqlTrace) {
     status.sqlTrace.write(`${setGroupConcatLength};\n--\n`);
   }
   await conn.query(setGroupConcatLength);


}

async function getConnectionPool(parameters,status,logWriter) {
 
  const connectionDetails = {
          host               : parameters.HOSTNAME
         ,user               : parameters.USERNAME
         ,password           : parameters.PASSWORD
         ,database           : parameters.DATABASE
         ,port               : parameters.PORT ? parameters.PORT : 3307
         ,multipleStatements : true
         ,typeCast           : false
         ,supportBigNumbers  : true
         ,bigNumberStrings   : true          
         ,dateStrings        : true
  }

  
  const  pool = mariadb.createPool(connectionDetails);
  const conn = await pool.getConnection();
    
  if (await setMaxAllowedPacketSize(pool,conn,status,logWriter)) {
       pool = mariadb.createPool(connectionDetails);
  }     
  
  return pool;

}

async function getConnectionFromPool(pool,status,logWriter) {
 
  const conn = await pool.getConnection();
  await configureSession(conn,status);
  return conn
    
}

async function createTargetDatabase(conn,status,schema) {    	
  const sqlStatement = `CREATE DATABASE IF NOT EXISTS "${schema}"`;					   
  if (status.sqlTrace) {
    status.sqlTrace.write(`${sqlStatement};\n--\n`);
  }
  const results = await conn.query(sqlStatement,schema);
  return results;
}

function processArguments(args) {

   const parameters = {
	                 FILE       : "export.json"
                    ,MODE       : "DDL_AND_CONTENT"
                    ,BATCHSIZE  : 100
                    ,COMMITROWS : 1000
   }

   process.argv.forEach(function (arg) {
	   
	 if (arg.indexOf('=') > -1) {
       const parameterName = arg.substring(0,arg.indexOf('='));
	   const parameterValue = arg.substring(arg.indexOf('=')+1);
	    switch (parameterName.toUpperCase()) {
	      case 'DATABASE':
	      case '--DATABASE':
  	        parameters.DATABASE = parameterValue;
			break;
	      case 'HOSTNAME':
	      case '--HOSTNAME':
  	        parameters.HOSTNAME = parameterValue;
			break;
	      case 'HOSTNAME':
	      case '--HOSTNAME':
  	        parameters.HOSTNAME = parameterValue;
			break;
	      case 'PORT':
	      case '--PORT':
	        parameters.PORT = parameterValue;
			break;
	      case 'PASSWORD':
	      case '--PASSWORD':
	        parameters.PASSWORD = parameterValue;
			break;
	      case 'USERNAME':
	      case '--USERNAME':
	        parameters.USERNAME = parameterValue;
			break;
	      case 'FILE':
	      case '--FILE':
	        parameters.FILE = parameterValue;
			break;
	      case 'OWNER':
	      case '--OWNER':
		    parameters.OWNER = Yadamu.processValue(parameterValue);
			break;
	      case 'FROMUSER':
	      case '--FROMUSER':
		    parameters.FROMUSER = Yadamu.processValue(parameterValue);
			break;
	      case 'TOUSER':
	      case '--TOUSER':
		    parameters.TOUSER = Yadamu.processValue(parameterValue);
			break;
	      case 'LOGFILE':
	      case '--LOGFILE':
		    parameters.LOGFILE = parameterValue;
			break;
	      case 'SQLTRACE':
	      case '--SQLTRACE':
		    parameters.SQLTRACE = parameterValue;
			break;
	      case 'LOGLEVEL':
	      case '--LOGLEVEL':
		    parameters.LOGLEVEL = parameterValue;
			break;
	      case 'DUMPFILE':
	      case '--DUMPFILE':
		    parameters.DUMPFILE = parameterValue.toUpperCase();
			break;
	      case 'BATCHSIZE':
	      case '--BATCHSIZE':
		    parameters.BATCHSIZE = parameterValue
			break;
	      case 'COMMITSIZE':
	      case '--COMMITSIZE':
		    parameters.COMMITSIZE = parameterValue
			break;
          case 'MODE':
		    parameters.MODE = parameterValue.toUpperCase();
			break;
		  default:
		    console.log(`Unknown parameter: "${parameterName}".`)			
	   }
	 }
   })
   
   return parameters;
}

async function getTableInfo(conn,schema,status) {
             
    if (status.sqlTrace) {
      status.sqlTrace.write(`${sqlGenerateMetadata}\n\/\n`)
    }
    
	return await conn.query(sqlGenerateMetadata,[schema]);

}

function generateMetadata(tableInfo) {
    
  const metadata = {} 
  for (let table of tableInfo) {
    metadata[table.TABLE_NAME] = {
      owner                    : table.TABLE_SCHEMA
     ,tableName                : table.TABLE_NAME
     ,columns                  : table.COLUMN_LIST
     ,dataTypes                : JSON.parse(table.DATA_TYPES)
     ,sizeConstraints          : JSON.parse(table.SIZE_CONSTRAINTS)
    }
  }
  return metadata;    

}

module.exports.processArguments        = processArguments
module.exports.getConnectionPool       = getConnectionPool
module.exports.getConnectionFromPool   = getConnectionFromPool
module.exports.createTargetDatabase    = createTargetDatabase
module.exports.getTableInfo            = getTableInfo
module.exports.generateMetadata        = generateMetadata
