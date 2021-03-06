"use strict"

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { performance } = require('perf_hooks');
const FileDBI = require('../file/node/fileDBI.js');
const DBReader = require('./dbReader.js');
const DBWriter = require('./dbWriter.js');
const DBReaderParallel = require('./dbReaderMaster.js');
const DBWriterParallel = require('./dbWriterMaster.js');
const YadamuLogger = require('./yadamuLogger.js');
const YadamuLibrary = require('./yadamuLibrary.js');
const YadamuDefaults = require('./yadamuDefaults.json');
const {YadamuError, UserError, CommandLineError, ConfigurationFileError} = require('./yadamuError.js');

class Yadamu {

  get EXPORT_VERSION() { return '1.0' };
  get YADAMU_DEFAULT_PARAMETERS() { return YadamuDefaults.yadamu }
     
  static nameMatch(source,target,rule) {
      
    switch (rule)  {
    
      case 'EXACT':
        if (source === target) {
          return true;
        }
        break;
      case 'UPPER':
        if (source.toUpperCase() === target) {
           return true;
        }
        break;
      case 'LOWER': 
        if (source.toLowerCase() === target) {
           return true;
        }
        break;
      case 'INSENSITIVE':
        if (source.toLowerCase() === target.toLowerCase()) {
           return true;
        }
      default:
    }
  }

  getDefaultDatabase() {
	 if (this.parameters.RDBMS) {
	   return this.parameters.RDBMS
	 }
	 return 'file'
  }
  
 
  reportStatus(status,yadamuLogger) {

    const endTime = performance.now();
      
    status.statusMsg = status.warningRaised === true ? 'with warnings' : status.statusMsg;
    status.statusMsg = status.errorRaised === true ? 'with errors'  : status.statusMsg;  
  
    yadamuLogger.info([`${this.constructor.name}`,`${status.operation}`],`Operation completed ${status.statusMsg}. Elapsed time: ${YadamuLibrary.stringifyDuration(endTime - status.startTime)}.`);
    if (!yadamuLogger.loggingToConsole()) {
      console.log(`${new Date().toISOString()}[${this.constructor.name}][${status.operation}]: Operation completed ${status.statusMsg}. Elapsed time: ${YadamuLibrary.stringifyDuration(endTime - status.startTime)}. See "${status.logFileName}" for details.`);  
    }
  }
  
  reportError(e,parameters,status,yadamuLogger) {
    
    if (!yadamuLogger.loggingToConsole()) {
      yadamuLogger.logException([`${this.constructor.name}`,`"${status.operation}"`],e);
      console.log(`${new Date().toISOString()} [ERROR][${this.constructor.name}][${status.operation}]: Operation failed: See "${parameters.LOG_FILE ? parameters.LOG_FILE  : 'above'}" for details.`);
    }
    else {
      console.log(`${new Date().toISOString()} [ERROR][${this.constructor.name}][${status.operation}]: Operation Failed:`);
      console.log(e);
    }
  }

  processValue(parameterValue) {

    if ((parameterValue.startsWith('"') && parameterValue.endsWith('"')) && (parameterValue.indexOf('","') > 0 )) {
      // List of Values
	  let parameterValues = parameterValue.substring(1,parameterValue.length-1).split(',');
	  parameterValues = parameterValues.map(function(value) {
        return YadamuLibrary.convertQutotedIdentifer(value);
	  })
	  return parameterValues
    }
    else {
      return YadamuLibrary.convertQuotedIdentifer(parameterValue);
    }
  }

  ensureNumeric(parameters,parameterName,parameterValue) {
     
     if (isNaN(parameterValue)) {
       console.log(`${new Date().toISOString()}[Yadamu]: Invalid Numeric value for parameter: "${parameterName}".`)         
     }
     else {
       parameters[parameterName] = parseInt(parameterValue);
     }

  }

