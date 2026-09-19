# Documentação da API TCG para o Projeto Bindr-TCG

## Visão Geral

A API TCG (https://apitcg.com) é um serviço que fornece dados de cartas e produtos para diversos jogos de cartas colecionáveis (TCG), incluindo o One Piece Card Game (OPTCG). Este documento explica como integrar esta API ao projeto Bindr-TCG para obter informações de cartas, sets e outros dados necessários para o funcionamento da aplicação.

> **Importante**: A API TCG é utilizada apenas para popular o catálogo de cartas do Bindr-TCG. A coleção pessoal do usuário é armazenada localmente no banco de dados da aplicação.

## Autenticação

Todas as requisições à API TCG requerem uma chave de API (API Key) no header `x-api-key`.

### Como Obter uma Chave de API
1. Acesse https://apitcg.com/register e crie uma conta gratuita
2. Após o login, vá para a [Developer Platform](https://apitcg.com/platform)
3. Clique em "[API Key](https://apitcg.com/platform/api-key)" para ver sua chave
4. Copie a chave para uso nas requisições

### Uso nas Requisições
```http
x-api-key: SUA_CHAVE_DE_API_AQUI
```

Exemplo com cURL:
```bash
curl 'https://api.apitcg.com/api/products?tcg=one-piece&name=luffy' \
  -H 'x-api-key: SUA_CHAVE_DE_API_AQUI'
```

### Erros de Autenticação
| Código | Significado |
|--------|-------------|
| `401 Unauthorized` | Chave de API ausente ou inválida |
| `429 Too Many Requests` | Limite de requisições excedido |

## Endpoints Relevantes para o Bindr-TCG

### 1. Listar Todos os TCGs Disponíveis
**Endpoint**: `GET /api/tcgs`  
**Propósito**: Confirmar que o One Piece TCG está disponível e obter seu slug (`one-piece`)  
**Resposta**: Lista de objetos TCG contendo `_id` (slug), `name`, `description`, etc.

### 2. Listar Sets de um TCG
**Endpoint**: `GET /api/{tcg}/sets`  
**Parâmetros**:
- `tcg` (path): slug do TCG (ex: `one-piece`)
- `populate` (query, opcional): se definido como `tcg`, inclui o documento completo do TCG

**Propósito**: Obter todos os sets/expansões disponíveis para o One Piece TCG  
**Resposta**: Lista de objetos Set contendo `_id`, `name`, `slug`, `code`, `release_date`, etc.

### 3. Obter Detalhes de um Set Específico
**Endpoint**: `GET /api/{tcg}/sets/{id}`  
**Parâmetros**:
- `tcg` (path): slug do TCG (ex: `one-piece`)
- `id` (path): ID do set (slug composto, ex: `one-piece-pillars-of-strength`)
- `populate` (query, opcional): se definido como `tcg`, inclui o documento completo do TCG

**Propósito**: Obter informações detalhadas sobre um set específico  
**Resposta**: Objeto Set com todos os campos

### 4. Buscar Produtos (Cartas, Produtos Lacrados, Acessórios)
**Endpoint**: `GET /api/products`  
**Este é o endpoint principal utilizado para obter dados de cartas.**

#### Parâmetros de Consulta (Query Parameters)
| Parâmetro | Tipo | Obrigatório? | Descrição |
|-----------|------|--------------|-----------|
| `tcg` | string | Sim | Slug do TCG (ex: `one-piece` para One Piece TCG) |
| `type` | string | Não | Tipo de produto (`card`, `sealed`, `accessory`) |
| `name` | string | Não | Nome do produto (busca parcial; correspondência exata é priorizada) |
| `code` | string | Não | Código da carta (ex: `OP03-070`) - busca em `attributes.Number` |
| `limit` | integer | Não | Número de resultados por página (máx: 100, padrão: 25) |
| `page` | integer | Não | Número da página para paginação |
| `sort` | string | Não | Campo para ordenação (ex: `name`, `power`, `cost`) |
| `order` | string | Não | Direção da ordenação (`asc` ou `desc`) |

#### Filtros Específicos para Cartas (One Piece TCG)
Para buscar apenas cartas do One Piece TCG, use:
```
tcg=one-piece&type=card
```

#### Exemplos de Requisições
- Buscar todas as cartas com "Luffy" no nome:
  ```
  GET /api/products?tcg=one-piece&type=card&name=luffy
  ```
  
- Buscar uma carta específica pelo código:
  ```
  GET /api/products?tcg=one-piece&type=card&code=OP03-070
  ```
  
- Obter cartas do set "Pillars of Strength" (OP03), ordenadas por poder:
  ```
  GET /api/products?tcg=one-piece&type=card&set=one-piece-pillars-of-strength&sort=power&order=desc
  ```
  
- Paginação (resultados 26-50):
  ```
  GET /api/products?tcg=one-piece&type=card&limit=25&page=2
  ```

## Estrutura da Resposta

A API retorna respostas no formato JSON com a seguinte estrutura geral:
```json
{
  "success": true,
  "data": [ /* Array de produtos */ ],
  "total": 123 /* Número total de resultados (sem paginação) */
}
```

### Objeto Produto (Card)
Cada item no array `data` representa um produto. Para cartas do One Piece TCG, os campos mais relevantes são:

#### Campos Fixos
| Campo | Tipo | Descrição |
|-------|------|-----------|
| `_id` | string | Identificador único do produto (também usado como slug/ID) |
| `name` | string | Nome do produto (ex: "Monkey.D.Luffy") |
| `images` | object | Contém URLs para as imagens: <br> - `small`: versão miniatura <br> - `large`: versão em alta resolução |
| `markets` | object | Links para listagens em marketplaces: <br> - `tcgplayer`: { `id`: string, `url`: string } <br> - `tcgmatch`: { `id`: string, `url`: string } |
| `tcg` | object | **Documento completo do TCG** (não apenas referência) <br> Contém: `_id` (`"one-piece"`), `name`, `description`, `markets`, etc. |
| `set` | object ou null | **Documento completo do set** ao qual o produto pertence (se aplicável) <br> Contém: `_id`, `name`, `slug`, `code` (ex: `"OP03"`), `release_date`, `tcg` (referência ao TCG), `markets` |
| `createdAt` | string (date-time) | Timestamp de criação do registro |
| `updatedAt` | string (date-time) | Timestamp da última atualização |

#### Campo `attributes` (Objeto Dinâmico)
Este campo contém os atributos específicos do jogo. Para cartas do One Piece TCG, as chaves mais importantes são:

| Chave | Tipo | Descrição | Exemplo |
|-------|------|-----------|---------|
| `Rarity` | string | Raridade da carta | `"R"`, `"SR"`, `"SEC"`, `"L"`, `"P"` |
| `Number` | string | Número da carta dentro do set | `"OP03-070"` |
| `Color` | string ou array | Cor(es) da carta | `"Purple"` ou `["Red", "Green"]` para multicolor |
| `CardType` | string | Tipo da carta | `"Leader"`, `"Character"`, `"Event"`, `"Stage"` |
| `Power` | string (numérico) | Poder de combate (para Leader/Character) | `"7000"` |
| `Cost` | string (numérico) | Custo em DON!! para jogar a carta (ausente para Leaders) | `"2"` |
| `Life` | string (numérico) | Vida do Leader (apenas para Leaders) | `"4000"` |
| `Counter` | string (numérico) ou null | Valor do counter (ausente ou null se não houver) | `"2000"` ou `null` |
| `Attributes` | array de strings | Ícones de tipo de ataque | `["Slash"]`, `["Strike", "Ranged"]` |
| `Traits` | array de strings | Afiliações/ tribos da carta | `["Straw Hat Crew"]`, `["Worst Generation"]` |
| `EffectText` | string | Texto de efeito da carta (pode conter `<br>` para quebras de linha) | `"[Once Per Turn]..."` |
| `TriggerText` | string | Texto de efeito de trigger (quando revelado da Life) | `"[Trigger]..."` |
| `Artist` | string | Nome do ilustrador (quando disponível) | `"Nekobayashi"` |

> **Observações importantes sobre o campo `attributes`:**
> - As chaves são strings; valores que parecem numéricos (Power, Cost, etc.) são retornados como strings e devem ser convertidos se necessário para operações numéricas.
> - Algumas chaves podem estar ausentes dependendo do tipo de carta (ex: `Life` só está presente para Leaders).
> - O campo `Artist` é opcional - nem todas as cartas têm esta informação publicada.
> - As chaves podem variar ligeiramente entre diferentes impressões da mesma carta (variantes).

## Como a API se Relaciona com o Modelo de Dados do Bindr-TCG

Com base no `design.md` do projeto Bindr-TCG, aqui está como os dados da API TCG se mapeiam para nosso modelo:

### Mapeamento para Entidades

| Campo da API TCG | Entidade Bindr-TCG | Campo Correspondente | Observações |
|------------------|-------------------|----------------------|-------------|
| `_id` (produto) | `card_variants` | `id` ou `external_id` | Usaremos como identificador externo único da variante |
| `name` | `card_variants` | `name` | Nome da variante (ex: "Monkey.D.Luffy") |
| `images.small` / `images.large` | `card_variants` | `image_url` / `image_url_large` | URLs para as imagens da carta |
| `tcg._id` | `sets` → `tcg_id` (via set) | Indiretamente | O TCG é acessado através do set |
| `set._id` | `sets` | `id` | O set ao qual a carta pertence |
| `set.code` | `sets` | `code` | Código do set (ex: "OP03") |
| `set.name` | `sets` | `name` | Nome do set (ex: "Pillars of Strength") |
| `set.release_date` | `sets` | `released_on` | Data de lançamento do set |
| `attributes.Number` | `cards` | `card_number` | Número da carta no jogo (ex: "OP01-001") |
| `attributes.CardType` | `cards` | `card_type` | Tipo da carta (Leader, Character, etc.) |
| `attributes.Color` | `cards` | `colors` | Array de cores (converter string para array se necessário) |
| `attributes.Power` | `cards` | `power` | Poder (converter string para inteiro) |
| `attributes.Cost` | `cards` | `cost` | Custo (converter string para inteiro; null se ausente) |
| `attributes.Life` | `cards` | `life` | Vida (converter string para inteiro; null se ausente) |
| `attributes.Counter` | `cards` | `counter` | Counter (converter string para inteiro; null se ausente) |
| `attributes.Attributes` | `cards` | `attributes` | Array de atributos de ataque |
| `attributes.Traits` | `cards` | `traits` | Array de traços/afiliações |
| `attributes.EffectText` | `cards` | `effect_text` | Texto de efeito |
| `attributes.TriggerText` | `cards` | `trigger_text` | Texto de trigger |
| `attributes.Rarity` | `card_variants` | `rarity` | Raridade da variante específica |
| `attributes.Artist` | `card_variants` | `illustrator` | Nome do ilustrador |

### Observações sobre o Mapeamento
1. **Separação Card × CardVariant**: Como especificado no `design.md` §3.1, mantemos a distinção entre:
   - **Card**: representa a carta do jogo (mesma para todas as variantes) - identificada por `card_number`
   - **CardVariant**: representa uma impressão física específica (arte rara, paralelo, etc.) - identificada pela combinação de `card_id` + `variant_code`

2. **Derivação do `variant_code`**: Como discutido no `design.md` §P5, quando a API não fornece um identificador estável de variante, derivaremos um `variant_code` determinístico baseado em:
   ```
   hash(card_number + rarity + art_kind)
   ```
   onde `art_kind` pode ser determinado pela presença de campos como `Artist` ou comparação com a arte base.

3. **Uso de Documentos Completo**: A vantagem desta API é que os objetos `tcg` e `set` são retornados como documentos completos, eliminando a necessidade de requisições adicionais para obter informações desses recursos.

## Limitações e Considerações Importantes

### 1. Cobertura de Dados
- A API pode não ter 100% de cobertura para todos os campos em todas as cartas (ex: o campo `Artist` pode estar ausente para algumas impressões mais antigas)
- Sempre verifique a existência de um campo antes de utilizá-lo em sua aplicação

### 2. Taxa de Requisições (Rate Limiting)
- A API impõe limites de taxa de requisições para evitar abusos
- Resposta `429 Too Many Requests` indica que o limite foi excedido
- **Recomendação**: Implemente caching agressivo e limite a frequência de requisições em sua aplicação

### 3. Estrutura do Campo `attributes`
- Embora a documentaçãoliste chaves específicas, a estrutura real pode variar ligeiramente entre diferentes TCGs e até entre diferentes impressões do mesmo TCG
- Seu código de normalização deve ser flexível o suficiente para lidar com campos ausentes ou inesperados

### 4. Dados de Preço
- Embora a API mencione "price history" em sua descrição, os endpoints de preço não foram detalhados na documentação acessível
- Se preços forem necessários para a Fase 3 do projeto, pode ser necessário investigar endpoints adicionais ou fontes alternativas

### 5. Disponibilidade do Serviço
- Como qualquer serviço externo, a API TCG pode sofrer indisponibilidade
- Sua implementação deve tratar adequadamente erros de conexão e timeout
- Considere implementar um mecanismo de fallback ou notificação quando o serviço estiver indisponível

## Exemplos de Integração no Código

### Exemplo 1: Busca Básica de Cartas (Pseudocódigo)
```python
def fetch_one_piece_cards(name_filter=None, page=1, limit=25):
    params = {
        "tcg": "one-piece",
        "type": "card",
        "limit": limit,
        "page": page
    }
    
    if name_filter:
        params["name"] = name_filter
    
    response = requests.get(
        "https://api.apitcg.com/api/products",
        headers={"x-api-key": API_KEY},
        params=params
    )
    
    if response.status_code == 200:
        return response.json()
    else:
        # Tratar erros (401, 429, etc.)
        raise Exception(f"API Error: {response.status_code}")
```

### Exemplo 2: Processamento de Resposta para o Modelo Bindr-TCG
```python
def normalize_api_product(api_product):
    """Converte um produto da API TCG para o formato interno do Bindr-TCG"""
    
    # Extrair informações básicas
    external_id = api_product["_id"]
    name = api_product["name"]
    image_url = api_product["images"]["small"]
    image_url_large = api_product["images"]["large"]
    
    # Obter informações do set (já vem como documento completo)
    set_info = api_product.get("set")
    set_external_id = set_info["_id"] if set_info else None
    set_code = set_info["code"] if set_info else None
    set_name = set_info["name"] if set_info else None
    released_on = set_info["release_date"] if set_info else None
    
    # Obter informações do TCG (já vem como documento completo)
    tcg_info = api_product["tcg"]
    tcg_external_id = tcg_info["_id"]  # Deve ser "one-piece"
    
    # Processar atributos específicos do One Piece TCG
    attrs = api_product.get("attributes", {})
    
    # Determinar card_number (do atributo Number)
    card_number = attrs.get("Number")
    
    # Determinar se é Leader, Character, etc.
    card_type_map = {
        "Leader": "leader",
        "Character": "character",
        "Event": "event",
        "Stage": "stage"
    }
    card_type = card_type_map.get(attrs.get("CardType"), attrs.get("CardType", "").lower())
    
    # Processar cores (pode ser string ou array)
    color_raw = attrs.get("Color", "")
    if isinstance(color_raw, str):
        # Se for string simples, converter para array
        colors = [c.strip() for c in color_raw.split(",") if c.strip()] if color_raw else []
    else:
        colors = color_raw if isinstance(color_raw, list) else []
    
    # Converter campos numéricos com tratamento de nullo
    def safe_int(value):
        if value is None or value == "":
            return None
        try:
            return int(value)
        except (ValueError, TypeError):
            return None
    
    power = safe_int(attrs.get("Power"))
    cost = safe_int(attrs.get("Cost"))
    life = safe_int(attrs.get("Life"))
    counter = safe_int(attrs.get("Counter"))
    
    # Outros campos
    rarity = attrs.get("Rarity")
    illustrator = attrs.get("Artist")
    effect_text = attrs.get("EffectText")
    trigger_text = attrs.get("TriggerText")
    attributes_list = attrs.get("Attributes", [])  # Note: plural na API
    traits_list = attrs.get("Traits", [])          # Note: plural na API
    
    # Gerar variant_code estável (exemplo simplificado)
    # Na prática, usar um hash estável como discutido no design.md §P5
    variant_data = f"{card_number}-{rarity or ''}-{'alternate_art' if illustrator else 'base_art'}"
    # variant_code = hash_stable(variant_data)  # Implementar função de hash adequada
    
    return {
        # Informações da variante (card_variants)
        "external_id": external_id,
        "name": name,
        "image_url": image_url,
        "image_url_large": image_url_large,
        "rarity": rarity,
        "illustrator": illustrator,
        "variant_code": variant_code,  # A ser implementado conforme P5
        
        # Informações da carta (cards) - será vinculada via card_id
        "card_number": card_number,
        "card_type": card_type,
        "colors": colors,
        "power": power,
        "cost": cost,
        "life": life,
        "counter": counter,
        "attributes": attributes_list,
        "traits": traits_list,
        "effect_text": effect_text,
        "trigger_text": trigger_text,
        
        # Relacionamentos
        "set_external_id": set_external_id,
        "set_code": set_code,
        "set_name": set_name,
        "released_on": released_on,
        "tcg_external_id": tcg_external_id
    }
```

## Próximos Passos para Integração no Bindr-TCG

1. **Obter uma chave de API** para desenvolvimento e teste
2. **Implementar o serviço de ingestão** que:
   - Faz requisições periódicas à API TCG para atualizar o catálogo
   - Normaliza os dados recebidos para o formato interno do Bindr-TCG
   - Realiza upsert (atualização ou inserção) evitando duplicatas
   - Nunca deleta registros de coleção do usuário (Requisito 1.7)
   - Registra logs detalhados para auditoria e depuração
3. **Implementar caching** para reduzir a carga na API e melhorar performance
4. **Adicionar tratamento de erros** robusto para lidar com:
   - Falhas de autenticação
   - Limites de taxa excedidos (429)
   - Problemas de conectividade
   - Respostas inesperadas ou malformadas
5. **Criar testes automatizados** que:
   - Validam o processo de normalização com dados de exemplo (fixtures)
   - Verificam a idempotência da ingestão (executar duas vezes não deve alterar contadores)
   - Asseguram que dados de coleção do usuário não são afetados pela ingestão

## Referências

- Documentação oficial da API TCG: https://docs.apitcg.com
- OpenAPI JSON: https://docs.apitcg.com/openapi.json
- Exemplos de uso na documentação: ver seção "How to use" e exemplos de código
- Lista de TCGs suportados: ver endpoint `/api/tcgs`

---
*Documentação gerada com base na especificacao da API TCG acessível em setembro de 2026. Para a informação mais atualizada, consulte diretamente https://docs.apitcg.com*