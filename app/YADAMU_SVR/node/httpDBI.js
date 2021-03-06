"use strict" 

const YadamuDBI = require('../../YADAMU/common/yadamuDBI.js');
const TextParser = require('../../YADAMU/file/node/fileParser.js')
const TableWriter = require('../../YADAMU/file/node/tableWriter.js')

/*
**
** YADAMU Database Inteface class skeleton
**
*/

class HttpDBI extends YadamuDBI {

  getConnectionProperties() {
    return {}
  }
  
  isDatabase() {
    return false;
  }
  
  objectMode() {
     return false;
  }
  
  getInputStream() {
    return this.stream.pipe(this.parser);
  }
  get DATABASE_VENDOR()    { return 'HTTP' };
  get SOFTWARE_VENDOR()    { return 'N/A' };
  get SPATIAL_FORMAT()     { return this.spatialFormat };
  get DEFAULT_PARAMETERS() { return this.yadamu.getYadamuDefaults().http }
  
  constructor(yadamu,httpStream) {
    super(yadamu,yadamu.getYadamuDefaults().http)    
	this.stream = httpStream;
	this.firstTable = true;							 
  }

  isValidDDL() {
    return true;
  }
  
  setSystemInformation(systemInformation) {
    this.stream.write(`"systemInformation":${JSON.stringify(systemInformation)}`);								  
				 
  }
	 
  setMetadata(metadata) {
    this.stream.write(',');
    this.stream.write(`"metadata":${JSON.stringify(metadata)}`);
  }
    
  async executeDDL(ddl) {
    this.stream.write(',');
    this.stream.write(`"ddl":${JSON.stringify(ddl)}`);							   
  }

  async initialize() {
    super.initialize(false);
    this.spatialFormat = this.parameters.SPATIAL_FORMAT ? this.parameters.SPATIAL_FORMAT : super.SPATIAL_FORMAT   
  }
  
  async initializeExport() {
	super.initializeExport();
    this.parser = new TextParser(this.yadamuLogger);
  }
  async initializeImport() {				  
    super.initializeImport()						
    this.stream.write(`{`)  
  }

  async initializeData() {
    this.stream.write(',');
    this.stream.write('"data":{');      
  }
  
  async finalizeData() {
    this.stream.write('}');
  }  
  
  async finalizeImport() {
    this.stream.write('}')    
   }
  async finalize() {
  }
 
 
  /*
  **
  **  Generate a set of DDL operations from the metadata generated by an Export operation
  **
  */

  async getDDLOperations() {
    return []
  }
  
  async getSchemaInfo(schema) {
    return null
  }

  getTableWriter(tableName) {

    if (this.firstTable === true) {
      this.firstTable = false
    }
    else {
      this.stream.write(',');
    }

    return new TableWriter(tableName,this.stream);      
  }

}

module.exports = HttpDBI
