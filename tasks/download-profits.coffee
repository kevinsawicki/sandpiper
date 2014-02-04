async   = require 'async'
es      = require 'event-stream'
path    = require 'path'
request = require 'request'
zlib    = require 'zlib'

# Download the profits or losses for all companies
module.exports = (grunt) ->
  grunt.registerTask 'download-profits', 'Download profits for all companies', ->
    done = @async()

    companies = grunt.file.readJSON('gen/companies.json')
    companiesWithoutProfits = companies.filter ({protifts}) -> not profits?
    companiesById = {}
    companiesById[company.id] = company for company in companiesWithoutProfits

    async.map [1, 2, 3, 4], readQuarterIndex, (error, quarters) ->
      return done(error) if error?

      reports = []
      reports = reports.concat(quarter) for quarter in quarters

      for report, index in reports
        reports[index] = {report, company: companiesById[report.id]}

      async.map reports, downloadProfits, (error, profits) ->
        return done(error) if error?

downloadProfits = ({company, report}, callback) ->
  getReportUri (error, reportUri) ->
    return callback(error) if error?

    request reportUri, (error, response, body) ->
      return callback(error) if error?

      # TODO Parse profits from report
      # NetIncomeLoss
      # NetIncomeLossAvailableToCommonStockholdersBasic
      # NetIncomeLossAvailableToCommonStockholdersDiluted

# Find the 10-K report URI for a company
getReportUri = ({company, report}, callback) ->
  reportId = path.basename(report.path, path.extname(report.path)).replace(/-/g, '')
  folderUri = "http://www.sec.gov/Archives/edgar/data/#{company.id}/#{reportId}"

  request folderUri, (error, response, body) ->
    return callback(error) if error?

    [reportName] = new RegExp("#{company.symbol}-\\d+\\.xml", 'i').exec(body)
    if reportName
      callback(null "#{folderUri}/#{reportName}")
    else
      callback(new Error("No report found for #{company.symbol}"))

# Download, uncompress, and parse the master index for the given quarter.
readQuarterIndex = (quarter, callback) ->
  year = new Date().getFullYear() - 1
  uri = "http://www.sec.gov/Archives/edgar/full-index/#{year}/QTR#{quarter}/master.gz"
  reports = []

  pipeline = es.pipeline(
    request(uri),
    zlib.createGunzip(),
    es.split(),
    es.map (line='', callback) ->
      [id, name, reportType, reportDate, reportPath] = line.split('|')
      id = parseInt(id)
      reportType = reportType?.trim()
      reportDate = reportDate?.trim()
      reportPath = reportPath?.trim()
      if id and reportDate and reportPath and reportType is '10-K'
        reports.push({id, date: reportDate, path: reportPath})
      callback()
  )
  pipeline.on 'error', (error) -> callback(error)
  pipeline.on 'end', -> callback(null, reports)
