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
  
start_time = Time.now
link_amount = Link.all.count  
@cars = @cars = Car.where(:year.gte => 1985).desc(:year)  
puts (Time.now - start_time).round(4)
puts "from #{link_amount}"
@lid = 0
Aap.all.each do |aap|
	@cars.each do |car|
		@lid += 1
		
		next if @lid < link_amount + 1
		
		
		link = Link.new()
		link.part_no = aap.part_no
		link.title = aap.title				#产品名称
		link.url = aap.url 					#地址
		link.product_id = aap.product_id 	#产品网站序列号

		link.year		= car.year					#年份	
		link.maker	= car.maker 				#maker
		link.model	= car.model					#车型
		link.engine	= car.engine				#发动机
		link.vehicle_id	= car.vehicle_id		#汽车编号
		link.vehicle_code	= car.vehicle_code	#汽车代码

		link.status	= 	0					#是否采集 0、1
		#link.result						#采集结果
		link.pipei	=	0					#是否匹配 0、1
		link.lid = @lid
		
	product_id = aap.product_id		
	year = car.year
	maker = car.maker
	model = car.model
	engine = car.engine
	vehicleID = car.vehicle_id
	vehicleCODE = car.vehicle_code	
	
	link.app_url = "http://shop.advanceautoparts.com/webapp/wcs/stores/servlet/AjaxManageMyGarageCmd?storeId=10151&catalogId=10051&langId=-1&vehicleID=#{vehicleID}&vehicleCODE=#{vehicleCODE}&productId=#{product_id}&callingPage=CheckFitModal&saveVehicleFromCheckFit=false&actionCode=addVehicle&vehicleMake=#{maker}&vehicleModel=#{model}&vehicleEngine=#{engine}&vehicleYear=#{year}"
	
		link.save
		if @lid%10000 == 0
			puts @lid/10000
			puts (Time.now - start_time).round(4)
		end
	end
end



