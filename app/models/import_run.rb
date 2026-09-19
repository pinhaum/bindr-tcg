# Resumo persistido de uma execução da ingestão (Req. 1.6 e 1.10). O
# `source_revision` é o que permite responder "de qual versão da fonte veio
# este dado" depois do fato.
class ImportRun < ApplicationRecord
  STATUSES = %w[running succeeded failed].freeze

  validates :source, :source_revision, :started_at, presence: true
  validates :status, inclusion: { in: STATUSES }
end
