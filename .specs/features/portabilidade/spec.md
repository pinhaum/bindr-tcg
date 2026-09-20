# Especificação — Import e export CSV (Fase 5)

Recorte da feature `portabilidade` sobre `.context/requirements.md` Req. 10 e
`.context/tasks.md` §5.2 e §5.3. Em divergência, `.context/` vence (AD-005).

Export e import na **mesma spec**, por decisão do dono do produto: o Req. 10.2
diz que o import aceita "o mesmo formato do export", então o formato é um
contrato único e separá-lo em duas specs criaria duas fontes de verdade para a
mesma tabela de colunas.

## Problem Statement

A coleção existe, é registrável por variante e agora tem progresso por set. Ela
continua **presa à aplicação**: quem já mantinha uma planilha não tem como
trazê-la, e quem usa o Bindr não tem como levar seu dado embora. O `product.md`
§7 posiciona o produto como substituto da planilha — sem porta de entrada, a
migração exige redigitar centenas de linhas, e sem porta de saída o produto pede
confiança que não devolve.

O risco desta feature **não é o mesmo nas duas metades**, e é isso que organiza o
plano inteiro:

- O **export** é leitura. O pior caso é um arquivo errado, que o usuário
  descarta e pede de novo. Nada se perde.
- O **import** é **escrita em massa sobre o único dado insubstituível do
  sistema**. O catálogo é regenerável (AD-001); a coleção não. Um import que
  sobrescreve o que não devia destrói trabalho que nenhuma reingestão
  reconstrói. Por isso o Req. 10.5 exige pré-visualização e confirmação — e por
  isso, nesta spec, **nenhuma escrita acontece sem o usuário ter visto antes o
  que vai mudar**.

## Goals

- [ ] Exportar a coleção do usuário em CSV com `card_number`, identificador da variante, nome da carta e quantidade.
- [ ] Importar um CSV no mesmo formato, resolvendo cada linha para uma variante existente.
- [ ] Linha com variante inexistente é rejeitada com motivo, e as demais seguem.
- [ ] Pré-visualização obrigatória, com confirmação explícita, antes de qualquer escrita.
- [ ] Resumo final: importadas, atualizadas, rejeitadas, com o motivo de cada rejeição.
- [ ] O arquivo exportado é aceito de volta pelo import sem edição — ida e volta fechada.

## Out of Scope

| Feature | Reason |
|---|---|
| Export ou import da wishlist | O Req. 10 fala de coleção. A wishlist tem `target_quantity`, não `quantity` — outro formato, outra decisão de merge. Feature nova, não detalhe desta. |
| Formatos além de CSV (XLSX, JSON) | O Req. 10 diz CSV. Cada formato novo é um parser novo a manter e a testar. |
| Import de planilhas de terceiros (TCGplayer, Deckbox, Dragon Shield) | Cada uma tem esquema próprio e identificador próprio de impressão. O Req. 10.2 pede o formato do **próprio** export. Mapear formatos alheios é feature de migração, com decisão de correspondência que esta spec não tem como tomar. |
| Import assíncrono / em background | Só entra se a medição com arquivo realista reprovar o tempo de resposta. Precedente da T10 da `colecao` e da T8 da `progresso`: medir antes, construir depois. |
| Desfazer (undo) de um import já confirmado | A pré-visualização é a barreira que o Req. 10.5 escolheu. Undo exigiria versionar a coleção inteira — decisão de modelo, não de portabilidade. |
| Correção da classificação de `art_kind` na ingestão | Dívida registrada na spec da `progresso`, ainda aberta. Nada nesta feature depende dela. |
| Criação ou alteração de índice | Só entra se a medição reprovar o alvo. Mesmo precedente das features anteriores. |

## Assumptions & Open Questions

