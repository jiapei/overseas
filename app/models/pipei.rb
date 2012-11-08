class Pipei
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :lid

  field	:product_id,	:type => String #��Ʒ��վ���к�
  field :vehicle_id,	:type => String #�������

  
  field :status							#�Ƿ�ɼ� 0��1
  field :result							#�ɼ����
  field :pipei							#�Ƿ�ƥ�� 0��1
  
  field :app_url,		:type => String #ƥ����ַ				

  index :status => 1
  index :pipei => 1
  index :lid => 1
end