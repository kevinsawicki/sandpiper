# Remove imperfections from the generated data.
module.exports = (grunt) ->
  grunt.registerTask 'normalize-companies', 'Normalize company information', ->
    companies = grunt.file.readJSON('gen/companies.json')

    # Sort companies by name
    companies.sort (company1, company2) ->
      company1.name.localeCompare(company2.name)

    # Remove null ipoYear values
    for company in companies when not company.ipoYear?
      delete company.ipoYear

    # Remove empty zip codes from addresses
    for {address} in companies when address? and not address.zip
      delete address.zip

    # Remove escaped apostrophes from names
    for company in companies
      company.name = company.name.replace('&#39;', '\'')

    # Remove trailing (The) from names
    for company in companies
      company.name = company.name.replace(/\s+\(The\)$/, '')

    for company in companies
      company.name = company.name.replace(/\s*,?\s*Inc\.?$/, '')

    companiesJson = JSON.stringify(companies, null, 2)
    grunt.file.write 'gen/companies.json', "#{companiesJson}\n"
