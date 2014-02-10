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
        if error?
          callback(error)
        else
          # Sanitize street2 values
          delete address.street2 unless address.street2
          delete address.street2 if address.street1 is address.street2

          company.address = address
          companiesJson = JSON.stringify(companies, null, 2)
          grunt.file.write 'gen/companies.json', companiesJson

          callback()

    async.each(companiesWithoutAddresses, loadAddress, done)

# Get the corporate address for the given company
getAddress = ({id}, callback) ->
  url = "http://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&output=atom&start=0&count=1&CIK=#{id}"
  request url, (error, response, body='') ->
    return callback(error) if error?

    if response.headers['content-type'] is 'application/atom+xml'
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
    else
      callback(new Error("No address for #{id}: #{url}\n#{body}"))
