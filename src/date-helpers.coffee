xpath = require 'xpath'

currentYear = new Date().getFullYear()

isInLastFiveYears = (year) ->
  currentYear - 5 <= year <= currentYear

parseYear = (year) ->
  year = parseInt(year)
  return year if isInLastFiveYears(year)

yearFromRange = (fromDate, toDate) ->
  return if isNaN(fromDate)
  return if isNaN(toDate)

  day = 24 * 60 * 60 * 1000
  days = (toDate - fromDate) / day
  return unless 360 < days < 370

  year = new Date(toDate).getFullYear()
  return year if isInLastFiveYears(year)

exports.yearOfNode = (document, node) ->
  contextRef = xpath.select('string(@contextRef)', node).toString()
  return unless contextRef

  [context] = xpath.select("//*[local-name()='context' and @id='#{contextRef}']", document)
  if context
    startDate = Date.parse(xpath.select("*[local-name()='period']/*[local-name()='startDate']/text()", context).toString())
    endDate = Date.parse(xpath.select("*[local-name()='period']/*[local-name()='endDate']/text()", context).toString())
    yearFromRange(startDate, endDate)
