class Ppipei
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :lid

  field	:product_id,	:type => String #产品网站序列号
  field :vehicle_id,	:type => String #汽车编号

  
  field :status							#是否采集 0、1
  field :result							#采集结果
  field :pipei							#是否匹配 0、1
  
  field :app_url,		:type => String #匹配网址				

  index :status => 1
  index :pipei => 1
  index :lid => 1
end

