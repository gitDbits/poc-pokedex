namespace :metabase do
  desc "Cria collection/cards/dashboard demo no Metabase"
  task seed_pokedex: :environment do
    env = {
      "METABASE_URL" => ENV.fetch("METABASE_URL", "http://localhost:3002"),
      "METABASE_EMAIL" => ENV.fetch("METABASE_EMAIL", "gea@example.com"),
      "METABASE_PASSWORD" => ENV.fetch("METABASE_PASSWORD", "Gea#1234"),
      "METABASE_DB_NAME" => ENV.fetch("METABASE_DB_NAME", "Pokedex Reader"),
      "METABASE_DB_HOST" => ENV.fetch("METABASE_DB_HOST", "pokedex-postgres-reader"),
      "METABASE_DB_PORT" => ENV.fetch("METABASE_DB_PORT", "5432"),
      "METABASE_DB_DATABASE" => ENV.fetch("METABASE_DB_DATABASE", "pokedex_development"),
      "METABASE_DB_USER" => ENV.fetch("METABASE_DB_USER", "pokedex_reader"),
      "METABASE_DB_PASSWORD" => ENV.fetch("METABASE_DB_PASSWORD", "pokedex_reader"),
      "METABASE_DB_SSL" => ENV.fetch("METABASE_DB_SSL", "false"),
      "METABASE_COLLECTION_NAME" => ENV.fetch("METABASE_COLLECTION_NAME", "Pokedex"),
      "METABASE_DASHBOARD_NAME" => ENV.fetch("METABASE_DASHBOARD_NAME", "Pokedex Analytics")
    }

    script_path = Rails.root.join("script/metabase_seed.rb").to_s
    success = system(env, RbConfig.ruby, script_path)
    abort("Falha ao executar seed do Metabase") unless success
  end
end
