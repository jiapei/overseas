class Pipei
  include Mongoid::Document
  include Mongoid::Timestamps

  field	:product_id,	:type => String #²úÆ·ÍøÕ¾ÐòÁÐºÅ
  field :vehicle_id,	:type => String #Æû³µ±àºÅ
  
  field :status							#ÊÇ·ñ²É¼¯ 0¡¢1
  field :result							#²É¼¯½á¹û
  field :pipei							#ÊÇ·ñÆ¥Åä 0¡¢1
  
  field :app_url,		:type => String #Æ¥ÅäÍøÖ·				
  field :lid
  
  index :status => 1
  index :pipei => 1

end
