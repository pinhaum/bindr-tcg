# Req. 11.1 / T13 — mede a latência da consulta de catálogo com busca e
# filtros combinados, sobre o catálogo completo.
#
# Não é teste: é medição. Não assere nada, imprime percentis. O alvo (p95 <
# 500ms) é avaliado por quem lê, e o resultado fica registrado na task.
namespace :catalog do
  desc "Mede a latência (p50/p95/p99) da busca com filtros combinados"
  task benchmark: :environment do
    repeticoes = Integer(ENV.fetch("REPS", 50))

    cenarios = {
      "busca + 3 filtros (alvo do Req. 11.1)" => {
        q: "Zorro", colors: [ "Red" ], card_types: [ "character" ], cost_min: 2, cost_max: 6
      },
      "busca sozinha" => { q: "Zorro" },
      "3 filtros sem busca" => {
        colors: [ "Red" ], card_types: [ "character" ], cost_min: 2, cost_max: 6
      },
      "busca com typo + filtros" => {
        q: "Luffi", colors: [ "Red" ], card_types: [ "character" ], cost_min: 1
      },
      "card_number exato + filtros" => {
        q: "OP01-001", colors: [ "Red" ], card_types: [ "leader" ]
      },
      "filtro por trait + set + raridade" => {
        traits: [ "Straw Hat Crew" ], sets: [ "OP01" ], rarities: [ "SR" ]
      }
    }

    puts "Catálogo: #{Card.count} cartas, #{CardVariant.count} variantes, #{CardSet.count} sets"
    puts "Repetições por cenário: #{repeticoes}"
    puts

    cenarios.each do |nome, params|
      # Descarta as primeiras execuções: a primeira paga plano, cache frio e
      # carregamento de classe, e mediria o boot em vez da consulta.
      3.times { CatalogQuery.new(params).call }

      amostras = Array.new(repeticoes) do
        inicio = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        resultado = CatalogQuery.new(params).call
        resultado.records.length # força materializar, senão mediria o lazy
        (Process.clock_gettime(Process::CLOCK_MONOTONIC) - inicio) * 1000
      end.sort

      total = CatalogQuery.new(params).call.total_count
      p50 = amostras[(repeticoes * 0.50).floor]
      p95 = amostras[(repeticoes * 0.95).ceil - 1]
      p99 = amostras[(repeticoes * 0.99).ceil - 1]

      veredito = p95 < 500 ? "OK" : "ACIMA DO ALVO"
      puts format("%-42s p50=%6.1fms  p95=%6.1fms  p99=%6.1fms  (%d cartas) %s",
                  nome, p50, p95, p99, total, veredito)
    end
  end
end
