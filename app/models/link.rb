class Link
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :lid
  field :part_no, 		:type => String #产品号码
  field :title, 		:type => String	#产品名称
  field :url, 			:type => String #地址
  field	:product_id,	:type => String #产品网站序列号

  field :year							#年份	
  field :maker, 		:type => String #maker
  field :model, 		:type => String #车型
  field :engine, 		:type => String #发动机
  field :vehicle_id,	:type => String #汽车编号
  field :vehicle_code,	:type => String #汽车代码
  
  field :status							#是否采集 0、1
  field :result							#采集结果
  field :pipei							#是否匹配 0、1
  
  field :app_url,		:type => String #匹配网址				
  
  index :status => 1
  index :pipei => 1
  index :year => 1
  index :lid => 1
end