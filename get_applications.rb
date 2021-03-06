#encoding: UTF-8
require 'rubygems'
require 'mongoid'
require 'nokogiri'
require 'open-uri'
require 'pp'



Dir.glob("#{File.dirname(__FILE__)}/app/models/*.rb") do |lib|
  require lib
end

ENV['MONGOID_ENV'] = 'aap'

Mongoid.load!("config/mongoid.yml")
class String
    def br_to_new_line
        self.gsub('<br>', "\n")
    end
    def n_to_nil
        self.gsub('\n', "")
    end	
    def strip_tag
        self.gsub(%r[<[^>]*>], '').gsub(/\t|\n|\r/, ' ')
    end
end #String
class IoFactory
	attr_reader :file
	def self.init file
		@file = file
		if @file.nil?
			puts 'Can Not Init File To Write'
			exit
		end #if
		File.open @file, 'a'
	end     
end #IoFactory
def safe_open(url, retries = 5, sleep_time = 0.42,  headers = {})
    begin  
      html = open(url).read  
		rescue StandardError,Timeout::Error, SystemCallError, Errno::ECONNREFUSED #有些异常不是标准异常  
      puts $!  
      retries -= 1  
      if retries > 0  
        sleep sleep_time and retry  
      else  
				#logger.error($!)
				#错误日志
        #TODO Logging..  
      end  
    end
  end
def create_file_to_write
	file_path = File.join('.', "application-#{Time.now.to_formatted_s(:number) }.txt")
	@file_to_write = IoFactory.init(file_path)
end #create_file_to_write

create_file_to_write
@total_open = 0
@first_time = Time.now.to_formatted_s(:number)
@products = Aap.where(:product_id => "-49957355") #"-49987467") #(:applications.ne => nil)#.limit(1)

@cars = Car.where(:year.gte => 1985, :year.lte => 2012).desc(:year)

@products.each_with_index do |p, i|
	p.status = 2
	p.save
	puts product_id = p.product_id
	
	@cars.each_with_index do |car, j|
		#next if j < 5339
		year = car.year
		maker = car.maker
		model = car.model
		engine = car.engine
		vehicleID = car.vehicle_id
		vehicleCODE = car.vehicle_code
		url = "http://shop.advanceautoparts.com/webapp/wcs/stores/servlet/AjaxManageMyGarageCmd?storeId=10151&catalogId=10051&langId=-1&vehicleID=#{vehicleID}&vehicleCODE=#{vehicleCODE}&productId=#{product_id}&callingPage=CheckFitModal&saveVehicleFromCheckFit=false&actionCode=addVehicle&vehicleMake=#{maker}&vehicleModel=#{model}&vehicleEngine=#{engine}&vehicleYear=#{year}"
		url = URI.parse(URI.encode(url))
		html_stream = safe_open(url , retries = 3, sleep_time = 0.42, headers = {})
			@total_open += 1
		#puts html_stream
		json_post = JSON.parse(html_stream)
		vehicle = json_post["descriptions"]
if vehicle.nil?
	puts "#{year}=#{i}=#{j}=null"  
	next
else
	@file_to_write.puts "#{i}=#{j}\t#{vehicleID}\t#{vehicleCODE}\t#{product_id}\t#{p.part_no}\t#{maker}\t#{model}\t#{engine}\t#{year}"
	param = Application.new() #find_or_create_by(:vehicle_id => car.vehicle_id)
	param.year = car.year
	param.maker = car.maker
	param.model = car.model
	param.engine = car.engine
	param.vehicle_id = car.vehicle_id
	param.vehicle_code = car.vehicle_code
	

	p.applications.push(param)
	puts "#{i}=#{j}\t#{vehicleID}\t#{vehicleCODE}\t#{product_id}\t#{p.part_no}\t#{maker}\t#{model}\t#{engine}\t#{year}"
	
end
		
	end
	
	p.status = 1
	p.save
end


@last_time = Time.now.to_formatted_s(:number)
puts "open: #{@total_open} "
puts "from: #{@first_time} - to: #{@last_time}"
