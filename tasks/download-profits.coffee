_           = require 'underscore'
async       = require 'async'
dates       = require '../src/date-helpers'
{DOMParser} = require 'xmldom'
es          = require 'event-stream'
path        = require 'path'
ProgressBar = require 'progress'
request     = require 'request'
xpath       = require 'xpath'
zlib        = require 'zlib'

require('events').defaultMaxListeners = Infinity

# Download the profits or losses for all companies
module.exports = (grunt) ->
  grunt.registerTask 'download-profits', 'Download profits for all companies', ->
    done = @async()

    companies = grunt.file.readJSON('gen/companies.json')
    if companyId = parseInt(grunt.option('company-id'))
      companiesWithoutProfits = companies.filter ({id}) -> id is companyId
    else
      companiesWithoutProfits = companies.filter ({profits}) -> not profits?
    companiesById = {}
    companiesById[company.id] = company for company in companiesWithoutProfits

    getReports (error, reports) ->
      report.company = companiesById[report.id] for report in reports
      reports = reports.filter ({company}) -> company?

      progress = new ProgressBar('Downloading profits for :current/:total companies [:bar] :percent :eta seconds remaining', {
        incomplete: ' '
        width: 20
        total: reports.length
      })

      queue = async.queue (report, callback) ->
        downloadProfits report, (error, profits) ->
          progress.tick(1)

          if profits?
            report.company.profits = profits
            companiesJson = JSON.stringify(companies, null, 2)
            grunt.file.write 'gen/companies.json', companiesJson

          callback(error)

      queue.drain = done
      queue.concurrency = 25
      for report in reports
        queue.push report, (error) ->
          if error?
            console.log()
            done(error)

downloadProfits = (report, callback) ->
  getReportUri report, (error, reportUri) ->
    return callback(error) if error?
    return callback() unless reportUri

    request reportUri, (error, response, body) ->
      return callback(error) if error?

      if response.headers['content-type'] isnt 'application/xml'
        callback(new Error("#{response.headers['content-type']} content type returned for #{report.company.name} (#{report.company.id}): #{reportUri}"))
        return

      document = new DOMParser().parseFromString(body)
      elements = [
        'NetIncomeLoss'
        'NetIncomeLossAvailableToCommonStockholdersBasic'
        'NetIncomeLossAvailableToCommonStockholdersDiluted'
        'IncomeLossFromContinuingOperationsIncludingPortionAttributableToNoncontrollingInterest'
        'ProfitLoss'
        'IncomeLossAttributableToParent'
      ]
      for element in elements
        if profits = profitsForElement(document, element)
          return callback(null, profits)

      callback(new Error("Could not parse profits for #{report.company.name} (#{report.company.id}): #{reportUri}"))

# Attempt to parse the yearly profits from the document using the element name.
profitsForElement = (document, elementName) ->
  nodes = xpath.select("//*[local-name()='#{elementName}']", document)
  profits = null
  for node in nodes when node.prefix is 'us-gaap'
    profit = parseFloat(node.firstChild?.data)
    continue if isNaN(profit)

    if year = dates.yearOfNode(document, node)
      profits ?= {}
      profits[year] ?= profit

  profits

# Find the 10-K report URI for a company
getReportUri = (report, callback) ->
  reportId = path.basename(report.path, path.extname(report.path)).replace(/-/g, '')
  folderUri = "http://www.sec.gov/Archives/edgar/data/#{report.company.id}/#{reportId}"

  request folderUri, (error, response, body='') ->
    return callback(error) if error?

    if match = body.match(new RegExp("\"([^\"]*#{report.company.symbol}-\\d+\\.xml)\"", 'i'))
      callback(null, "#{folderUri}/#{match[1]}")
    else
      callback()

# Get the 10-K report information for all quarters in the last year.
getReports = (callback) ->
  async.map [1, 2, 3, 4], readQuarterIndex, (error, quarters=[]) ->
    callback(error, _.flatten(quarters))

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
