# Remove imperfections from the generated data.
module.exports = (grunt) ->
  grunt.registerTask 'normalize-companies', 'Normalize company information', ->
    companies = grunt.file.readJSON('gen/companies.json')

    # Sort companies by name
    companies.sort (company1, company2) ->
      company1.name.localeCompare(company2.name)

    # Remove escaped apostrophes from names
    for company in companies
      company.name = company.name.replace('&#39;', '\'')

    # Remove trailing (The) from names
    for company in companies
      company.name = company.name.replace(/\s+\(The\)$/, '')

    # Remove trailing Inc. from names
    for company in companies
      company.name = company.name.replace(/\s*,?\s+Inc\.?$/, '')

    # Remove trailing Corporation from names
    for company in companies
      company.name = company.name.replace(/\s+Corporation$/, '')

    # Remove trailing Incorporated from names
    for company in companies
      company.name = company.name.replace(/\s+Incorporated$/, '')

    # Remove trailing Corp. from names
    for company in companies
      company.name = company.name.replace(/\s+Corp\.$/, '')

    # Remove trailing L.P. from names
    for company in companies
      company.name = company.name.replace(/\s*,?\s+L\.P\.$/, '')

    # Remove trailing Co. from names
    for company in companies
      company.name = company.name.replace(/\s*,?\s+Co\.$/, '')

    # Remove n/a as sector
    for company in companies when company.sector is 'n/a'
      delete company.sector

    # Remove n/a as industry
    for company in companies when company.industry is 'n/a'
      delete company.industry

    companiesJson = JSON.stringify(companies, null, 2)
    grunt.file.write 'gen/companies.json', "#{companiesJson}\n"