| Assumption/decision | Chosen default | Rationale | Confirmed? |
|---|---|---|---|
| **Chave que identifica a variante no CSV** | O **par** `card_number` + `variant_code`, as duas colunas juntas | O índice único do schema é `(card_id, variant_code)` — **por carta, não global** (`db/structure.sql:518`). Hoje os 4917 `variant_code` são todos distintos entre si, mas isso é propriedade **dos dados**, não garantia do banco: uma fonte que reemita `p1` para outra carta não viola constraint nenhuma. Resolver por `variant_code` sozinho funcionaria hoje e passaria a casar a variante errada em silêncio depois. O par é também exatamente o que o Req. 10.1 já manda exportar | Sim — medido e conferido no schema |
| Colunas do CSV | `card_number`, `variant_code`, `card_name`, `quantity`, nesta ordem, com linha de cabeçalho | Req. 10.1 pede as quatro. Cabeçalho porque o arquivo é lido por humano em planilha, e porque o import pode validar o formato antes de processar linha nenhuma | Sim — Req. 10.1 |
| Papel de `card_name` no import | **Informativo, nunca chave.** O import resolve por `card_number` + `variant_code` e ignora divergência de nome | O nome existe para o humano reconhecer a linha na planilha. Usá-lo como chave quebraria o import na primeira correção de grafia vinda da fonte externa — e o catálogo é regenerável, logo o nome muda sem o usuário fazer nada | Sim |
| **Semântica do import sobre linha já existente** | **Substituir**: a quantidade do CSV passa a ser a quantidade possuída | **AD-006.** É a única leitura sob a qual o arquivo do export é idempotente na volta (POR-11): somar dobraria a coleção a cada ciclo de exportar-e-reimportar. A pré-visualização mostra o antes e o depois por linha, então substituir 2 por 3 é visível antes de gravar | Sim — AD-006 |
| Momento da escrita | Nenhuma escrita antes da confirmação. O upload produz uma pré-visualização; a gravação é uma segunda requisição, explícita | Req. 10.5 literal. É a barreira que separa "arquivo errado" de "coleção destruída" | Sim — Req. 10.5 |
| Onde vive o arquivo entre a pré-visualização e a confirmação | **Tabela de staging**, dona do usuário que a criou, com expiração | **AD-007.** É a única das três que garante que a confirmação grava o que a pré-visualização mostrou — o cookie de 4KB não comporta mil linhas, e o reenvio permite que o arquivo mude entre as duas etapas. Custa uma migração: `schema_format` é `:sql` | Sim — AD-007 |
| Autorização das duas metades | **Exigem sessão.** Sem `allow_unauthenticated_access`, herdando o default de `ApplicationController` | Export sem sessão exporia coleção alheia ou devolveria arquivo vazio; import sem sessão não tem onde gravar. O default protegido do app já resolve por construção — e evita a armadilha do `allow_unauthenticated_access` que apareceu cinco vezes na `colecao` | Sim — `app/controllers/concerns/authentication.rb` |
| Origem do usuário | `Current.user`, via `CollectionItem.for_user(user)`; nenhum identificador de usuário vem do request | Req. 6.5 por construção. `for_user` exige o objeto `User` e levanta `ArgumentError` para um id | Sim — `app/models/collection_item.rb` |
| O que o export inclui | As linhas de `CollectionItem.for_user(user).owned` — quantidade ≥ 1 | Req. 7.3: zero é linha existente que significa "não tenho". Exportar zeros encheria o arquivo de linhas sem informação e, na volta, pediria uma decisão de merge que o usuário não pediu | Sim — scope `owned` vigente |
| Biblioteca de CSV | `csv` da stdlib, **declarada explicitamente no Gemfile** | Medido: `csv 3.2.8` disponível sob Ruby 3.3.0, hoje como *default gem*. A partir do Ruby 3.4 ela deixa de ser carregada implicitamente; declarar agora custa uma linha e evita que a atualização de Ruby quebre a feature sem aviso. Gem nova exige `docker compose run --rm --no-deps app bundle install` — o volume `bundle` sombreia as gems da imagem | Sim — medido |
| Codificação e delimitador | UTF-8, vírgula | O catálogo tem nomes com acento e caractere não-ASCII. Planilha em pt-BR frequentemente usa `;` — mas aceitar dois delimitadores no import exige detecção, que erra. Fixar um e documentá-lo é mais honesto que adivinhar | Sim |
| Tamanho máximo de arquivo aceito | **10.000 linhas de dado**, sem contar o cabeçalho; recusa antes de processar linha nenhuma | **AD-008.** Folga de pouco mais de 2× sobre o teto do domínio (4917 variantes), medido. Em linhas e não em bytes porque é a unidade que o usuário entende e a que determina o custo. Verificado junto da validação de formato | Sim — AD-008 |
| Verificação de comportamento visual | Teste de integração sobre HTML renderizado, com `SPEC_DEVIATION` no cabeçalho do arquivo | Não há navegador no container, logo não há system test. Precedente estabelecido em `collection_ownership_ui_test.rb` e nas três features anteriores | Sim — `CLAUDE.md` |

