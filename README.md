# Bindr

Galeria de cartas do One Piece Card Game (OPTCG) e registro de coleção pessoal.
Uso pessoal, não comercial.

Rails 8 + Hotwire + PostgreSQL. A escolha do banco não é preferência: `pg_trgm`,
`unaccent` e índices GIN sobre arrays sustentam a busca e os filtros (AD-002 em
`.specs/STATE.md`).

## Subir o projeto

Pré-requisitos: Docker e Docker Compose. Nada mais — Ruby e PostgreSQL rodam
dentro dos containers.

```bash
docker compose up
```

A aplicação fica em <http://localhost:3000>. A primeira subida constrói a imagem
e cria o banco; as seguintes só aplicam migrações pendentes, porque o container
roda `db:prepare`, que é idempotente.

**A primeira subida entrega o catálogo vazio.** Para carregá-lo com o catálogo
real, rode o próximo passo.

Para parar: `docker compose down`. Para descartar também o banco:
`docker compose down -v`.

### Configuração local (opcional)

O arquivo `.env.example` tem defaults que funcionam localmente sem personalização.
Se precisar mudar credenciais ou nomes do banco, copie o arquivo e edite:

```bash
cp .env.example .env
```

Então `docker compose up` vai usar os valores de `.env`.

## Ingestão do catálogo

A chave da apitcg fica em `APITCG_API_KEY` no `.env` — obrigatória só para
`ingestion:import` sem `SNAPSHOT=`. Os testes usam um cliente HTTP falso e não a usam.

```bash
# Busca na apitcg real (requer chave em APITCG_API_KEY)
docker compose exec app bin/rails ingestion:import
```

A saída mostra a origem do snapshot, status (`succeeded` ou `failed`), contagem de cartas
criadas/atualizadas/falhadas e o total de registros no banco:

```
revisão: apitcg-20261001T024920Z.json sha256:<hex>
status: succeeded
criados: <n> | atualizados: <n> | falhados: <n>
cartas: <n> | variantes: <n> | sets: <n>
```

Se a fonte não estiver disponível, o processo registra um `ImportRun` `failed` e
aborta antes de escrever no catálogo, sem deixar registros parciais. Para reprocessar um snapshot já salvo em disco (útil
offline ou para testar):

```bash
# Reprocessa sem rede nem chave (útil para testes ou quando a API está fora)
docker compose exec app bin/rails ingestion:import SNAPSHOT=storage/ingestion/apitcg-20261001T024920Z.json

# Aponta coleção e wishlist para as variantes da fonte atual (sempre após import)
docker compose exec app bin/rails ingestion:remap

# Compara dois snapshots para medir estabilidade do tcgplayer.id (necessário com ≥24h de diferença)
docker compose exec app bin/rails ingestion:compare_snapshots A=storage/ingestion/<arquivo-A> B=storage/ingestion/<arquivo-B>
```

Os snapshots brutos ficam em `storage/ingestion/` — diretório ignorado pelo git,
reconstruível a partir de `ingestion:import`. A tarefa sai com código 1 se o status
não for `succeeded` (AD-019).

## Testes e verificações

Os três gates de verificação local:

```bash
# quick: testes de modelos e queries
docker compose exec app bin/rails test test/models test/queries

# full: suíte completa de testes + lint
docker compose exec app bin/rails test && docker compose exec app bin/rubocop

# build: construir a imagem de produção
docker compose build
```

Análise de segurança:

```bash
docker compose exec app bin/brakeman
```

Verificação da fixture de ingestão (roda offline, sem Docker e sem Ruby):

```bash
python3 spec/verify_fixture.py
```

As mesmas verificações rodam no CI (`.github/workflows/ci.yml`) a cada push e
pull request: um job de lint (`rubocop` + `brakeman`) e um job de testes contra
um serviço PostgreSQL 17. O job de testes usa `POSTGRES_TEST_DB` explícito, como
o ambiente local — o banco de teste precisa ser distinto do de desenvolvimento.

`config/brakeman.ignore` registra os avisos dispensados, cada um com
justificativa obrigatória. O CI roda o brakeman com
`--ensure-ignore-notes --ensure-no-obsolete-ignore-entries`, então uma entrada
sem nota ou que deixou de corresponder a um aviso real derruba o build.

## Configuração

`config/database.yml` lê host, usuário, senha e nome do banco do ambiente, com
defaults para `localhost`. É isso que permite os mesmos arquivos servirem dentro
do container (host `db`) e fora dele. As variáveis estão em `.env.example`; os
valores são credenciais locais de desenvolvimento.

`Dockerfile.dev` é a imagem de desenvolvimento — monta o código como volume e
roda em modo development. `Dockerfile` é o de produção, gerado pelo Rails. São
separados de propósito.

### Se o build falhar com `docker-credential-desktop.exe`

Acontece quando `~/.docker/config.json` tem `"credsStore": "desktop.exe"` mas o
helper do Docker Desktop não está no `PATH` — típico de WSL sem o Docker Desktop
integrado. Contorne com um config vazio, sem mexer no global:

```bash
mkdir -p /tmp/dockercfg && echo '{}' > /tmp/dockercfg/config.json
DOCKER_CONFIG=/tmp/dockercfg docker compose up
```

## Documentação

- `.context/` — requisitos, design e plano de tasks (fonte de verdade)
- `.specs/` — recorte por feature, log de decisões (`STATE.md`) e verificações
- `docs/adr/` — decisões arquiteturais em formato longo
- `docs/pesquisa/` — notas de investigação das fontes de dados
