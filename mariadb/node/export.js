"use strict";
const fs = require('fs');
const path = require('path');

const Yadamu = require('../../common/yadamuCore.js');
const FileWriter = require('../../common/fileWriter.js');
const MariaCore = require('./mariaCore.js');const DBReader = require('./dbReader.js');

const EXPORT_VERSION = 1.0;
const DATABASE_VENDOR = 'MariaDB';

function processFile(conn, schema, outputStream ,mode, status,logWriter) {
  
  return new Promise(function (resolve,reject) {
    try {
      const fileWriter = new FileWriter(outputStream,status,logWriter);
      fileWriter.on('error',function(err){logWriter.write(`${err}\n${err.stack}\n`);})
      fileWriter.on('finish', function(){resolve()});
      const dbReader = new DBReader(conn,schema,fileWriter,mode,status,logWriter);
      dbReader.on('error',function(err){logWriter.write(`${err}\n${err.stack}\n`);})
      dbReader.pipe(fileWriter);
    } catch (e) {
      logWriter.write(`${e}\n${e.stack}\n`);
      reject(e);
    }
  })
}

function closeFile(outStream) {
        
  return new Promise(function(resolve,reject) {
    outStream.on('finish',function() { resolve() });
    outStream.close();
  })

}

async function main(){

  let pool;
  let conn;
  let parameters;
  let logWriter = process.stdout;
  let status;
  
  try {
    process.on('unhandledRejection', function (err, p) {
      logWriter.write(`${new Date().toISOString()}: Unhandled Rejection\n`);
      logWriter.write(`${err}\n${err.stack}\n`);
    })
          
    parameters = MariaCore.processArguments(process.argv);
    status = Yadamu.getStatus(parameters,'Export');
    
    if (parameters.LOGFILE) {
      logWriter = fs.createWriteStream(parameters.LOGFILE,{flags : "a"});
    }
    
    pool = await MariaCore.getConnectionPool(parameters,status,logWriter);
    conn = await MariaCore.getConnectionFromPool(pool,status,logWriter);
    
    const exportFilePath = path.resolve(parameters.FILE);
    let exportFile = fs.createWriteStream(exportFilePath);
    // exportFile.on('error',function(err) {console.log(err)})
    logWriter.write(`${new Date().toISOString()}[Export]: Generating file "${exportFilePath}".\n`)
    
    await processFile(conn,parameters.OWNER,exportFile,'DATA_ONLY',status,logWriter);
    await closeFile(exportFile);
	await conn.end();
    conn = undefined;
    
    Yadamu.reportStatus(status,logWriter);
  } catch (e) {
    if (logWriter !== process.stdout) {
      console.log(`Export operation failed: See "${parameters.LOGFILE}" for details.`);
      logWriter.write('Export operation failed.\n');
      logWriter.write(`${e.stack}\n`);
    }
    else {
        console.log('Export operation Failed.');
        console.log(e);
    }
    if (conn !== undefined) {
      await conn.end();
    }
  }
  
  if (logWriter !== process.stdout) {
    logWriter.close();
  }    
  
  if (status.sqlTrace) {
    status.sqlTrace.close();
  }
  
  setTimeout(function() { process.exit()},500)
}

main();