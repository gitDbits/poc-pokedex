module ApplicationHelper
  include Pagy::Method

  TYPE_TRANSLATIONS = {
    "Normal" => "Normal",
    "Fire" => "Fogo",
    "Water" => "Agua",
    "Electric" => "Eletrico",
    "Grass" => "Planta",
    "Ice" => "Gelo",
    "Fighting" => "Lutador",
    "Poison" => "Veneno",
    "Ground" => "Terra",
    "Flying" => "Voador",
    "Psychic" => "Psiquico",
    "Bug" => "Inseto",
    "Rock" => "Pedra",
    "Ghost" => "Fantasma",
    "Dragon" => "Dragao",
    "Dark" => "Sombrio",
    "Steel" => "Aco",
    "Fairy" => "Fada"
  }.freeze

  def pokemon_sprite_url(pokemon)
    number = pokemon.pokedex_number.to_i
    return nil if number <= 0

    "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/#{number}.png"
  end

  def pokemon_type_label(type)
    return "-" if type.blank?

    TYPE_TRANSLATIONS.fetch(type.to_s, type.to_s)
  end

  def pokemon_legendary_label(value)
    ActiveModel::Type::Boolean.new.cast(value) ? "Sim" : "Nao"
  end
end