  isTrue(value){
    if (typeof(value) === 'string'){
        value = value.trim().toLowerCase();
    }
    switch(value){
        case true:
        case "true":
        case 1:
        case "1":
        case "on":
        case "yes":
            return true;
        default: 
            return false;
    }
  }
  
  async finalize(status,yadamuLogger) {

    this.commandPrompt.close();
    await yadamuLogger.close();

    if (status.sqlTrace) {
      status.sqlTrace.close();
    }
  }
  
  async close() {
    await this.finalize(this.status,this.yadamuLogger);
  }
  
  reloadParameters(parameters) {
	 
	this.loadParameters(parameters)
    this.processParameters();    
  }
  
  loadParameters(suppliedParameters) {

    // Start with Yadamu Defaults
    this.parameters = Object.assign({}, YadamuDefaults.yadamu);

    // Merge parameters read from configuration files
    Object.assign(this.parameters, suppliedParameters ? suppliedParameters : {});

    // Merge parameters provided via command line arguments
    Object.assign(this.parameters,this.getCommandLineParameters())

  }

  processParameters() {

    this.yadamuLogger = this.setYadamuLogger(this.parameters,this.status);

    if (this.parameters.SQL_TRACE) {
	  this.status.sqlTrace = fs.createWriteStream(this.parameters.SQL_TRACE);
    }

    if (this.parameters.LOG_FILE) {
      this.status.logFileName = this.parameters.LOG_FILE;
    }

    if (this.parameters.DUMP_FILE) {
      this.status.dumpFileName = this.parameters.DUMP_FILE
    }

    if (this.parameters.LOG_LEVEL) {
      this.status.loglevel = this.parameters.LOG_LEVEL;
    }
    	
    this.status.showInfoMsgs = (this.status.loglevel && (this.status.loglevel > 2));  	

  }	  
  
  constructor(operation,parameters) {
    
    const self = this; 
	this.yadamuLogger = new YadamuLogger(process.stdout)

    process.on('unhandledRejection', (err, p) => {
      self.yadamuLogger.logException([`${self.constructor.name}.onUnhandledRejection()`,`"${self.status.operation}"`],err);
      self.reportStatus(self.status,self.yadamuLogger)
      process.exit()
    })

    this.status = {
      operation     : operation
     ,errorRaised   : false
     ,warningRaised : false
     ,statusMsg     : 'successfully'
     ,startTime     : performance.now()
    }

    // Read Command Line Parameters
    this.commandLineParameters = this.readCommandLineParameters();
	this.loadParameters(parameters)
    this.processParameters();    
	
	// Use an object to pass the prompt to ensure changes to prompt are picked up insde the writeToOutput function closure()

    this.cli = { 
	  "prompt" : null
	} 

    this.commandPrompt = readline.createInterface({input: process.stdin, output: process.stdout});
    this.commandPrompt._writeToOutput = function _writeToOutput(charsToWrite) {
	  if (charsToWrite.startsWith(self.cli.prompt)) {
        self.commandPrompt.output.write(self.cli.prompt + '*'.repeat(charsToWrite.length-self.cli.prompt.length))
      } 
	  else {
	    self.commandPrompt.output.write(charsToWrite.length > 1 ? charsToWrite : "*")
      }
    };	
	
  }
     
  createQuestion(prompt) {	
    const self = this
	this.cli.prompt = prompt;
    return new Promise(function (resolve,reject) {
      self.commandPrompt.question(self.cli.prompt, function(answer) {
		resolve(answer);
	  })
	})
  }
  
  cloneDefaultParameters() {
     const parameters = Object.assign({},YadamuDefaults.yadamu)
     Object.assign(parameters, YadamuDefaults.yadamuDBI)
     return parameters
  }

  getStatus() {
    return this.status
  }
  
  getYadamuDefaults() {
    return YadamuDefaults
  }

  getYadamuLogger() {
    return this.yadamuLogger
  }
  
  getConfigFilePath() {
    return this.commandLineParameters.CONFIG
  }

  getCommandLineParameters() {
    return this.commandLineParameters
  }
    