**Open questions:** none. As três que bloqueavam o import foram decididas pelo
dono do produto e registradas em `.specs/STATE.md` — **P8** em **AD-006**
(substituir), **P9** em **AD-007** (tabela de staging) e **P10** em **AD-008**
(10.000 linhas). Nenhuma se reabre nesta feature.

## Decisões tomadas — P8, P9 e P10

Os três pontos onde o requisito não decidia foram decididos pelo dono do produto
e registrados em `.specs/STATE.md`. **Nenhum se reabre nesta feature.**

| # | Pergunta | Decisão | ADR |
|---|---|---|---|
| P8 | Import sobre variante que o usuário já possui | **Substituir** — a quantidade do CSV passa a ser a quantidade possuída | AD-006 |
| P9 | Onde o arquivo vive entre a pré-visualização e a confirmação | **Tabela de staging**, dona do usuário, com expiração | AD-007 |
| P10 | Limite de tamanho do arquivo | **10.000 linhas de dado**, recusa antes de processar qualquer linha | AD-008 |

### P8 — substituir, e o que isso custa

Das três leituras (substituir, somar, maior valor), **substituir é a única sob a
qual o export é idempotente na volta**, que é o que o Req. 10.2 e o POR-11 pedem:
exportar e reimportar sem editar tem de deixar a coleção idêntica. Sob "somar", o
fluxo mais óbvio do produto — baixar, conferir, devolver — dobraria a coleção
inteira a cada ciclo. Sob "maior valor", quem vendeu duas cópias e corrige o
número para baixo é ignorado em silêncio.

