# Resumo persistido de uma execução da ingestão (Req. 1.6 e 1.10). O
# `source_revision` é o que permite responder "de qual versão da fonte veio
# este dado" depois do fato.
class ImportRun < ApplicationRecord
  STATUSES = %w[running succeeded failed].freeze

  # Chave do lock consultivo que serializa quem lê a presença para escrever
  # (`Ingestion::Remap`) com quem a muda (`Ingestion::Upsert#finish`). O valor
  # é arbitrário; só precisa ser o mesmo nos dois lados.
  PRESENCE_LOCK_KEY = 2_026_093_001

  validates :source, :source_revision, :started_at, presence: true
  validates :status, inclusion: { in: STATUSES }

  # `pg_advisory_xact_lock` só solta no fim da transação, então fora de uma
  # ele não protegeria nada.
  def self.lock_presence!
    raise ArgumentError, "lock_presence! exige transação aberta" unless connection.transaction_open?

    connection.execute("SELECT pg_advisory_xact_lock(#{PRESENCE_LOCK_KEY})")
  end
end
