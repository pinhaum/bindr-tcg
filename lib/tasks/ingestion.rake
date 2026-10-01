namespace :ingestion do
  desc "Importa o catálogo da revisão fixada em config/ingestion.yml (Req. 1.1)"
  task import: :environment do
    run = Ingestion::Run.call(reuse_payload: ENV["REUSE_PAYLOAD"] == "1")

    puts "revisão: #{run.source_revision}"
    puts "status: #{run.status}"
    puts "criados: #{run.created_count} | atualizados: #{run.updated_count} | falhados: #{run.failed_count}"
    puts "cartas: #{Card.count} | variantes: #{CardVariant.count} | sets: #{CardSet.count}"
    exit(1) unless run.status == "succeeded"
  end

  desc "Aponta coleção e wishlist para as variantes da fonte atual (SRC-19..SRC-23)"
  task remap: :environment do
    report = Ingestion::Remap.call

    # Só `card_number`, `variant_code` e motivo: nada que identifique o usuário.
    puts "movidos: #{report.moved.size} | pulados: #{report.skipped.size}"
    report.skipped.each do |entry|
      puts "pulado: #{entry[:card_number]} | #{entry[:old_variant_code]} | #{entry[:reason]}"
    end
  rescue Ingestion::Remap::NoSucceededRun, Ingestion::Remap::ConcurrentChange => e
    warn e.message
    exit(1)
  end
end
