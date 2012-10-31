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
	file_path = File.join('.', "application-#{Time.now.to_formatted_s(:number) }.txt")
	@file_to_write = IoFactory.init(file_path)
end #create_file_to_write

create_file_to_write
first_time = Time.now

links = Link.where( :status => 0, :lid.lte => 1000)
links.each do |link|
	url = link.app_url
	url = URI.parse(URI.encode(url))
	html_stream = safe_open(url , retries = 3, sleep_time = 0.42, headers = {})

	json_post = JSON.parse(html_stream)
	vehicle = json_post["descriptions"]	
			link.status = 1
			link.result = html_stream
			if vehicle.nil?
				link.pipei = 0
			elsif
				link.pipei = 1
			end
			link.save
			puts "link_id : #{link.lid}"
			
	@file_to_write.puts "#{link.lid}\t#{link.vehicle_id}\t#{link.product_id}\t#{link.part_no}\t#{link.maker}\t#{link.model}\t#{link.engine}\t#{link.year}"

	
end


puts Time.now - first_time.round(4)
