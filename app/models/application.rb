class Application
  include Mongoid::Document
  
  field :year
  field :maker, 	:type => String
  field :model, 		:type => String
  field :engine, 		:type => String
  field :vehicle_id,	:type => String
  field :vehicle_code,	:type => String


  embedded_in :aap
end