#!../script/runner

if ARGV.size != 1
  puts "gimme a *.dgl filename"
  exit
end

STDOUT.sync = true

require 'double_gis'

puts "[.] houses in db BEFORE import: #{House.count}"

houses = DoubleGis.parse_dgl(ARGV.first)

puts "[.] loaded #{houses.size} houses from dgl"

houses.each do |gh|
  h = House.find_or_initialize_by_street_and_number(
    gh.street,
    gh.number
  )
#  if h.new_record?
#    require 'pp'
#    pp h
#    pp gh
#  end
  h.inet_status = House::ST_MINOR_PROBLEMS
  h.comment = 'Требуется согласование с председателем'
  h.save!
  putc '.'
end
puts

puts "[.] houses in db AFTER  import: #{House.count}"