O que se perde: o caso de uso de **planilha de aquisição** ("abri uma caixa,
registrei o que veio") fica descoberto — quem quiser isso precisa somar à mão
antes de enviar. A mitigação é a pré-visualização, que mostra **antes e depois**
por linha: trocar 2 por 3 é visível na tela antes de gravar. Se o caso de
aquisição se mostrar frequente, a saída é um modo de merge escolhido no upload,
**não** mudar este default.

### P9 — tabela de staging, e a migração que ela implica

O Req. 10.5 exige que a confirmação grave **o que a pré-visualização mostrou**, e
só o staging dá essa garantia. O cookie de sessão tem teto de 4KB e não comporta
mil linhas (limite medido, não preferência). O reenvio do arquivo na confirmação
não guarda estado, mas deixa o arquivo **mudar entre as duas etapas** — a
pré-visualização passaria a descrever algo que não é o que será gravado, o que
esvazia a barreira que o requisito existe para criar.

Consequências que o plano precisa absorver: **esta feature tem migração**
(`schema_format` é `:sql`, logo `db:migrate` para regenerar `db/structure.sql`);
a tabela guarda dado do usuário fora da coleção e entra no mesmo regime de
autorização (leitura por `Current.user`, pré-visualização alheia não é
confirmável); e precisa de política de expiração e limpeza.

### P10 — 10.000 linhas

O teto natural do domínio hoje é **4917 variantes**: uma coleção que possuísse
todas as impressões existentes daria um CSV desse tamanho. 10.000 é folga de
pouco mais de 2× — aceita qualquer coleção real, inclusive com o catálogo
crescendo, e ainda põe teto no trabalho de uma requisição. O limite é em
**linhas**, não em bytes, porque é a unidade que o usuário entende e a que
determina o custo real (uma linha = uma resolução de variante).

É um número **escolhido, não derivado**: nenhuma medição diz que 10.000 é seguro
e 10.001 não é. Ele protege contra o arquivo absurdo, não contra o grande-mas-
legítimo. Se a medição de custo (POR-13) mostrar que 10.000 linhas não cabem no
tempo de resposta, a saída é import assíncrono ou um limite menor **com
medição** — não afrouxar este número no escuro.

## User Stories

### P0: Suíte confiável antes de escrever a feature ⭐ PRIMEIRO PASSO

**User Story**: Como quem vai implementar esta feature, quero que a suíte falhe apenas quando há defeito, para que o gate signifique alguma coisa durante a execução do plano.

**Why P0**: Dois testes de **outras features** falham de forma intermitente, medido
durante a execução da `progresso`. Não são defeitos desta feature e não têm relação
com CSV — mas esta feature tem **gate full em toda task**, e um gate que falha 1 em 6
por acaso treina quem executa a ignorar vermelho. Numa feature cuja metade escreve
em massa sobre dado insubstituível, essa é a pior dívida possível de carregar.
É o primeiro passo, antes de qualquer linha de export.

**Acceptance Criteria**:
1. The system SHALL apresentar `test/services/ingestion/guarantees_test.rb` verde de forma determinística, sem depender do instante em que a ingestão roda.
2. The system SHALL apresentar `test/queries/catalog_search_test.rb` verde de forma determinística, sem depender de contenção do planejador.
3. WHEN a suíte completa rodar doze vezes seguidas THEN nenhum dos dois testes SHALL falhar.
4. The system SHALL preservar a garantia que cada teste existia para provar — nenhuma asserção enfraquecida, pulada ou removida.

**Independent Test**: Rodar a suíte completa doze vezes e conferir zero falha nos dois arquivos; reverter a correção e confirmar que a garantia original volta a ser exercida.

**Diagnóstico já levantado, a confirmar antes de corrigir**:

- `guarantees_test.rb:210` — `assert_operator presente.last_seen_at, :>, ausente.last_seen_at`, com as duas marcas truncadas por `to_i`. Quando as duas ingestões caem no mesmo segundo, empatam e o `>` estrito falha. É asserção estrita sobre relógio.
- `catalog_search_test.rb:296` — asserção de plano (`refute_match(/Seq Scan on cards/)`) que depende de o planejador escolher índice; sob contenção ele escolhe `Seq Scan` com razão. Mesma família do que a T8 da `progresso` encontrou: **asserção de plano é sensível a estatísticas**, e sem `ANALYZE` recente o plano medido é outro.

**Nota de método**: o padrão que atravessa os dois é *asserção estrita sobre
relógio ou sobre estatística*. Corrigir sem entender isso produz a terceira
ocorrência numa feature futura.

### P1: Export da coleção em CSV ⭐ MVP

**User Story**: Como usuário, quero baixar minha coleção em CSV, para não ficar preso à aplicação.

**Why P1**: É o Req. 10.1 inteiro, é a metade sem risco de perda, e é o que define
o formato de que o import depende.

**Acceptance Criteria**:
1. The system SHALL exportar a coleção do usuário da sessão em CSV com `card_number`, identificador da variante, nome da carta e quantidade.
2. The system SHALL incluir linha de cabeçalho nomeando as colunas.
3. The system SHALL exportar apenas as variantes possuídas, tratando quantidade zero como não possuída.
4. WHEN o usuário não possuir nenhuma variante THEN the system SHALL entregar um arquivo com cabeçalho e nenhuma linha de dado, em vez de erro ou arquivo vazio.
5. The system SHALL derivar o conteúdo do usuário da sessão, ignorando qualquer identificador de usuário vindo da requisição.
6. WHEN um usuário não autenticado solicitar o export THEN the system SHALL redirecionar para a autenticação sem entregar arquivo.
7. The system SHALL entregar o arquivo com codificação UTF-8, preservando acentos dos nomes de carta.

**Independent Test**: Autenticado, com posse conhecida em variantes de sets distintos e uma variante zerada, baixar o CSV e conferir cabeçalho, uma linha por variante possuída, a ausência da zerada, e os acentos íntegros.

### P1: Pré-visualização obrigatória do import ⭐ MVP

**User Story**: Como usuário, quero ver exatamente o que vai mudar na minha coleção antes de confirmar, para não destruir meu registro com um arquivo errado.

**Why P1**: É o Req. 10.5 e é a única barreira entre um arquivo errado e a perda do
dado insubstituível. Sem ela, o import não deve existir.

**Acceptance Criteria**:
1. The system SHALL apresentar, antes de qualquer escrita, o que cada linha do arquivo produzirá na coleção.
2. The system SHALL distinguir na pré-visualização as linhas que criam registro, as que alteram registro existente e as que serão rejeitadas.
3. The system SHALL exigir uma confirmação explícita do usuário para gravar.
4. WHILE a confirmação não ocorrer, the system SHALL manter a coleção inalterada.
5. WHEN o usuário abandonar o fluxo sem confirmar THEN the system SHALL deixar a coleção exatamente como estava.
6. The system SHALL gravar, na confirmação, exatamente o que a pré-visualização apresentou.

**Independent Test**: Enviar um arquivo, conferir a pré-visualização contra a coleção real, abandonar o fluxo e verificar que nada mudou; repetir confirmando e verificar que o resultado é idêntico ao previsto.

### P1: Import linha a linha com rejeição isolada ⭐ MVP

**User Story**: Como usuário, quero que uma linha ruim não impeça a importação das boas, para não ter que caçar o erro e reenviar tudo.

**Why P1**: Req. 10.2 e 10.3. É a mesma garantia que a ingestão já dá ao catálogo
(Req. 1.5): erro isolado não aborta o lote.

**Acceptance Criteria**:
1. The system SHALL importar linhas no mesmo formato produzido pelo export.
2. WHEN uma linha referenciar uma variante inexistente THEN the system SHALL rejeitar essa linha com motivo e continuar processando as demais.
3. WHEN uma linha tiver quantidade inválida THEN the system SHALL rejeitá-la com motivo, sem interromper o lote.
4. The system SHALL resolver a variante pelo par `card_number` + identificador da variante, nunca pelo nome da carta.
5. IF o arquivo não estiver no formato esperado THEN the system SHALL recusá-lo inteiro com mensagem em português, antes de processar qualquer linha.
6. The system SHALL gravar cada linha aceita sem desfazer as anteriores por causa de uma posterior.
7. WHEN o arquivo produzido pelo export for reimportado sem edição THEN the system SHALL deixar a coleção idêntica ao estado exportado.

**Independent Test**: Importar um arquivo com linhas válidas, uma variante inexistente e uma quantidade inválida; conferir que as válidas entraram, as duas foram rejeitadas com motivo, e que reimportar o próprio export não altera nada.

### P2: Resumo final da importação

**User Story**: Como usuário, quero um resumo do que entrou, do que mudou e do que foi recusado, para saber se preciso corrigir alguma coisa.

**Why P2**: Req. 10.4. Não altera o que é gravado; torna o resultado auditável pelo
usuário.

**Acceptance Criteria**:
1. The system SHALL apresentar, ao final, a quantidade de linhas importadas, atualizadas e rejeitadas.
2. The system SHALL apresentar o motivo de cada linha rejeitada, identificando a linha.
3. The system SHALL apresentar o resumo em português.
4. WHERE nenhuma linha for rejeitada, the system SHALL apresentar o resumo sem sugerir erro.

**Independent Test**: Importar um arquivo com os três desfechos e conferir que os três números batem com o estado real da coleção depois da gravação.

### P2: Isolamento e custo das duas metades

**User Story**: Como usuário, quero que o export traga só a minha coleção e que o import escreva só nela, mesmo que outra pessoa envie um arquivo com as mesmas variantes.

**Why P2**: Não acrescenta informação, mas é o que torna as histórias P1 corretas.
Falha aqui é vazamento ou corrupção, não usabilidade.

**Acceptance Criteria**:
1. The system SHALL derivar export e import do usuário da sessão corrente.
2. IF uma requisição informar um identificador de usuário THEN the system SHALL ignorá-lo.
3. WHILE dois usuários importarem arquivos com as mesmas variantes, the system SHALL manter as duas coleções independentes.
4. The system SHALL resolver o export em um número de consultas que não cresce com a quantidade de linhas exportadas.
5. The system SHALL resolver a pré-visualização sem emitir uma consulta por linha do arquivo.

**Independent Test**: Dois usuários com posses distintas; exportar por ambos e conferir que cada arquivo tem só o seu; importar o arquivo de um estando autenticado como o outro e conferir que a coleção do primeiro não muda.

## Edge Cases

- WHEN o CSV contiver a mesma variante em duas linhas, THEN o comportamento decorre de P8 e precisa ser explícito na pré-visualização — a última linha não pode vencer em silêncio.
- WHEN uma linha tiver quantidade zero, THEN ela significa "não possuo" (Req. 7.3) e o efeito sobre um registro existente decorre de P8.
- IF o arquivo vier com BOM (planilhas do Excel o inserem), THEN o cabeçalho não pode deixar de ser reconhecido por causa dele.
- IF o arquivo vier com `;` em vez de `,`, THEN ele é recusado com mensagem que diz o delimitador esperado, em vez de importar uma coluna só.
- WHEN o arquivo tiver cabeçalho em ordem diferente, THEN as colunas são resolvidas por nome, não por posição.
- IF uma variante referenciada tiver sido marcada como ausente da fonte, THEN ela continua importável — a ingestão não deleta (Req. 1.7).
- WHEN o catálogo for reingerido entre o export e o import, THEN o par `card_number` + `variant_code` continua resolvendo, porque ambos são estáveis por AD-001.
- IF o usuário enviar um arquivo que não é CSV, THEN a recusa é explícita e em português, sem stack trace.
- WHEN a sessão expirar entre a pré-visualização e a confirmação, THEN nada é gravado e o usuário é levado à autenticação.
- IF duas confirmações da mesma pré-visualização chegarem, THEN a segunda não duplica o efeito da primeira.

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
|---|---|---|---|
| POR-00 | Suíte determinística antes de começar | 5 | Pending |
| POR-01 | Export com `card_number`, variante, nome e quantidade (Req. 10.1) | 5 | Pending |
| POR-02 | Export só de variantes possuídas (Req. 7.3) | 5 | Pending |
| POR-03 | Export exige sessão e parte de `Current.user` (Req. 6.4, 6.5) | 5 | Pending |
| POR-04 | Import aceita o formato do export (Req. 10.2) | 5 | Pending |
| POR-05 | Linha com variante inexistente é rejeitada com motivo (Req. 10.3) | 5 | Pending |
| POR-06 | Rejeição isolada não aborta o lote (Req. 10.3) | 5 | Pending |
| POR-07 | Pré-visualização obrigatória antes de gravar (Req. 10.5) | 5 | Pending |
| POR-08 | Confirmação explícita grava o que foi previsto (Req. 10.5) | 5 | Pending |
| POR-09 | Resumo com importadas, atualizadas e rejeitadas (Req. 10.4) | 5 | Pending |
| POR-10 | Motivo por linha rejeitada (Req. 10.4) | 5 | Pending |
| POR-11 | Ida e volta idempotente: reimportar o export não altera nada | 5 | Pending |
| POR-12 | Import exige sessão e escreve só na coleção do usuário (Req. 6.4, 6.5) | 5 | Pending |
| POR-13 | Export e pré-visualização sem consulta por linha (Req. 11.1) | 5 | Pending |

**Coverage:** 14 total, 0 mapped to tasks, 14 unmapped ⚠️ (tasks.md ainda não
escrito — próxima fase, após revisão desta spec e resolução de P8, P9 e P10)

## Success Criteria

- [ ] Um usuário exporta a coleção, abre em planilha, edita quantidades e reimporta, vendo antes o que vai mudar.
- [ ] Existe teste que prova que reimportar o próprio export não altera a coleção — a ida e volta é fechada.
- [ ] Existe teste que prova que abandonar o fluxo após a pré-visualização deixa a coleção intacta.
- [ ] Existe teste que prova que uma linha com variante inexistente é rejeitada com motivo e as demais entram.
- [ ] Existe teste que prova que dois usuários que importam o mesmo arquivo mantêm coleções independentes.
- [ ] Existe teste que prova que o import resolve pelo par `card_number` + `variant_code`, e não pelo nome.
- [ ] A suíte roda doze vezes seguidas sem falha intermitente, incluindo os dois testes herdados.
- [ ] `bin/rails test` passa inteiro, sem alteração de asserção existente.
- [ ] `bin/rubocop` limpo.
