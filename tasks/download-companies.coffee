_           = require 'underscore'
async       = require 'async'
{DOMParser} = require 'xmldom'
ProgressBar = require 'progress'
request     = require 'request'
xpath       = require 'xpath'

# Task to download company information from different stock exchanges.
#
# Only companies that have a Central Index Key (CIK) will written out.
#
# Currently the NASDAQ, NYSE, and AMEX exchanges are used.
module.exports = (grunt) ->
  grunt.registerTask 'download-companies', 'Download all companies on a major stock exchange', ->
    done = @async()

    downloadCompanies (error, companies) ->
      return done(error) if error?

      if grunt.file.isFile('gen/companies.json')
        existingCompanies = grunt.file.readJSON('gen/companies.json')
      existingCompanies ?= []

      companies = companies.filter ({symbol}) ->
        for existing in existingCompanies when existing.symbol is symbol
          return false
        true

      existingCompanies = existingCompanies.filter ({id}) -> id

      progress = new ProgressBar('Mapping symbols to ids for :current/:total companies [:bar] :percent :eta seconds remaining', {
        incomplete: ' '
        width: 20
        total: companies.length
      })

      queue = async.queue (company, callback) ->
        idForSymbol company.symbol, (error, id) ->
          progress.tick(1)
          return callback(error) if error?

          if id
            company.id = id
            delete company.ipoYear unless company.ipoYear
            existingCompanies.push(company)
            companiesJson = JSON.stringify(existingCompanies, null, 2)
            grunt.file.write('gen/companies.json', companiesJson)

          callback()

      queue.push(company) for company in companies
      queue.concurrency = 25
      queue.drain = done

# Download a master company list from all exchanges
downloadCompanies = (callback) ->
  exchangeNames = ['nasdaq', 'amex', 'nyse']
  progress = new ProgressBar('Downloading :total exchanges [:bar] :percent :eta seconds remaining', {
    incomplete: ' '
    width: 20
    total: exchangeNames.length
  })

  async.map exchangeNames, downloadExchange, (error, exchanges) ->
    progress.tick(1)
    if error?
      callback(error)
    else
      callback(null, _.flatten(exchanges))

# Download all symbols on the given exchange
downloadExchange = (exchange, callback) ->
  uri = "http://www.nasdaq.com/screening/companies-by-name.aspx?letter=0&exchange=#{exchange}&render=download"
  request uri, (error, response, body) ->
    return callback(error) if error?

    lines =  body.split('\n')
    lines.shift() # First line has column names
    symbols = []
    for line in lines
      segments = line.split('","')
      symbol   = segments[0].substring(1) # Remove leading "
      name     = segments[1]
      ipoYear  = parseInt(segments[5])
      sector   = segments[6]
      industry = segments[7]
      symbols.push({symbol, name, ipoYear, sector, industry, exchange})

    callback(null, symbols)

# Get the company id for a ticker symbol
idForSymbol = (symbol, callback) ->
  url = "http://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&output=atom&start=0&count=1&CIK=#{symbol}"
  request url, (error, response, body) ->
    return callback(error) if error?

    if response.headers['content-type'] is 'application/atom+xml'
      dom = new DOMParser().parseFromString(body)
      id = parseInt(xpath.select('/feed/company-info/cik/text()', dom).toString())
      callback(null, id)
    else
      callback()
