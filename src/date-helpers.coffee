xpath = require 'xpath'

exports.yearOfNode = (node) ->
  exports.getYear(xpath.select('@contextRef', node)[0]?.value)

exports.getYear = (date='') ->
    return -1 unless date

    if match = date.match(/^from_([a-z]+\d{2})_(\d{4})_to_([a-z]+\d{2})_(\d{4})$/i)
      fromDate = Date.parse("#{match[1]} #{match[2]}")
      unless isNaN(fromDate)
        toDate = Date.parse("#{match[3]} #{match[4]}")
        unless isNaN(toDate)
          day = 24 * 60 * 60 * 1000
          days = (toDate - fromDate) / day
          return new Date(toDate).getFullYear() if 360 < days < 370

    if match = date.match(/^from-(\d{4})-(\d{2})-(\d{2})-to-(\d{4})-(\d{2})-(\d{2})(\.\d+)*$/i)
      fromDate = Date.parse("#{match[2]} #{match[3]} #{match[1]}")
      unless isNaN(fromDate)
        toDate = Date.parse("#{match[5]} #{match[6]} #{match[4]}")
        unless isNaN(toDate)
          day = 24 * 60 * 60 * 1000
          days = (toDate - fromDate) / day
          return new Date(toDate).getFullYear() if 360 < days < 370

    if match = date.match(/^Context_FYE_\d{2}-[a-zA-Z]+-(\d{4})$/)
      year = parseInt(match[1])
      return year unless isNaN(year)

    if match = date.match(/^TwelveMonthsEnded_\d{2}[a-zA-Z]+(\d{4})$/)
      year = parseInt(1)
      return year unless isNaN(year)

    if match = date.match(/^d(\d{4})$/i)
      year = parseInt(match[1])
      return year unless isNaN(year)

    if match = date.match(/^d(\d{4})q4(ytd)?$/i)
      year = parseInt(match[1])
      return year unless isNaN(year)

    -1
