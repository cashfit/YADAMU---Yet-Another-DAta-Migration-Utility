"use strict" 


class FileStatistics {
    
  constructor() {
     this.tableInfo = {}
     this.tableName = undefined;
     this.parameters = {}
  }
  
  isValidDDL() {
    return true;
  }
  
  setSystemInformation(systemInformation) {
    this.systemInformation = systemInformation
  }
  
  setMetadata(metadata) {
  }
    
  async executeDDL(schema, ddl) {
  }

  /*  
  **
  **  Connect to the database. Set global setttings
  **
  */
  
  async initialize() {
  }

  /*
  **
  **  Gracefully close down the database connection.
  **
  */

  async finalize() {
    return {}    
  }

  /*
  **
  **  Abort the database connection.
  **
  */

  async abort() {
  }

  async initializeExport() {
  }

  async finalizeExport() {
  }

  async initializeImport() {
  }

  async initializeData() {
  }

  async finalizeData() {
  }

  async finalizeImport() {
  }

  /*
  **
  ** Commit the current transaction
  **
  */
  
  async commitTransaction() {
  }

  /*
  **
  ** Abort the current transaction
  **
  */
  
  async rollbackTransaction() {
  }
  
  /*
  **
  ** The following methods are used by JSON_TABLE() style import operations  
  **
  */

  /*
  **
  **  Upload a JSON File to the server. Optionally return a handle that can be used to process the file
  **
  */
  async generateStatementCache(StatementGenerator,schema,executeDDL) {
  }
  
  async uploadFile(importFilePath) {
  }
  
  /*
  **
  **  Process a JSON File that has been uploaded to the server. 
  **
  */

  async processFile(mode,schema,hndl) {
  }
  
  /*
  **
  ** The following methods are used by the YADAMU DBReader class
  **
  */
  
  /*
  **
  **  Generate the SystemInformation object for an Export operation
  **
  */
  
  async getSystemInformation(schema,EXPORT_VERSION) {     
  }

  /*
  **
  **  Generate a set of DDL operations from the metadata generated by an Export operation
  **
  */

  async getDDLOperations(schema) {
    return []
  }
  
  async getSchemaInfo(schema) {
    return []
  }

  /*
  **
  ** The following methods are used by the YADAMU DBwriter class
  **
  */
  
  async initializeDataLoad(databaseVendor) {     
    this.tableInfo = {}
  }

  getTableWriter(tableName) {

    this.tableInfo[tableName] = {
      rowCount  : 0
     ,byteCount : 2
     ,hash      : null
    }    
    this.tableName = tableName;
    return this;
  }
  
  batchComplete() {
    return false
  }
  
  commitWork(rowCount) {
    return false;
  }

  async appendRow(row) { 

    this.tableInfo[this.tableName].rowCount++;
    this.tableInfo[this.tableName].byteCount+= JSON.stringify(row).length;    
  }

  async writeBatch() {
    if  (this.tableInfo[this.tableName].rowCount > 1) {
      this.tableInfo[this.tableName].byteCount += this.tableInfo[this.tableName].rowCount - 1;
    }
  }    

}

module.exports = FileStatistics