  readCommandLineParameters() {
   
    const parameters = {}
 
    process.argv.forEach(function (arg) {
     
      if (arg.indexOf('=') > -1) {
        const parameterName = arg.substring(0,arg.indexOf('='));
        const parameterValue = arg.substring(arg.indexOf('=')+1);
        switch (parameterName.toUpperCase()) {
	      case 'INIT':		  
	      case '--INIT':
	      case 'COPY':		  
	      case '--COPY':
	      case 'TEST':		  
	      case '--TEST':
			parameters.CONFIG = parameterValue;
			break;
          case 'IMPORT':
          case '--IMPORT':
          case 'UPLOAD':		  
	      case '--UPLOAD':
  	      case 'EXPORT':
          case '--EXPORT':
			parameters.FILE = parameterValue;
            break;
          case 'RDBMS':
          case '--RDBMS':
            parameters.RDBMS = parameterValue;
            break;
	      case 'OVERWRITE':		  
	      case '--OVERWRITE':
  	        parameters.OVERWRITE = this.isTrue(parameterValue.toUpperCase());
		    break;
          case 'CONFIG':
          case '--CONFIG':
          case 'CONFIGURATION':
          case '--CONFIGURATION':
            parameters.CONFIG = parameterValue;
			parameters.FILE = parameterValue;
            break;
	      case 'USERID':
  	        parameters.USERID = parameterValue;
			break;
          case 'USERNAME':
          case '--USERNAME':
            parameters.USERNAME = parameterValue;
            break;
          case 'PASSWORD':
          case '--PASSWORD':
		    console.log(`${new Date().toISOString()} [WARNING][${this.constructor.name}]: Suppling a password on the command line interface can be insecure`);
            parameters.PASSWORD = parameterValue;
            break;
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
          case 'FILE':
          case '--FILE':
		    if (parameters.IMPORT || parameters.EXPORT) {
			  throw new error(`Cannot combine legacy parameter FILE with IMPORT or EXPORT`);
			}
            parameters.FILE = parameterValue;
            break;
          case 'OWNER':
          case '--OWNER':
          case 'FROM_USER':
          case '--FROM_USER':
            parameters.FROM_USER = this.processValue(parameterValue);
            break;
          case 'TOUSER':
          case '--TOUSER':
          case 'TO_USER':
          case '--TO_USER':
            parameters.TO_USER = this.processValue(parameterValue);
            break;
          case 'PARALLEL':
          case '--PARALLEL':
            parameters.PARALLEL = parameterValue;
            break;
          case 'LOG_FILE':
          case '--LOG_FILE':
            parameters.LOG_FILE = parameterValue;
            break;
          case 'SQL_TRACE':
          case '--SQL_TRACE':
            parameters.SQL_TRACE = parameterValue;
            break;
          case 'PERF_TRACE':
          case '--PERF_TRACE':
		  case 'PERFORMANCE_TRACE':
          case '--PERFORMANCE_TRACE':
            parameters.PERFORMANCE_TRACE = parameterValue;
            break;
                    case '--SQL_TRACE':
            parameters.SQL_TRACE = parameterValue;
            break;
          case 'PARAMETER_TRACE':
          case '--PARAMETER_TRACE':
            parameters.PARAMETER_TRACE = (parameterValue.toLowerCase() === 'true');
            break;
          case 'SPATIAL_FORMAT':
          case '--SPATIAL_FORMAT':
            parameters.SPATIAL_FORMAT = parameterValue.toUpperCase()
            break;
          case 'LOG_LEVEL':
          case '--LOG_LEVEL':
            parameters.LOG_LEVEL = parameterValue;
            break;
          case 'DUMP_FILE':
          case '--DUMP_FILE':
            parameters.DUMP_FILE = parameterValue;
            break;
          case 'FEEDBACK':
          case '--FEEDBACK':
            parameters.FEEDBACK = parameterValue.toUpperCase();
            break;
          case 'MODE':
          case '--MODE':
            parameters.MODE = parameterValue.toUpperCase();
            break
          case 'BATCH_SIZE':
          case '--BATCH_SIZE':
            this.ensureNumeric(parameters,parameterName.toUpperCase(),parameterValue)
            break;
          case 'BATCH_COMMIT':
          case '--BATCH_COMMIT':
            this.ensureNumeric(parameters,parameterName.toUpperCase(),parameterValue)
            break;
          case 'BATCH_LOB_COUNT':
          case '--BATCH_LOB_COUNT':
            this.ensureNumeric(parameters,parameterName.toUpperCase(),parameterValue)
            break;
          default:
            console.log(`${new Date().toISOString()}[WARNING][this.constructor.name]: Unknown parameter: "${parameterName}". See yadamu --help for supported command line switches and arguments` )          
        }
      }
    },this)
    
	return parameters;
  }
  
