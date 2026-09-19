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
end
