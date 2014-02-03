async   = require 'async'
request = require 'request'


# Task to download all company ticker information from different exchanges
module.exports = (grunt) ->
  grunt.registerTask 'download-exchange-symbols', 'Download all company symbols and exchange names', ->
    done = @async()

    async.map ['nasdaq', 'amex', 'nyse'], downloadExchange, (error, exchanges) ->
      return done(error) if error?

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
      ipoYear  = segments[5]
      sector   = segments[6]
      industry = segments[7]
      symbols.push({symbol, ipoYear, sector, industry})

    callback(null, symbols)
