# Mínimo necessário para a T8 provar a preservação da coleção. O fluxo de
# autenticação (sessões, login, logout) é da Fase 4 e usará o gerador do
# Rails 8, conforme verificado na T1.
class User < ApplicationRecord
  has_many :collection_items, dependent: :restrict_with_exception

  validates :email, presence: true
end
