#!/usr/bin/env ruby
#encoding: UTF-8

require 'rubygems'
require 'mongoid'
require 'pp'				
require 'json'
require 'open-uri'
require 'nokogiri'			# gem install nokogiri
require 'forkmanager'		# gem install parallel-forkmanager


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

class MultipleCrawler
	
	def initialize(links, mylids, retries = 3, pm_max=1, sleep_time = 0.42, user_agent='', redirect_limit=1)
		@links = links  				# 网址数组 
		@mylids = mylids				# lids数组
		@pm_max = pm_max 				# 最大并行运行进程数
		@retries = retries 
		@sleep_time = sleep_time
	end
	
	def process_jobs # 处理任务
		puts	start_time = Time.now
		@success_time = 0
		pm = Parallel::ForkManager.new(@pm_max)
		
		@links.each_with_index do |my_url, i| 
			pm.start(my_url) and next # 启动后，立刻 next 不会等待进程执行完，这样才可以并行运算
			#doing stuff here with my_url will be in a child
			url = URI.parse(my_url)
			begin
			  html = open(url).read  
			  @success_time += 1
			  pm.finish(0)
			rescue StandardError,Timeout::Error, SystemCallError, Errno::ECONNREFUSED #有些异常不是标准异常  
			  puts $!  
			  @retries -= 1  
			  if @retries > 0  
				sleep @sleep_time and retry  
			  else  
				pm.finish(255)
				#logger.error($!)
				#错误日志
				#TODO Logging..  
			  end  
			end
			#save the html result
			json_post = JSON.parse(html)
			vehicle = json_post["descriptions"]
			puts " get json data from PID:#$$"

			if !vehicle.nil?
				Pipei.create(:lid => @mylids[i], :result => html, :app_url => url, :pipei => 1)
			end
			
			puts "slid:#{@mylids[i]} has scanned!"
			# end stuff in the child process
		end	

		begin 
			print "wait for all children!\n"
			pm.wait_all_children		# 等待所有子进程处理完毕 
		rescue SystemExit, Interrupt	# 遇到中断，打印消息
			print "!!!!Interrupt wait all children!!!!\n"
		ensure
			print "Process end, total: #{@links.size}, crawled: #{@success_time}, time: #{'%.4f' % (Time.now - start_time)}s.\n"
		end
	end
	
	
	def run # 运行入口
		process_jobs
	end
end
#links = Link.where( :status => 0, :lid.lte => 100)
links = Link.where( :product_id => '-49957383', :year.gte => 1985)
#links = Link.limit(100).where(:status => 0)
puts "get limit #{links.count} items."

mylinks = links.map {|link| link.app_url}
mylids = links.map {|link| link.lid}

break


user_agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:13.0) Gecko/20100101 Firefox/13.0'
pm_max = 10

MultipleCrawler.new(mylinks, mylids, retries = 3,pm_max, sleep_time = 0.2, user_agent).run
