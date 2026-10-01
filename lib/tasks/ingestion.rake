namespace :ingestion do
  desc "Importa o catálogo da apitcg; com SNAPSHOT=<arquivo> reprocessa o snapshot sem rede nem chave (SRC-07)"
  task import: :environment do
    run = Ingestion::Run.call(snapshot: ENV["SNAPSHOT"].presence)

    puts "revisão: #{run.source_revision}"
    puts "status: #{run.status}"
    puts "criados: #{run.created_count} | atualizados: #{run.updated_count} | falhados: #{run.failed_count}"
    puts "cartas: #{Card.count} | variantes: #{CardVariant.count} | sets: #{CardSet.count}"
    exit(1) unless run.status == "succeeded"
  rescue Ingestion::SourceConfig::MissingApiKey, Ingestion::Run::SnapshotUnreadable => e
    warn e.message
    exit(1)
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

  desc "Compara dois snapshots e informa mudanças de tcgplayer.id (SRC-31)"
  task compare_snapshots: :environment do
    a_path = ENV["A"]
    b_path = ENV["B"]

    if a_path.blank? || b_path.blank?
      warn "faltam argumentos: A=<arquivo> B=<arquivo>"
      exit(1)
    end

    begin
      result = Ingestion::Apitcg::CompareSnapshots.call(a_path, b_path)

      puts "comuns: #{result.common}"
      puts "mudados: #{result.changed}"
      result.changes.each do |change|
        puts "#{change[:_id]} #{change[:from]} → #{change[:to]}"
      end
    rescue => e
      warn e.message
      exit(1)
    end
  end
end
