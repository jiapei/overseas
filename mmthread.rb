#encoding: UTF-8
require 'rubygems'
require 'mongoid'
require 'nokogiri'
require 'open-uri'
require 'pp'



Dir.glob("#{File.dirname(__FILE__)}/app/models/*.rb") do |lib|
  require lib
end

ENV['MONGOID_ENV'] = 'aap-data'

Mongoid.load!("config/mongoid.yml")

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
	file_path = File.join('.', "production-#{Time.now.to_formatted_s(:number) }.txt")
	@file_to_write = IoFactory.init(file_path)
end #create_file_to_write

create_file_to_write
first_time = Time.now


if $*[0]==nil
	abort "用法示例：ruby #$0 开始数　结束数　存放的目录 EX:如ruby #$0 20000  " 
end

max_num = $*[0].to_i
first_time = Time.now

links = Link.where( :status => 0, :lid.lte => max_num)

threads = []
links.each do |link|
	begin
		threads << Thread.new(link) do |thei|
		
			#puts thei.app_url
			url = URI.parse(URI.encode(thei.app_url))		
			html_stream = safe_open(url , retries = 3, sleep_time = 0.1, headers = {})
			next if html_stream.nil?

			json_post = JSON.parse(html_stream)
			vehicle = json_post["descriptions"]	
			vehicleID = json_post["vehicleID"]
			
			if vehicleID.nil?
				puts "太快了"
			else
				puts vehicleID
				
				thei.status = 1
				thei.result = html_stream
				if vehicle.nil?
					thei.pipei = 0
				else
					thei.pipei = 1
					@file_to_write.puts "#{thei.lid}\t#{thei.vehicle_id}\t#{thei.product_id}\t#{thei.part_no}\t#{thei.maker}\t#{thei.model}\t#{thei.engine}\t#{thei.year}"
				end
				thei.save
				puts "link_id : #{thei.lid}"
				
				
			end
		
		end
	
	rescue
	  p $!  # => "unhandled exception"
	end
end

threads.each {|thr| thr.join}
puts " 下载完成，共耗时：#{Time.now - first_time}秒"