  setYadamuLogger(parameters) {

    if (this.parameters.LOG_FILE) {
      return new YadamuLogger(fs.createWriteStream(this.parameters.LOG_FILE,{flags : "a"}),this.status);
    }
    return new YadamuLogger(process.stdout,this.status);
  
  }
  
  closeFile(outputStream) {
        
    return new Promise(function(resolve,reject) {
      outputStream.on('finish',function() { resolve() });
      outputStream.close();
    })

  }

  async getDBReader(dbi,parallel) {
	const dbReader = parallel ? new DBReaderParallel(dbi, dbi.parameters.MODE, this.status, this.yadamuLogger) : new DBReader(dbi, dbi.parameters.MODE, this.status, this.yadamuLogger);
	await dbReader.initialize();
    return dbReader;
  }
  
  async getDBWriter(dbi,parallel) {
	const dbWriter = parallel ? new DBWriterParallel(dbi, dbi.parameters.MODE, this.status, this.yadamuLogger) : new DBWriter(dbi, dbi.parameters.MODE, this.status, this.yadamuLogger);
    await dbWriter.initialize();
    return dbWriter;
  }

  async doPumpOperation(source,target) {

    const timings = {}

    try {
      const self = this
      await source.initialize();
      await target.initialize();
	  let parallel = ((this.parameters.PARALLEL) && (this.parameters.PARALLEL > 1))
	  parallel = (parallel && source.isDatabase() && target.isDatabase());
      const dbReader = await this.getDBReader(source,parallel)
      const dbWriter = await this.getDBWriter(target,parallel)  
	  const inputStream = dbReader.getInputStream();
      const copyOperation = new Promise(function (resolve,reject) {
        try {
			
          dbWriter.on('finish', function(){
			resolve()
		  })
          dbWriter.on('error',function(err){
			self.yadamuLogger.logException([`${dbWriter.constructor.name}.onError()`],err);
			reject(err)
	      })
		  
          inputStream.on('error',function(err){
			 self.yadamuLogger.logException([`${inputStream.constructor.name}.onError()`],err);
			 reject(err)
		  })
		  
          inputStream.pipe(dbWriter);
        } catch (err) {
          self.yadamuLogger.logException([`${self.constructor.name}.onError()`],err)
          reject(err);
        }
      })
      
      this.status.operationSuccessful = false;
      await copyOperation;
      await source.finalize();
      await target.finalize();
	  const timings = dbWriter.getTimings();
	  this.status.operationSuccessful = true;
      return timings
    } catch (e) {
	  this.status.operationSuccessful = false;
	  this.status.err = e;
      await source.abort(e);
	  await target.abort(e);
	  
	  if (e instanceof UserError) {
		await this.close();
	    // Prevent reportError from being called for User Errors
		throw e
	  }
    }
    return timings
  }
    
