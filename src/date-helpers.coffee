xpath = require 'xpath'

yearFromRange = (fromDate, toDate) ->
  return null if isNaN(fromDate)
  return null if isNaN(toDate)

  day = 24 * 60 * 60 * 1000
  days = (toDate - fromDate) / day
  return new Date(toDate).getFullYear() if 360 < days < 370

exports.yearOfNode = (node) ->
  exports.getYear(xpath.select('@contextRef', node)[0]?.value)

exports.getYear = (date='') ->
    return -1 unless date

    if match = date.match(/^from_([a-z]+\d{2})_(\d{4})_to_([a-z]+\d{2})_(\d{4})$/i)
      fromDate = Date.parse("#{match[1]} #{match[2]}")
      toDate   = Date.parse("#{match[3]} #{match[4]}")
      return year if year = yearFromRange(fromDate, toDate)

    if match = date.match(/^from-(\d{4})-(\d{2})-(\d{2})-to-(\d{4})-(\d{2})-(\d{2})(\.\d+)*$/i)
      fromDate = Date.parse("#{match[2]} #{match[3]} #{match[1]}")
      toDate   = Date.parse("#{match[5]} #{match[6]} #{match[4]}")
      return year if year = yearFromRange(fromDate, toDate)

    if match = date.match(/from(\d{4})-(\d{1,2})-(\d{1,2})to(\d{4})-(\d{1,2})-(\d{1,2})/i)
      fromDate = Date.parse("#{match[2]} #{match[3]} #{match[1]}")
      toDate   = Date.parse("#{match[5]} #{match[6]} #{match[4]}")
      return year if year = yearFromRange(fromDate, toDate)

    if match = date.match(/from(\d+)([a-z]+)(\d{4})to(\d+)([a-z]+)(\d+)/i)
      fromDate = Date.parse("#{match[2]} #{match[1]} #{match[3]}")
      toDate   = Date.parse("#{match[5]} #{match[4]} #{match[6]}")
      return year if year = yearFromRange(fromDate, toDate)

    if match = date.match(/^c(\d{4})(\d{2})(\d{2})to(\d{4})(\d{2})(\d{2})$/)
      fromDate = Date.parse("#{match[2]} #{match[3]} #{match[1]}")
      toDate   = Date.parse("#{match[5]} #{match[6]} #{match[4]}")
      return year if year = yearFromRange(fromDate, toDate)

    if match = date.match(/^Duration_(\d{1,2})_(\d{1,2})_(\d{4})_To_(\d{1,2})_(\d{1,2})_(\d{4})$/)
      fromDate = Date.parse("#{match[1]} #{match[2]} #{match[3]}")
      toDate   = Date.parse("#{match[4]} #{match[5]} #{match[6]}")
      return year if year = yearFromRange(fromDate, toDate)

    if match = date.match(/^([a-z]+)_(\d{1,2})_(\d{4})_([a-z]+)_(\d{1,2})_(\d{4})$/i)
      fromDate = Date.parse("#{match[1]} #{match[2]} #{match[3]}")
      toDate   = Date.parse("#{match[4]} #{match[5]} #{match[6]}")
      return year if year = yearFromRange(fromDate, toDate)

    if match = date.match(/(\d{1,2})_([a-z]+)_(\d{4})_to_(\d{1,2})_([a-z]+)_(\d{4})/i)
      fromDate = Date.parse("#{match[2]} #{match[1]} #{match[3]}")
      toDate   = Date.parse("#{match[3]} #{match[4]} #{match[6]}")
      return year if year = yearFromRange(fromDate, toDate)

    if match = date.match(/d_12m_(\d{4})_\d{1,2}_\d{1,2}/i)
      year = parseInt(match[1])
      return year unless isNaN(year)

    if match = date.match(/d_ye_(\d{4})_12_31/i)
      year = parseInt(match[1])
      return year unless isNaN(year)

    if match = date.match(/^Context_FYE_\d{2}-[a-zA-Z]+-(\d{4})$/)
      year = parseInt(match[1])
      return year unless isNaN(year)

    if match = date.match(/^TwelveMonthsEnded_\d{2}[a-zA-Z]+(\d{4})$/)
      year = parseInt(match[1])
      return year unless isNaN(year)

    if match = date.match(/^TwelveMonthEnded_\d{2}[a-zA-Z]+(\d{4})$/)
      year = parseInt(match[1])
      return year unless isNaN(year)

    if match = date.match(/^d(\d{4})$/i)
      year = parseInt(match[1])
      return year unless isNaN(year)

    if match = date.match(/^d(\d{4})q4(ytd)?$/i)
      year = parseInt(match[1])
      return year unless isNaN(year)

    if match = date.match(/STD_3\d\d_(\d{4})\d{4}/)
      year = parseInt(match[1])
      return year unless isNaN(year)

    if match = date.match(/D12ME(\d{4})/)
      year = parseInt(match[1])
      return year unless isNaN(year)

    -1
