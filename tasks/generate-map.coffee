
# Generate a map of all the companies
module.exports = (grunt) ->
  grunt.registerTask 'generate-map', 'Generate a map of all the companies', ->
    done = @async()

    companies = grunt.file.readJSON('gen/companies.json')
    features = []
    for company in companies
      continue unless company.address
      continue unless company.latitude? and company.longitude?
      continue unless /^[A-Z]{2}$/.test(company.address.state)

      geometry =
        type: 'Point'
        coordinates: [company.longitude, company.latitude]

      properties =
        Name: company.name
        Symbol: company.symbol
        Exchange: company.exchange

      properties.Sector = company.sector if company.sector
      properties.Industry = company.industry if company.industry
      properties['IPO Year'] = company.ipoYear if company.ipoYear

      switch company.sector
        when 'Capital Goods'         then properties['marker-symbol'] = 'car'
        when 'Consumer Non-Durables' then properties['marker-symbol'] = 'fast-food'
        when 'Consumer Services'     then properties['marker-symbol'] = 'shop'
        when 'Enery'                 then properties['marker-symbol'] = 'fuel'
        when 'Finance'               then properties['marker-symbol'] = 'bank'
        when 'Health Care'           then properties['marker-symbol'] = 'hospital'
        when 'Public Utilities'      then properties['marker-symbol'] = 'mobilephone'
        when 'Technology'            then properties['marker-symbol'] = 'chemist'
        when 'Transportation'        then properties['marker-symbol'] = 'rail'

      if company.profits?[2012] > 0
        properties['marker-color'] = "#01796F"
        properties["2012 Profit"] = getProfitLabel(company.profits[2012])
      else if company.profits?[2012] < 0
        properties['marker-color'] = "#A45A52"
        properties["2012 Profit"] = "-#{getProfitLabel(company.profits[2012])}"
      else
        properties['marker-color'] = "#536895"

      features.push({geometry, properties, type: 'Feature'})

    map = {features, type: 'FeatureCollection'}
    grunt.file.write('gen/map.geojson', JSON.stringify(map))

getProfitLabel = (profit) ->
  if profit > 1000000000
    billions = Math.round(profit / 1000000000)
    "#{billions}B"
  else if profit > 1000000
    millions = Math.round(profit / 1000000)
    "#{millions}M"
  else
    thousands = Math.round(profit / 1000)
    " #{thousands}K"
