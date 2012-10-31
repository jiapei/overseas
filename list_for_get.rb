#!/usr/bin/env ruby
#encoding: UTF-8

# ץȡÿһ��վ�����ҳ��������
# require 'rubygems'			# 1.8.7
require 'rubygems'
require 'mongoid'
require 'ap'				# gem install awesome_print
require 'json'
require 'net/http'
require 'nokogiri'			# gem install nokogiri
require 'forkmanager'		# gem install parallel-forkmanager
require 'beanstalk-client'	# gem install beanstalk-client

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
					if res.header['location'] # �����ض�����url�趨Ϊlocation���ٴ�ץȡ
						url = res.header['location'] 
						redirecting = true
					end
					redirect -= 1
				end while redirecting and redirect>=0
				opened_time = (Time.now - start_time).round(4) # ͳ�ƴ���վ��ʱ
				encoding = res.body.scan(/<meta.+?charset=["'\s]*([\w-]+)/i)[0]
				encoding = encoding ? encoding[0].upcase : 'GB18030'
				html = 'UTF-8'==encoding ? res.body : res.body.force_encoding('GB2312'==encoding || 'GBK'==encoding ? 'GB18030' : encoding).encode('UTF-8') 
				doc = Nokogiri::HTML(html)
				processed_time = (Time.now - start_time - opened_time).round(4) # ͳ�Ʒ������Ӻ�ʱ, 1.8.7, ('%.4f' % float).to_f �滻 round(4)
				[opened_time, processed_time, doc.css('a[@href]').size, res.header['server']]
			rescue =>e
				e.message  
			end
		end
	end
	
	def initialize(websites, beanstalk_jobs, pm_max=1, user_agent='', redirect_limit=1)
		@websites = websites  				# ��ַ���� 
		@beanstalk_jobs = beanstalk_jobs	# beanstalk��������ַ�͹ܵ�����
		@pm_max = pm_max 					# ��������н�����
		@user_agent = user_agent 			# user_agent αװ�����������
		@redirect_limit = redirect_limit  	# ��������ض������
		
		@ipc_reader, @ipc_writer = IO.pipe # �������� ipc �ܵ�
	end
	
	attr_accessor :user_agent, :redirect_limit
	
	def init_beanstalk_jobs # ׼��beanstalk����
		beanstalk = Beanstalk::Pool.new(*@beanstalk_jobs)
		#���beanstalk�Ĳ�����Ϣ����
		begin
			while job = beanstalk.reserve(0.1) 
				job.delete
			end
		rescue Beanstalk::TimedOut
			print "Beanstalk queues cleared!\n"
		end
		@websites.size.times{|i| beanstalk.put(i)} # �����е�����ѹջ
		beanstalk.close
		rescue => e 
			puts e 
			exit
	end
	
	def process_jobs # ��������
		start_time = Time.now
		pm = Parallel::ForkManager.new(@pm_max)
		@pm_max.times do |i| 
			pm.start(i) and next # ���������� next ����ȴ�����ִ���꣬�����ſ��Բ�������
			beanstalk = Beanstalk::Pool.new(*@beanstalk_jobs)
			@ipc_reader.close	 # �رն�ȡ�ܵ����ӽ���ֻ��������
			loop{ 
				begin
					job = beanstalk.reserve(0.1) # ��ⳬʱΪ0.1�룬��Ϊ������ǰ��ǰѹջ
					index = job.body
					job.delete
					website = @websites[index.to_i]
					result = Crawler.new(@user_agent).fetch(website)
					@ipc_writer.puts( ({website=>result}).to_json )
				rescue Beanstalk::DeadlineSoonError, Beanstalk::TimedOut, SystemExit, Interrupt
					break
				end
			}
			@ipc_writer.close
			pm.finish(0)	
	end		@ipc_writer.close
		begin 
			pm.wait_all_children		# �ȴ������ӽ��̴������ 
		rescue SystemExit, Interrupt	# �����жϣ���ӡ��Ϣ
			print "Interrupt wait all children!\n"
		ensure
			results = read_results
			ap results, :indent => -4 , :index=>false	# ��ӡ������
			print "Process end, total: #{@websites.size}, crawled: #{results.size}, time: #{'%.4f' % (Time.now - start_time)}s.\n"
		end
	end
	
	def read_results # ͨ���ܵ���ȡ�ӽ���ץȡ���ص�����
		results = {}
		while result = @ipc_reader.gets
			results.merge! JSON.parse(result)
		end
		@ipc_reader.close
		results
	end
	
	def run # �������
		init_beanstalk_jobs
		process_jobs
	end
end
websites = []

links = Link.where( :status => 0, :lid.lte => 100)
links.each do |link|
	websites << link.app_url
end

beanstalk_jobs = [['192.168.2.14:11300'],'crawler-jobs']
user_agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:13.0) Gecko/20100101 Firefox/13.0'
pm_max = 10

MultipleCrawler.new(websites, beanstalk_jobs, pm_max, user_agent).run