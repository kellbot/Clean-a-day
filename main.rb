require './calendar.rb'
require 'date'

twentytwelve = Calendar.new((Date.today + 1), (Date.today+21))
twentytwelve.days.each do |day|
  day.prepare
  day.draw
end
twentytwelve.make_printable


