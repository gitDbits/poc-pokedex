#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

class MetabaseSeeder
  def initialize
    @base_url = ENV.fetch("METABASE_URL", "http://localhost:3002")
    @email = ENV.fetch("METABASE_EMAIL")
    @password = ENV.fetch("METABASE_PASSWORD")
    @db_name = ENV.fetch("METABASE_DB_NAME", "Pokedex Reader")
    @db_host = ENV.fetch("METABASE_DB_HOST", "pokedex-postgres-reader")
    @db_port = Integer(ENV.fetch("METABASE_DB_PORT", "5432"))
    @db_database = ENV.fetch("METABASE_DB_DATABASE", "pokedex_development")
    @db_user = ENV.fetch("METABASE_DB_USER", "pokedex_reader")
    @db_password = ENV.fetch("METABASE_DB_PASSWORD", "pokedex_reader")
    @db_ssl = ENV.fetch("METABASE_DB_SSL", "false") == "true"
    @collection_name = ENV.fetch("METABASE_COLLECTION_NAME", "Pokedex")
    @dashboard_name = ENV.fetch("METABASE_DASHBOARD_NAME", "Pokedex Analytics")
  end

  def run!
    session_id = create_session
    db_id = find_or_create_database_id(session_id, @db_name)
    cards_blueprint = build_cards

    collection_id = find_or_create_primary_collection(session_id, cards_blueprint)
    dashboard_id = find_or_create_dashboard(session_id, collection_id, @dashboard_name)
    remove_duplicate_dashboards(session_id, collection_id, @dashboard_name, dashboard_id)

    cards = upsert_cards(session_id, db_id, collection_id, dashboard_id, cards_blueprint)
    position_dashboard_cards(session_id, dashboard_id, cards)
    remove_duplicate_collections(session_id, collection_id)

    puts "Dashboard criado com sucesso:"
    puts "#{@base_url}/dashboard/#{dashboard_id}"
  end

  private

  def build_cards
    [
      {
        name: "Top 10 Pokemons Mais Fortes",
        display: "table",
        size_x: 12,
        size_y: 8,
        row: 0,
        col: 0,
        sql: <<~SQL
          select name, total
          from pokemons
          order by total desc
          limit 10;
        SQL
      },
      {
        name: "Top 10 Pokemons Mais Velozes",
        display: "table",
        size_x: 12,
        size_y: 8,
        row: 0,
        col: 12,
        sql: <<~SQL
          select name, speed
          from pokemons
          order by speed desc
          limit 10;
        SQL
      },
      {
        name: "Top 10 Pokemons com Maiores Ataques",
        display: "table",
        size_x: 12,
        size_y: 8,
        row: 8,
        col: 0,
        sql: <<~SQL
          select name, attack
          from pokemons
          order by attack desc
          limit 10;
        SQL
      },
      {
        name: "Quantidade de Pokemons por Tipo",
        display: "bar",
        size_x: 12,
        size_y: 8,
        row: 8,
        col: 12,
        sql: <<~SQL
          select type_1, count(*) as qtd
          from pokemons
          group by type_1
          order by qtd desc;
        SQL
      }
    ]
  end

  def create_session
    response = request(:post, "/api/session", { username: @email, password: @password })
    response.fetch("id")
  end

  def fetch_database_id(session_id, db_name)
    databases = request(:get, "/api/database/", nil, session_id).fetch("data")
    db = databases.find { |item| item["name"] == db_name }
    raise "Banco '#{db_name}' nao encontrado no Metabase" unless db

    db.fetch("id")
  end

  def find_or_create_database_id(session_id, db_name)
    fetch_database_id(session_id, db_name)
  rescue RuntimeError => e
    raise unless e.message.include?("nao encontrado")

    create_database(session_id, db_name)
  end

  def create_database(session_id, db_name)
    body = {
      engine: "postgres",
      name: db_name,
      details: {
        host: @db_host,
        port: @db_port,
        dbname: @db_database,
        user: @db_user,
        password: @db_password,
        ssl: @db_ssl
      },
      is_full_sync: true,
      is_on_demand: false,
      auto_run_queries: true
    }

    response = request(:post, "/api/database", body, session_id)
    response.fetch("id")
  end

  def create_collection(session_id, name)
    body = {
      name:,
      color: "#509EE3"
    }
    request(:post, "/api/collection/", body, session_id).fetch("id")
  end

  def create_card(session_id, db_id, collection_id, dashboard_id, card)
    body = {
      name: card.fetch(:name),
      collection_id:,
      dashboard_id:,
      type: "question",
      display: card.fetch(:display),
      visualization_settings: {},
      dataset_query: {
        type: "native",
        native: {
          query: card.fetch(:sql)
        },
        database: db_id
      }
    }

    request(:post, "/api/card/", body, session_id).fetch("id")
  end

  def update_card(session_id, card_id, db_id, collection_id, dashboard_id, card)
    body = {
      name: card.fetch(:name),
      collection_id:,
      dashboard_id:,
      type: "question",
      display: card.fetch(:display),
      visualization_settings: {},
      dataset_query: {
        type: "native",
        native: {
          query: card.fetch(:sql)
        },
        database: db_id
      }
    }

    request(:put, "/api/card/#{card_id}", body, session_id).fetch("id")
  end

  def create_dashboard(session_id, collection_id, name)
    body = {
      name:,
      collection_id:
    }

    request(:post, "/api/dashboard/", body, session_id).fetch("id")
  end

  def find_or_create_primary_collection(session_id, cards_blueprint)
    candidates = find_collections_by_name(session_id, @collection_name)
    return create_collection(session_id, @collection_name) if candidates.empty?

    best = candidates.max_by do |collection|
      items = collection_items(session_id, collection.fetch("id"))
      dashboards = items.select { |item| item["model"] == "dashboard" }
      cards = items.select { |item| item["model"] == "card" }

      has_dashboard = dashboards.any? { |item| item["name"] == @dashboard_name } ? 1 : 0
      matched_cards = cards.count { |item| cards_blueprint.any? { |bp| bp[:name] == item["name"] } }
      total_items = items.size
      [has_dashboard, matched_cards, total_items, -collection.fetch("id")]
    end

    best.fetch("id")
  end

  def find_or_create_dashboard(session_id, collection_id, name)
    dashboards = dashboards_by_name_in_collection(session_id, collection_id, name)
    return create_dashboard(session_id, collection_id, name) if dashboards.empty?

    dashboards.first.fetch("id")
  end

  def remove_duplicate_dashboards(session_id, collection_id, name, keep_dashboard_id)
    dashboards = dashboards_by_name_in_collection(session_id, collection_id, name)
    dashboards.each do |dashboard|
      id = dashboard.fetch("id")
      next if id == keep_dashboard_id

      request(:delete, "/api/dashboard/#{id}", nil, session_id)
    end
  end

  def upsert_cards(session_id, db_id, collection_id, dashboard_id, cards_blueprint)
    items = collection_items(session_id, collection_id)
    cards_by_name = items
      .select { |item| item["model"] == "card" }
      .group_by { |item| item["name"] }

    cards_blueprint.map do |card|
      name = card.fetch(:name)
      existing = Array(cards_by_name[name]).sort_by { |item| item.fetch("id") }

      keep = existing.shift
      existing.each { |duplicate| request(:delete, "/api/card/#{duplicate.fetch("id")}", nil, session_id) }

      id = if keep
        update_card(session_id, keep.fetch("id"), db_id, collection_id, dashboard_id, card)
      else
        create_card(session_id, db_id, collection_id, dashboard_id, card)
      end

      card.merge(id:)
    end
  end

  def position_dashboard_cards(session_id, dashboard_id, cards)
    dashboard = request(:get, "/api/dashboard/#{dashboard_id}", nil, session_id)
    dashcard_id_by_card_id = dashcard_id_map(dashboard)

    cards_payload = cards.map do |card|
      card_id = card.fetch(:id)
      dashcard_id = dashcard_id_by_card_id[card_id]
      raise "Nao foi possivel encontrar dashcard para o card #{card_id}" unless dashcard_id

      {
        id: dashcard_id,
        card_id: card_id,
        size_x: card.fetch(:size_x),
        size_y: card.fetch(:size_y),
        row: card.fetch(:row),
        col: card.fetch(:col),
        parameter_mappings: []
      }
    end

    request(:put, "/api/dashboard/#{dashboard_id}/cards", { cards: cards_payload }, session_id)
  end

  def dashcard_id_map(dashboard)
    Array(dashboard["dashcards"]).each_with_object({}) do |item, acc|
      card_id = item["card_id"] || item.dig("card", "id")
      acc[card_id] = item["id"] if card_id && item["id"]
    end
  end

  def remove_duplicate_collections(session_id, keep_collection_id)
    find_collections_by_name(session_id, @collection_name).each do |collection|
      collection_id = collection.fetch("id")
      next if collection_id == keep_collection_id

      items = collection_items(session_id, collection_id)
      items.select { |item| item["model"] == "dashboard" }.each do |dashboard|
        request(:delete, "/api/dashboard/#{dashboard.fetch("id")}", nil, session_id)
      end
      items.select { |item| item["model"] == "card" }.each do |card|
        request(:delete, "/api/card/#{card.fetch("id")}", nil, session_id)
      end

      request(:delete, "/api/collection/#{collection_id}", nil, session_id)
    end
  end

  def dashboards_by_name_in_collection(session_id, collection_id, name)
    collection_items(session_id, collection_id)
      .select { |item| item["model"] == "dashboard" && item["name"] == name }
      .sort_by { |item| item.fetch("id") }
  end

  def collection_items(session_id, collection_id)
    response = request(:get, "/api/collection/#{collection_id}/items", nil, session_id)
    Array(response["data"])
  end

  def find_collections_by_name(session_id, name)
    tree = request(:get, "/api/collection/tree", nil, session_id)
    flatten_collections(tree).select { |collection| collection["name"] == name && !collection["archived"] }
  end

  def flatten_collections(nodes)
    Array(nodes).flat_map do |node|
      [node] + flatten_collections(node["children"])
    end
  end

  def request(method, path, body = nil, session_id = nil)
    uri = URI.join(@base_url, path)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"

    klass = case method
    when :get then Net::HTTP::Get
    when :post then Net::HTTP::Post
    when :put then Net::HTTP::Put
    when :delete then Net::HTTP::Delete
    else
      raise "Metodo HTTP nao suportado: #{method}"
    end

    req = klass.new(uri)
    req["Content-Type"] = "application/json"
    req["X-Metabase-Session"] = session_id if session_id
    req.body = JSON.generate(body) if body

    res = http.request(req)
    parsed = parse_json(res.body)
    return parsed if res.is_a?(Net::HTTPSuccess)

    raise "Erro API #{res.code} em #{path}: #{parsed || res.body}"
  end

  def parse_json(body)
    JSON.parse(body)
  rescue JSON::ParserError
    nil
  end
end

MetabaseSeeder.new.run!
