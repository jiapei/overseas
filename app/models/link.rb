class Link
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :lid
  field :part_no, 		:type => String #��Ʒ����
  field :title, 		:type => String	#��Ʒ����
  field :url, 			:type => String #��ַ
  field	:product_id,	:type => String #��Ʒ��վ���к�

  field :year							#���	
  field :maker, 		:type => String #maker
  field :model, 		:type => String #����
  field :engine, 		:type => String #������
  field :vehicle_id,	:type => String #�������
  field :vehicle_code,	:type => String #��������
  
  field :status							#�Ƿ�ɼ� 0��1
  field :result							#�ɼ����
  field :pipei							#�Ƿ�ƥ�� 0��1
  
  field :app_url,		:type => String #ƥ����ַ				
  
  index :status => 1
  index :pipei => 1
  index :year => 1
  index :lid => 1
end