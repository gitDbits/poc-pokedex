# POC Sepog Pokedex

![Tela inicial](docs/screen_home)
![Index de pokemons](docs/index_pokemons)
![Batalha de pokemon](docs/battle_pokemon)
![Dashboard no Metabase](docs/screen_dashboad_metabase)

Análise para a nova estrutura da Gea Sepog:

1. Estruturar o ambiente via Docker Compose com Ruby/Rails, Redis, Sidekiq e Metabase App.
2. Escrita transacional no PostgreSQL Writer.
3. Replicação física para PostgreSQL Reader.
4. Metabase consultando somente a réplica com usuário read-only.

## Arquitetura

Serviços Docker Compose:

- `rails`
- `sidekiq`
- `pokedex-redis`
- `pokedex-postgres-writer` (porta host `5433`)
- `pokedex-postgres-reader` (porta host `5434`)
- `metabase-postgres` (porta host `5435`)
- `metabase` (porta host `3002`, configurável por `METABASE_PORT`)

### Resumo dos serviços e dependências

- `pokedex-postgres-writer`: banco primário (read/write). Sobe com scripts de init que criam usuários e configuração de replicação.
- Scripts executados no startup do Writer (`/docker-entrypoint-initdb.d`, somente no primeiro boot com volume vazio):
- `docker/postgres/writer/init/create-replication-user.sh`: cria o usuário de replicação (`replicator`).
- `docker/postgres/writer/init/configure-replication-hba.sh`: adiciona regra no `pg_hba.conf` para permitir conexão de replicação.
- `docker/postgres/writer/init/create-readonly-user.sql`: cria `pokedex_reader` e concede permissões de leitura.
- `pokedex-postgres-reader`: réplica física read-only do Writer via WAL. Depende de `pokedex-postgres-writer` saudável.
- Script executado no startup do Reader:
- `docker/postgres/reader/bootstrap-replica.sh`: faz `pg_basebackup` do Writer (quando a réplica ainda não existe) e inicia o PostgreSQL em modo réplica.
- `pokedex-redis`: broker/cache usado pelo Sidekiq e app Rails.
- `rails`: aplicação web Rails (porta `3000`). Depende de Writer, Reader e Redis saudáveis.
- Script executado no startup do Rails:
- `bin/docker-entrypoint`: ao subir com `./bin/rails server`, roda `./bin/rails db:prepare` antes de iniciar o servidor.
- `sidekiq`: processamento assíncrono de jobs. Depende de Writer, Reader e Redis saudáveis.
- Observação Sidekiq: usa o mesmo `ENTRYPOINT` (`bin/docker-entrypoint`), mas como o comando é `bundle exec sidekiq`, não dispara `db:prepare`.
- `metabase-postgres`: banco interno do Metabase (metadados/configurações).
- `metabase`: app de BI (porta `3002`). Depende de `metabase-postgres` saudável.

Fluxo de dependências (simplificado):
- `pokedex-postgres-writer` -> `pokedex-postgres-reader`
- `pokedex-redis` + `pokedex-postgres-writer` + `pokedex-postgres-reader` -> `rails` e `sidekiq`
- `metabase-postgres` -> `metabase`

## Pré-requisitos

