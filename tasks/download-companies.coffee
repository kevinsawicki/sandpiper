_       = require 'underscore'
async   = require 'async'
es      = require 'event-stream'
request = require 'request'
zlib    = require 'zlib'

module.exports = (grunt) ->
  grunt.registerTask 'download-companies', 'Download all companies that filed a 10K', ->
    done = @async()

    async.map [1, 2, 3, 4], readQuarterIndex, (error, quarters) ->
      return done(error) if error?

      companies = []
      companies = companies.concat(quarter) for quarter in quarters

      companies = _.uniq companies, ({id}) -> id
      companies.sort (company1, company2) ->
        company1.name.toLowerCase().localeCompare(company2.name.toLowerCase())

      companiesJson = JSON.stringify(companies, null, 2)
      grunt.file.write 'gen/companies.json', companiesJson
      grunt.log.ok """
        Downloaded #{companies.length} companies that filed a 10-K in #{new Date().getFullYear() - 1}
      """
      done()

# Download, uncompress, and parse the master index for the given quarter.
readQuarterIndex = (quarter, callback) ->
  year = new Date().getFullYear() - 1
  uri = "http://www.sec.gov/Archives/edgar/full-index/#{year}/QTR#{quarter}/master.gz"
  companies = []

  pipeline = es.pipeline(
    request(uri),
    zlib.createGunzip(),
    es.split(),
    es.map (line='', callback) ->
      [id, name, reportType] = line.split('|')
      id = parseInt(id)
      name = name?.trim()
      reportType = reportType?.trim()
      companies.push({id, name}) if id and name and reportType is '10-K'
      callback()
  )
  pipeline.on 'error', (error) -> callback(error)
  pipeline.on 'end', -> callback(null, companies)
