async       = require 'async'
{DOMParser} = require 'xmldom'
ProgressBar = require 'progress'
request     = require 'request'
xpath       = require 'xpath'

# Task to download all company ticker information from different exchanges
#
# Currently the nasdaq, nyse, and amex exchanges are used.
module.exports = (grunt) ->
  grunt.registerTask 'download-exchange-symbols', 'Download all company symbols and exchange names', ->
    done = @async()

    companies = grunt.file.readJSON('gen/companies.json')
    companiesWithoutSymbols = companies.filter ({symbol}) -> not symbol?
    companiesById = {}
    companiesById[company.id] = company for company in companiesWithoutSymbols

    progress = new ProgressBar('Resolving symbols for :total companies [:bar] :percent :eta seconds remaining', {
      incomplete: ' '
      width: 20
      total: companiesWithoutSymbols.length
    })
    companiesUpdated = 0
    loadSymbol = ({symbol, exchange, ipoYear, sector, industry}, callback) ->
      getId symbol, (error, id) ->
        progress.tick(1)
        if company = companiesById[id]
          company.symbol   = symbol
          company.exchange = exchange
          company.ipoYear  = ipoYear if ipoYear
          company.sector   = sector
          company.industry = industry
          companiesUpdated++
        callback(error)

    async.map ['nasdaq', 'amex', 'nyse'], downloadExchange, (error, exchanges) ->
      return done(error) if error?

      symbols = []
      symbols = symbols.concat(exchange) for exchange in exchanges
      async.map symbols, loadSymbol, (error) ->
        return done(error) if error?

        companiesJson = JSON.stringify(companies, null, 2)
        grunt.file.write 'gen/companies.json', companiesJson
        grunt.log.ok "Downloaded #{companiesUpdated} symbols"
        done()

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
      ipoYear  = parseInt(segments[5])
      sector   = segments[6]
      industry = segments[7]
      symbols.push({symbol, ipoYear, sector, industry, exchange})

    callback(null, symbols)

# Get the company id for a ticker symbol
getId = (symbol, callback) ->
  url = "http://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&output=atom&start=0&count=1&CIK=#{symbol}"
  request url, (error, response, body) ->
    return callback(error) if error?

    if response.headers['content-type'] is 'application/atom+xml'
      dom = new DOMParser().parseFromString(body)
      id = parseInt(xpath.select('/feed/company-info/cik/text()', dom).toString())
      callback(null, id)
    else
      callback()
