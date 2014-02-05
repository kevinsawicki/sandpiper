async       = require 'async'
dates       = require '../src/date-helpers'
{DOMParser} = require 'xmldom'
es          = require 'event-stream'
path        = require 'path'
ProgressBar = require 'progress'
request     = require 'request'
xpath       = require 'xpath'
zlib        = require 'zlib'

# Download the profits or losses for all companies
module.exports = (grunt) ->

  # Prevents: warning: possible EventEmitter memory leak detected.
  process.setMaxListeners(0)

  grunt.registerTask 'download-profits', 'Download profits for all companies', ->
    done = @async()

    companies = grunt.file.readJSON('gen/companies.json')
    companiesWithoutProfits = companies.filter ({profits}) -> not profits?
    companiesById = {}
    companiesById[company.id] = company for company in companiesWithoutProfits

    getReports (error, reports) ->
      report.company = companiesById[report.id] for report in reports

      progress = new ProgressBar('Downloading profits for :current/:total companies [:bar] :percent :eta seconds remaining', {
        incomplete: ' '
        width: 20
        total: companiesWithoutProfits.length
      })

      queue = async.queue (report, callback) ->
        downloadProfits report, (error) ->
          progress.tick(1)

          companiesJson = JSON.stringify(companies, null, 2)
          grunt.file.write 'gen/companies.json', companiesJson

          callback(error)

      queue.drain = done
      queue.concurrency = 10
      queue.push(report) for report in reports

downloadProfits = (report, callback) ->
  getReportUri report, (error, reportUri) ->
    return callback(error) if error?

    request reportUri, (error, response, body) ->
      return callback(error) if error?

      document = new DOMParser().parseFromString(body)
      elements = [
        'NetIncomeLoss'
        'NetIncomeLossAvailableToCommonStockholdersBasic'
        'NetIncomeLossAvailableToCommonStockholdersDiluted'
      ]

      for element in elements
        if profits = profitsForElement(document, element)
          report.company.profits = profits
          break

      callback()

# Attempt to parse the yearly profits from the document using the element name.
profitsForElement = (document, elementName) ->
  nodes = xpath.select("//*[local-name() = '#{elementName}']", document)
  profits = null
  for node in nodes when node.prefix is 'us-gaap'
    profit = parseFloat(node.firstChild?.data)
    continue if isNaN(profit)

    year = dates.yearOfNode(node)
    if year isnt -1
      profits ?= {}
      profits["#{year}"] = profit

  profits

# Find the 10-K report URI for a company
getReportUri = (report, callback) ->
  reportId = path.basename(report.path, path.extname(report.path)).replace(/-/g, '')
  folderUri = "http://www.sec.gov/Archives/edgar/data/#{report.company.id}/#{reportId}"

  request folderUri, (error, response, body) ->
    return callback(error) if error?

    [reportName] = new RegExp("#{report.company.symbol}-\\d+\\.xml", 'i').exec(body) ? []
    if reportName
      callback(null, "#{folderUri}/#{reportName}")
    else
      callback(new Error("No report found for #{report.company.symbol}"))

# Get the 10-K report information for all quarters in the last year.
getReports = (callback) ->
  async.map [1, 2, 3, 4], readQuarterIndex, (error, quarters) ->
    return callback(error) if error?

    reports = []
    reports = reports.concat(quarter) for quarter in quarters
    callback(null, reports)

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
