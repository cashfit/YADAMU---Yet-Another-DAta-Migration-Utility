"use strict"

const YadamuCLI = require('./yadamuCLI.js')
const Yadamu = require('./yadamu.js')
const {CommandLineError} = require('./yadamuError.js');

class Import extends YadamuCLI {}

async function main() {

  try {
    const yadamuImport = new Import();
    try {
      await yadamuImport.doImport();
    } catch (e) {
      Import.reportError(e)
	}
    await yadamuImport.close();
  } catch (e) {
	Import.reportError(e)
  }

}

main()

module.exports = Import