  async pumpData(source,target) {
      
    if ((source.isDatabase() === true) && (source.parameters.FROM_USER === undefined)) {
      throw new Error('Missing mandatory parameter FROM_USER');
    }

    if ((target.isDatabase() === true) && (target.parameters.TO_USER === undefined)) {
      throw new Error('Missing mandatory parameter TO_USER');
    }
   
    const timings = await this.doPumpOperation(source,target)
	switch (this.status.operationSuccessful) {
      case true:
        this.reportStatus(this.status,this.yadamuLogger)
		break;
	  case false:
        this.reportError(this.status.err,this.parameters,this.status,this.yadamuLogger);
		break;
	  default:
	}
 
    return timings
  }
  
  async doImport(dbi) {
    const fileReader = new FileDBI(this)
    const timings = await this.pumpData(fileReader,dbi);
    await this.close();
    return timings
  }  
 
  async doExport(dbi) {
    const fileWriter = new FileDBI(this)
    const timings = await this.pumpData(dbi,fileWriter);
    await this.close();
    return timings
  }  
  
  async doCopy(source,target) {
    const timings = await this.pumpData(source,target);
    await this.close();
    return timings
  }  
  
  async cloneFile(pathToFile) {

    const fileReader = new FileDBI(this)
    const fileWriter = new fileDBI(this)
    const timings = await this.pumpData(fileReader,fileWriter);
    await this.close();
    return timings
  }
  
  async uploadFile(dbi,importFilePath) {
    const stats = fs.statSync(importFilePath)
    const fileSizeInBytes = stats.size

    const startTime = performance.now();
    const json = await dbi.uploadFile(importFilePath);
    const elapsedTime = performance.now() - startTime;
    this.yadamuLogger.info([`${this.constructor.name}.uploadFile()`],`Processing file "${importFilePath}". Size ${fileSizeInBytes}. File Upload elapsed time ${YadamuLibrary.stringifyDuration(elapsedTime)}s.  Throughput ${Math.round((fileSizeInBytes/elapsedTime) * 1000)} bytes/s.`)
    return json;
  }
  
  
    
  getTimings(log) {
      
     const timings = {}
     log.forEach(function(entry) {
       switch (Object.keys(entry)[0]) {
         case 'dml' :
           timings[entry.dml.tableName] = {rowCount : entry.dml.rowCount, insertMode : "SQL", elapsedTime : entry.dml.elapsedTime + "ms", throughput: Math.round((entry.dml.rowCount/Math.round(entry.dml.elapsedTime)) * 1000).toString() + "/s"}
           break;
         case 'error' :
           timings[entry.error.tableName] = {rowCount : -1, insertMode : "SQL", elapsedTime : "NaN", throughput: "NaN"}
           break;
         default:
       }
     },this)
     return timings
  }

  
  async doUploadOperation(dbi) {

    const timings = {}

    try {
      await dbi.initialize();
      this.status.operationSuccessful = false;
      const pathToFile = dbi.parameters.FILE;
      const hndl = await this.uploadFile(dbi,pathToFile);
      const log = await dbi.processFile(hndl)
      await dbi.finalize();
	  const timings = this.getTimings(log);  
	  this.status.operationSuccessful = true;
      return timings
    } catch (e) {
	  this.status.operationSuccessful = false;
	  this.status.err = e;
      await dbi.abort(e)
    }
    return timings;
  }

  async uploadData(dbi) {
	  
    if ((dbi.isDatabase() === true) && (dbi.parameters.TO_USER === undefined)) {
      throw new Error('Missing mandatory parameter TO_USER');
    }

    if (dbi.parameters.FILE === undefined) {
      throw new Error('Missing mandatory parameter FILE');
    }
   
    const timings = await this.doUploadOperation(dbi)
	
	switch (this.status.operationSuccessful) {
      case true:
        this.reportStatus(this.status,this.yadamuLogger)
		break;
	  case false:
        this.reportError(this.status.err,this.parameters,this.status,this.yadamuLogger);
		break;
	  default:
	}
	
    return timings;
  } 
  
  async doUpload(dbi) {
    const timings = await this.uploadData(dbi);
    await this.close();
    return timings
  }  

}  
     
module.exports = Yadamu;
