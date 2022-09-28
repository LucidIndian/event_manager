require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def clean_phone(raw_phone)
  phone_array = raw_phone.split("")
  # removing chars that are not a digit 0-9 so I can measure only the digits
  phone_num_only = phone_array.delete_if {|char| !/\d/.match(char)} 
  phone_numbers = phone_num_only
  # If the phone  is less than 10 or greater than 11 digits, assume it's bad 
  if phone_numbers.length < 10 || phone_numbers.length > 11
    phone_numbers = Array.new(10, "0") # Zeros = Bad number
  # If the phone number is 11 digits and the first number IS 1, 
    #trim the 1 and use the remaining 10 digits
  elsif phone_numbers.length == 11 && phone_numbers[0] == "1" 
    # trim 1, use the remaining 10 digits
    phone_numbers.delete_at(0)
  # If the phone is 11 digits and the 1st num is NOT 1, assume it's bad 
  elsif phone_numbers.length == 11 && phone_numbers[0] != "1" 
    phone_numbers = Array.new(10, "0") # Zeros = Bad number
  else  # If the phone number is 10 digits, assume that it's good
    phone_numbers
  end
  # Re-add dashes ###-###-#### and convert to string so it displays better
  phone_numbers.insert(3, "-")
  phone_numbers.insert(7, "-")
  phone_nums_string = phone_numbers.join("")
  phone_nums_string.to_s
end 

def clean_reg_date(raw_date, hours_hash, dow_hash)
  formatted_time = Time.strptime(raw_date, "%m/%d/%y %R")
  # Tally the hour of the formatted_time
  hour = formatted_time.hour
  puts "formatted_time hour is #{hour}"
  hour_symbol = ":" + hour.to_s
  hours_hash[hour_symbol] += 1 # talley for hours count
  # Tally the DOW of the formatted_time
  dow = formatted_time.wday
  puts "DOW is #{dow}"
  dow_symbol = ":" + dow.to_s
  dow_hash[dow_symbol] += 1 # talley for dow count
  formatted_time
end 

hours_hash = Hash.new
for i in 0..23 do
  # h[:bat] = 3 # => 3
  symbol = ":" + i.to_s
  hours_hash[symbol] = 0
end

dow_hash = Hash.new
for i in 0..6 do
  symbol = ":" + i.to_s
  dow_hash[symbol] = 0
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  filename = "output/thanks_#{id}.html"
  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def save_time_targeting(time_target_report)
  Dir.mkdir('time_target_report') unless Dir.exist?('time_target_report')
  filename = "time_target_report/time_target_report.html"
  File.open(filename, 'w') do |file|
    file.puts time_target_report
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter_a = File.read('form_letter.erb')
erb_template_a = ERB.new template_letter_a
template_letter_b = File.read('time_target_report.erb')
erb_template_b = ERB.new template_letter_b

contents.each do |row|
  id = row[0]
  fname = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone = clean_phone(row[:homephone]) # added by Tygh
  reg_date = clean_reg_date(row[:regdate], hours_hash, dow_hash) # added by Tygh
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template_a.result(binding)
  save_thank_you_letter(id,form_letter)
end

# Assignment: Time Targeting
sorted_hours = hours_hash.sort_by{|k,v| v}.reverse
bossname = "Brittany"
# Assignment: DOW
sorted_days = dow_hash.sort_by{|k,v| v}.reverse
time_target_report = erb_template_b.result(binding)
save_time_targeting(time_target_report)