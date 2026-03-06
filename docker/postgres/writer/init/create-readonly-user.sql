DO
$$
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_catalog.pg_roles WHERE rolname = 'pokedex_reader'
  ) THEN
    CREATE ROLE pokedex_reader WITH LOGIN PASSWORD 'pokedex_reader';
  END IF;
END
$$;

GRANT CONNECT ON DATABASE pokedex_development TO pokedex_reader;
\connect pokedex_development

GRANT USAGE ON SCHEMA public TO pokedex_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO pokedex_reader;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO pokedex_reader;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
GRANT SELECT ON TABLES TO pokedex_reader;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
GRANT SELECT ON SEQUENCES TO pokedex_reader;