- [Docker](https://docs.docker.com/get-started/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/)
- Ruby/Bundler local (para rodar tasks Rails locais)

## Passo a Passo Completo (Infra)

### 1. Resetar tudo do zero

```bash
docker compose down -v --remove-orphans
```

### 2. Subir toda a stack

```bash
docker compose up -d --build
```

### 3. Conferir status

```bash
docker compose ps
```

### 4. Acessar serviços

- App Rails: `http://localhost:3000`
- Sidekiq: `http://localhost:3000/sidekiq`
- Metabase: `http://localhost:3002`

## Guia do Metabase (Conexão + Seed)

### 1. Setup inicial do Metabase

- Acesse `http://localhost:3002`
- Finalize o onboarding (criação do usuário admin) com:
- E-mail: `gea@example.com`
- Senha: `Gea#1234`

### 2. Criar conexão com a réplica (Reader)

No Metabase, crie uma nova conexão PostgreSQL com os dados abaixo:

- Display name: `Pokedex Reader`
- Host: `pokedex-postgres-reader`
- Port: `5432`
- Database name: `pokedex_development`
- Username: `pokedex_reader`
- Password: `pokedex_reader`

O que significa cada propriedade:

- Display name: `Pokedex Reader` é só o nome amigável dentro do Metabase (pode ser outro, sem impacto técnico).
- Host: `pokedex-postgres-reader` é o nome do serviço da réplica no `docker-compose.yml`; como o Metabase também está em container, ele enxerga esse host pela rede interna do Compose.
- Port: `5432` é a porta interna padrão do PostgreSQL no container `pokedex-postgres-reader` (no host externo ela é publicada como `5434`, mas entre containers continua `5432`).
- Database name: `pokedex_development` é o banco definido no Compose (`POSTGRES_DB`) para Writer/Reader.
- Username: `pokedex_reader` é o usuário criado no bootstrap do Writer em `docker/postgres/writer/init/create-readonly-user.sql`.
- Password: `pokedex_reader` é a senha definida na criação desse mesmo usuário no script de init.

Por que esse usuário é o ideal para BI:
- O script concede `CONNECT`, `USAGE` no schema `public` e `SELECT` em tabelas/sequences.
- Não concede permissão de escrita (`INSERT/UPDATE/DELETE`), então o Metabase consulta sem risco de alterar dados.

Observação:
- No Metabase em container, use `pokedex-postgres-reader:5432` (rede Docker).
- `localhost:5434` é para acesso direto da máquina host (ex.: pgAdmin), não para a conexão interna do Metabase.

### 3. Executar a seed via rake

Observação: o arquivo CSV de Pokémons está disponível em `lib/csv`.

Com a conexão criada, execute:

```bash
bin/rails metabase:seed_pokedex
```

Ela cria/atualiza:

- Collection `Pokedex`
- Dashboard `Pokedex Analytics`
- Perguntas:
  - Top 10 Pokemons Mais Fortes (`name`, `total`)
  - Top 10 Pokemons Mais Velozes (`name`, `speed`)
  - Top 10 Pokemons com Maiores Ataques (`name`, `attack`)
  - Quantidade de Pokemons por Tipo

Variáveis opcionais para customizar a conexão usada pela task:

- `METABASE_DB_NAME` (default: `Pokedex Reader`)
- `METABASE_DB_HOST` (default: `pokedex-postgres-reader`)
- `METABASE_DB_PORT` (default: `5432`)
- `METABASE_DB_DATABASE` (default: `pokedex_development`)
- `METABASE_DB_USER` (default: `pokedex_reader`)
- `METABASE_DB_PASSWORD` (default: `pokedex_reader`)
- `METABASE_DB_SSL` (default: `false`)

## Acesso via pgAdmin 4 (Writer e Reader)

Com a stack no ar (`docker compose up -d`), no pgAdmin crie 2 conexões em `Register > Server`.

### 1. Servidor Writer (primário)

- Name: `Pokedex Writer`
- Host: `localhost`
- Port: `5433`
- Maintenance DB: `pokedex_development`
- Username: `postgres`
- Password: `postgres`

### 2. Servidor Reader (réplica)

- Name: `Pokedex Reader`
- Host: `localhost`
- Port: `5434`
- Maintenance DB: `pokedex_development`
- Username: `pokedex_reader`
- Password: `pokedex_reader`

### 3. Como confirmar quem é primário e quem é réplica

No Query Tool de cada servidor:

```sql
select pg_is_in_recovery();
```

- `false` = primário (Writer)
- `true` = réplica (Reader)

No Reader:

```sql
show transaction_read_only;
```

Esperado: `on` (somente leitura).

## Validação da Arquitetura Writer/Reader

Roteiro sugerido: executar tudo no Query Tool do pgAdmin, abrindo cada servidor separado (`Pokedex Writer` e `Pokedex Reader`).

### 1. Entender as "bases físicas" (instâncias)

Nesta POC, Writer e Reader sao dois servidores PostgreSQL distintos (duas instâncias com armazenamento separado), conectados por replicação física WAL.

No Writer e no Reader, rode:

```sql
select current_database() as db, pg_is_in_recovery() as em_recovery;
select datname from pg_database order by datname;
select name, setting from pg_settings where name = 'data_directory';
```

Interpretação:
- `pg_is_in_recovery = false` no Writer (primário).
- `pg_is_in_recovery = true` no Reader (réplica).
- `data_directory` deve apontar para diretórios diferentes entre as duas instâncias.

### 2. Separação de usuários e o que cada um pode fazer

No Writer, conectado como `postgres`:

```sql
select
  rolname,
  rolcanlogin,
  rolsuper,
  rolreplication
from pg_roles
where rolname in ('postgres', 'replicator', 'pokedex_reader')
order by rolname;
```

Leitura esperada:
- `postgres`: superusuário, acesso total (admin).
- `replicator`: `rolreplication = true`, usado para streaming da réplica.
- `pokedex_reader`: login de leitura (usado por consultas/BI).

Ainda no Writer, validar permissões do `pokedex_reader`:

```sql
select
  grantee,
  table_schema,
  table_name,
  privilege_type
from information_schema.role_table_grants
where grantee = 'pokedex_reader'
  and table_schema = 'public'
order by table_name, privilege_type;
```

### 3. Teste funcional de escrita no primário e leitura na réplica

No Writer (`postgres`), gravar:

```sql
insert into pokemons (
  pokedex_number, name, type_1, total, hp, attack, defense, sp_atk, sp_def, speed,
  generation, legendary, created_at, updated_at
) values (
  9999, 'Replica Test', 'Normal', 1, 1, 1, 1, 1, 1, 1,
  1, false, now(), now()
);
```

No Reader (`pokedex_reader`), consultar:

```sql
select pokedex_number, name, total
from pokemons
where pokedex_number = 9999;
```

No Reader (`pokedex_reader`), tentar gravar:

```sql
insert into pokemons (
  pokedex_number, name, type_1, total, hp, attack, defense, sp_atk, sp_def, speed,
  generation, legendary, created_at, updated_at
) values (
  10000, 'Nao Deve Gravar', 'Normal', 1, 1, 1, 1, 1, 1, 1,
  1, false, now(), now()
);
```

Esperado: erro de escrita (replica/read-only e sem privilegio de escrita para `pokedex_reader`).

### 4. Status da replicação (saúde e progresso)

No Writer (`postgres`), ver se a réplica está conectada:

```sql
select
  application_name,
  client_addr,
  state,
  sync_state,
  sent_lsn,
  write_lsn,
  flush_lsn,
  replay_lsn,
  pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) as lag_bytes_aprox
from pg_stat_replication;
```

Como ler:
- `state = streaming` indica replicação ativa.
- `lag_bytes_aprox` perto de `0 bytes` indica Reader acompanhando o Writer.

No Reader (`postgres`), ver receptor WAL:

```sql
select
  status,
  receive_start_lsn,
  written_lsn,
  flushed_lsn,
  latest_end_lsn,
  latest_end_time
from pg_stat_wal_receiver;
```

### 5. "Tempo que demorou" (atraso temporal da réplica)

No Reader (`postgres` ou `pokedex_reader`), medir atraso em tempo:

```sql
select
  now() as agora_reader,
  pg_last_xact_replay_timestamp() as ultima_transacao_replicada_em,
  now() - pg_last_xact_replay_timestamp() as atraso_aprox
;
```

Observações:
- Se `atraso_aprox` for pequeno (milissegundos/segundos), replicação está saudável.
- Se vier `NULL`, pode nao ter transação recente para medir (gere uma escrita nova no Writer e consulte de novo).

### 6. Progresso durante carga inicial (base backup)

Quando a réplica está sendo recriada pela primeira vez, no Writer (`postgres`) use:

```sql
select
  pid,
  phase,
  backup_total,
  backup_streamed,
  tablespaces_total,
  tablespaces_streamed
from pg_stat_progress_basebackup;
```

Essa visão mostra o progresso do `pg_basebackup` enquanto a réplica está em bootstrap.
