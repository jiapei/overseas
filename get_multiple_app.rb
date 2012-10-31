#!/usr/bin/env ruby
#encoding: UTF-8

# 抓取每一个站点的首页链接数量
# require 'rubygems'			# 1.8.7
require 'rubygems'
require 'mongoid'
require 'ap'				# gem install awesome_print
require 'json'
require 'net/http'
require 'nokogiri'			# gem install nokogiri
require 'forkmanager'		# gem install parallel-forkmanager
require 'beanstalk-client'	# gem install beanstalk-client

Dir.glob("#{File.dirname(__FILE__)}/app/models/*.rb") do |lib|
  require lib
end

ENV['MONGOID_ENV'] = 'aap'
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

	class Crawler
		def initialize(user_agent, redirect_limit=1)
			@user_agent = user_agent
			@redirect_limit = redirect_limit
			@timeout = 20 
		end
		attr_accessor :user_agent, :redirect_limit, :timeout
		
		def fetch(website)
			print "Pid:#{Process.pid}, fetch: #{website}\n"
			redirect, url = @redirect_limit, website
			start_time = Time.now
			redirecting = false
			begin
				begin
					uri = URI.parse(url)
					req = Net::HTTP::Get.new(uri.path)
					req.add_field('User-Agent', @user_agent)
					res = Net::HTTP.start(uri.host, uri.port) do |http|
						http.read_timeout = @timeout
						http.request(req)
					end
					if res.header['location'] # 遇到重定向，则url设定为location，再次抓取
						url = res.header['location'] 
						redirecting = true
					end
					redirect -= 1
				end while redirecting and redirect>=0
				opened_time = (Time.now - start_time).round(4) # 统计打开网站耗时

				html =  res 
				doc = Nokogiri::HTML(html)
		
				processed_time = (Time.now - start_time - opened_time).round(4) # 统计分析链接耗时, 1.8.7, ('%.4f' % float).to_f 替换 round(4)
				@file_to_write.puts "#{opened_time}\t#{processed_time}\t#{doc.css('a[@href]').size}\t#{res.header['server']}"
				
				html
			rescue =>e
				e.message  
			end
		end
	end
	
	def initialize(websites, beanstalk_jobs, pm_max=1, user_agent='', redirect_limit=1)
		@websites = websites  				# 网址数组 
		@beanstalk_jobs = beanstalk_jobs	# beanstalk服务器地址和管道参数
		@pm_max = pm_max 					# 最大并行运行进程数
		@user_agent = user_agent 			# user_agent 伪装成浏览器访问
		@redirect_limit = redirect_limit  	# 允许最大重定向次数
		
		@ipc_reader, @ipc_writer = IO.pipe # 缓存结果的 ipc 管道
	end
	
	attr_accessor :user_agent, :redirect_limit
	
	
	def create_file_to_write
		file_path = File.join('.', "multiple-#{Time.now.to_formatted_s(:number) }.txt")
		@file_to_write = IoFactory.init(file_path)
	end #create_file_to_write


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
		@websites.size.times{|i| beanstalk.put(i)} # 将所有的任务压栈
		beanstalk.close
		rescue => e 
			puts e 
			exit
	end
	
	def process_jobs # 处理任务
		start_time = Time.now
		pm = Parallel::ForkManager.new(@pm_max)
		@pm_max.times do |i| 
			pm.start(i) and next # 启动后，立刻 next 不会等待进程执行完，这样才可以并行运算
			beanstalk = Beanstalk::Pool.new(*@beanstalk_jobs)
			@ipc_reader.close	 # 关闭读取管道，子进程只返回数据
			loop{ 
				begin
					job = beanstalk.reserve(0.1) # 检测超时为0.1秒，因为任务以前提前压栈
					index = job.body
					job.delete
					website = @websites[index.to_i]
					result = Crawler.new(@user_agent).fetch(website)
					ap result
					@ipc_writer.puts( ({website=>result}).to_json )
				rescue Beanstalk::DeadlineSoonError, Beanstalk::TimedOut, SystemExit, Interrupt
					break
				end
			}
			@ipc_writer.close
			pm.finish(0)	
		end
		@ipc_writer.close
		begin 
			pm.wait_all_children		# 等待所有子进程处理完毕 
		rescue SystemExit, Interrupt	# 遇到中断，打印消息
			print "Interrupt wait all children!\n"
		ensure
			results = read_results
			ap results, :indent => -4 , :index=>false	# 打印处理结果
			print "Process end, total: #{@websites.size}, crawled: #{results.size}, time: #{'%.4f' % (Time.now - start_time)}s.\n"
		end
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
		create_file_to_write	
		process_jobs
	end
end

websites = %w(
http://shop.advanceautoparts.com/webapp/wcs/stores/servlet/AjaxManageMyGarageCmd?storeId=10151&catalogId=10051&langId=-1&vehicleID=407631&vehicleCODE=1441566&productId=54529&callingPage=CheckFitModal&saveVehicleFromCheckFit=false&actionCode=addVehicle&vehicleMake=Audi&vehicleModel=A4&vehicleEngine=2.0L+1984CC+L4+FI+Turbo+VIN&vehicleYear=2008
)


beanstalk_jobs = [['192.168.2.14:11300'],'crawler-jobs']
user_agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:13.0) Gecko/20100101 Firefox/13.0'
pm_max = 10

MultipleCrawler.new(websites, beanstalk_jobs, pm_max, user_agent).run