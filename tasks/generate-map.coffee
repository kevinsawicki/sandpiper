
# Generate a map of all the companies
module.exports = (grunt) ->
  grunt.registerTask 'generate-map', 'Generate a map of all the companies', ->
    done = @async()

    companies = grunt.file.readJSON('gen/companies.json')
    features = []
    for company in companies
      geometry =
        type: 'Point'
        coordinates: [company.longitude, company.latitude]

      properties =
        Name: company.name
        Symbol: company.symbol
        Exchange: company.exchange
        Sector: company.sector
        Industry: company.industry
        IpoYear: company.ipoYear

      features.push({geometry, properties, type: 'Feature'})

    map = {features, type: 'FeatureCollection'}
    grunt.file.write('gen/map.geojson', JSON.stringify(map))
