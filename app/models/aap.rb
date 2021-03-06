class Aap
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :part_no, 	:type => String
  field :title, 	:type => String
  field :url, 		:type => String
  field	:product_id,	:type => String
  field :status
  

  embeds_many  :applications
  embeds_many  :parameters
  
  index :status => 1
end