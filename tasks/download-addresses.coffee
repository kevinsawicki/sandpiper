async       = require 'async'
{DOMParser} = require 'xmldom'
ProgressBar = require 'progress'
request     = require 'request'
xpath       = require 'xpath'

# Task to download the addresses of all companies
module.exports = (grunt) ->
  grunt.registerTask 'download-addresses', 'Download addresses for all companies', ->
    done = @async()

    companies = grunt.file.readJSON('gen/companies.json')
    companiesWithoutAddresses = companies.filter ({address}) -> not address?

    progress = new ProgressBar('Downloading :total addresses [:bar] :percent :eta seconds remaining', {
      incomplete: ' '
      width: 20
      total: companiesWithoutAddresses.length
    })
    loadAddress = (company, callback) ->
      getAddress company, (error, address) ->
        progress.tick(1)
        callback(error, address)

    async.map companiesWithoutAddresses, loadAddress, (error, addresses) ->
      return done(error) if error?

      for company, index in companiesWithoutAddresses
        company.address = addresses[index]

      # Sanitize street2 values
      for {address} in companies
        delete address.street2 unless address.street2
        delete address.street2 if address.street1 is address.street2

      companiesJson = JSON.stringify(companies, null, 2)
      grunt.file.write 'gen/companies.json', companiesJson
      grunt.log.ok "Downloaded #{addresses.length} company addresses"
      done()

# Get the corporate address for the given company
getAddress = ({id}, callback) ->
  url = "http://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&output=atom&start=0&count=1&CIK=#{id}"
  request url, (error, response, body) ->
    return callback(error) if error?

    dom = new DOMParser().parseFromString(body)
    [address] = xpath.select('/feed/company-info/addresses/address[@type=\'business\']', dom)
    if not address? or xpath.select('count(/)', address) is 1
      [address] = xpath.select('/feed/company-info/addresses/address[@type=\'mailing\']', dom)
    street1 = xpath.select('street1/text()', address).toString()
    street2 = xpath.select('street2/text()', address).toString()
    city = xpath.select('city/text()', address).toString()
    state = xpath.select('state/text()', address).toString()
    zip = xpath.select('zip/text()', address).toString()
    callback(null, {street1, street2, city, state, zip})
