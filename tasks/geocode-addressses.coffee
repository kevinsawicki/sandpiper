ProgressBar = require 'progress'
request     = require 'request'

# Task to geocode all company addresses using the MapQuest API
#
# Requires the MAPQUEST_APP_KEY environment variable be set to the app
# key to use for API requests.
module.exports = (grunt) ->
  grunt.registerTask 'geocode-addresses', 'Geocode addresses for all companies', ->
    unless process.env.MAPQUEST_APP_KEY
      return grunt.warn('Must set MAPQUEST_APP_KEY environment variable.')

    done = @async()

    companies = grunt.file.readJSON('gen/companies.json')
    companiesWithoutLocations = companies.filter ({latitude, longitude}) ->
      not latitude? or not longitude?

    progress = new ProgressBar('Geocoding :total addresses [:bar] :percent :eta seconds remaining', {
      incomplete: ' '
      width: 20
      total: companiesWithoutLocations.length
    })

    offset = 0
    chunkSize = 100
    loadGeocodes = ->
      if offset >= companiesWithoutLocations.length
        grunt.log.ok "Geocoded #{companiesWithoutLocations.length} company addresses"
        done()
        return

      chunk = companiesWithoutLocations.slice(offset, offset + chunkSize)
      geocodeCompanies chunk, (error, locations) ->
        return done(error) if error?

        for {latitude, longitude}, index in locations
          companiesWithoutLocations[offset + index].latitude = latitude
          companiesWithoutLocations[offset + index].longitude = longitude

        companiesJson = JSON.stringify(companies, null, 2)
        grunt.file.write 'gen/companies.json', companiesJson

        offset += chunkSize
        progress.tick(chunkSize)
        setTimeout(loadGeocodes, 100) # Limit to 10 requests per second

    loadGeocodes()

geocodeCompanies = (companies, callback) ->
  apiKey = process.env.MAPQUEST_APP_KEY
  locations = []
  for {address} in companies
    {street1, street2, city, state, zip} = address
    segments = []
    segments.push(street1) if street1
    segments.push(street2) if street2
    segments.push(city) if city
    segments.push(state) if state
    segments.push(zip) if zip
    locations.push(segments.join(', '))

  options =
    url: "http://www.mapquestapi.com/geocoding/v1/batch?key=#{apiKey}"
    json: true
    qs:
      json: JSON.stringify({locations})
      outFormat: 'geojson'

  request options, (error, response, {info, results}) ->
    return callback(error) if error?

    if results.length isnt companies.length
      return callback(new Error(info.messages.join('\n')))

    locations = []
    for result in results
      [location] = result.locations
      {lat, lng} = location.latLng
      locations.push({latitude: lat, longitude: lng})
    callback(null, locations)
