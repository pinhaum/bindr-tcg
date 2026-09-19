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
cp .env.example .env
docker compose up
```

A aplicação fica em <http://localhost:3000>. A primeira subida constrói a imagem
e cria o banco; as seguintes só aplicam migrações pendentes, porque o container
roda `db:prepare`, que é idempotente.

Para parar: `docker compose down`. Para descartar também o banco:
`docker compose down -v`.

## Testes e verificações

```bash
docker compose exec app bin/rails test    # suíte completa
docker compose exec app bin/rubocop       # rubocop-rails-omakase
docker compose exec app bin/brakeman      # análise de segurança
```

A verificação da fixture de ingestão roda offline, sem Docker e sem Ruby:

```bash
python3 spec/verify_fixture.py
```

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
