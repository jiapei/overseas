#!/usr/bin/env ruby
#encoding: UTF-8

# 抓取每一个站点的首页链接数量
# require 'rubygems'			# 1.8.7
require 'rubygems'
require 'mongoid'
require 'pp'				
require 'json'
require 'open-uri'
require 'nokogiri'			# gem install nokogiri
require 'forkmanager'		# gem install parallel-forkmanager
require 'ap'
require 'beanstalk-client'	# gem install beanstalk-client

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

class MultipleCrawler

	class Crawler
		def initialize(user_agent, redirect_limit=1)
			@user_agent = user_agent
			@redirect_limit = redirect_limit
			@timeout = 20 
		end
		attr_accessor :user_agent, :redirect_limit, :timeout
		
		def fetch(website)
			print "Pid:#{Process.pid}, fetch: #{website}\n"
			url = website
			url = URI.parse(URI.encode(url))
			html_stream = safe_open(url , retries = 3, sleep_time = 0.2, headers = {})
		end
	end
	
	def initialize(links, beanstalk_jobs, pm_max=1, user_agent='', redirect_limit=1)
		@links = links  				# 网址数组 
		@beanstalk_jobs = beanstalk_jobs	# beanstalk服务器地址和管道参数
		@pm_max = pm_max 					# 最大并行运行进程数
		@user_agent = user_agent 			# user_agent 伪装成浏览器访问
		@redirect_limit = redirect_limit  	# 允许最大重定向次数
		
		@ipc_reader, @ipc_writer = IO.pipe # 缓存结果的 ipc 管道
	end
	
	attr_accessor :user_agent, :redirect_limit
	
	def init_beanstalk_jobs # 准备beanstalk任务
		beanstalk = Beanstalk::Pool.new(*@beanstalk_jobs)
		#清空beanstalk的残留消息队列
		begin
			while job = beanstalk.reserve(0.1) 
				job.delete
			end
		rescue Beanstalk::TimedOut
			print "Beanstalk queues cleared!\n"
		end
		puts "begin in beanstalk's jobs"
		@links.size.times{|i| beanstalk.put(i)} # 将所有的任务压栈
		puts "end all in beanstalk's jobs"
		puts "links.size: #{@links.size}"
	
		beanstalk.close
		rescue => e 
		puts e 
		exit
	end
	
	def process_jobs # 处理任务
		puts	start_time = Time.now
			beanstalk = Beanstalk::Pool.new(*@beanstalk_jobs)
			@ipc_reader.close
loop{
				begin
					job = beanstalk.reserve(0.1) # 检测超时为0.1秒，因为任务以前提前压栈
					index = job.body
					job.delete
					website = @links[index.to_i].app_url
					result = Crawler.new(@user_agent).fetch(website)

					json_post = JSON.parse(result)
					vehicle = json_post["descriptions"]

					@my_link = @links[index.to_i] #Link.where(:lid => 1 ).first
					@my_link.status = 1
					@my_link.result = result

					if vehicle.nil?
						@my_link.pipei = 0
					elsif
						@my_link.pipei = 1
					end
					@my_link.save
#					@ipc_writer.
puts "#{@my_link.lid}\t#{@my_link.vehicle_id}\t#{@my_link.product_id}\t#{@my_link.part_no}\t#{@my_link.maker}\t#{@my_link.model}\t#{@my_link.engine}\t#{@my_link.year}"

				rescue Beanstalk::DeadlineSoonError, Beanstalk::TimedOut, SystemExit, Interrupt
					puts "error"
					break
				end
}
			@ipc_writer.close
			results = read_results
			ap results, :indent => -4 , :index => false
			print "Process end, total: #{@links.size}, crawled: #{results.size}, time: #{'%.4f' % (Time.now - start_time)}s.\n"
	end
	
	def read_results # 通过管道读取子进程抓取返回的数据
		results = {}
		while result = @ipc_reader.gets
			results.merge! JSON.parse(result)
		end
		@ipc_reader.close
		results
	end
	
	def run # 运行入口
		init_beanstalk_jobs
			
		process_jobs
	end
end
#links = Link.where( :status => 0, :lid.lte => 100)
links = Link.where( :product_id => '-49957383', :year => 2013, :status => 0)

#links = Link.limit(100).where(:status => 0)
puts "get limit #{links.count} items."


beanstalk_jobs = [['192.168.2.14:11300'],'crawler-jobs']
user_agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:13.0) Gecko/20100101 Firefox/13.0'
pm_max = 10

MultipleCrawler.new(links, beanstalk_jobs, pm_max, user_agent).run

