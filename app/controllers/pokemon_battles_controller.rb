# frozen_string_literal: true

class PokemonBattlesController < ApplicationController
  def new
    @pokemons = available_pokemons
    @selected_pokemon_1_id = params[:pokemon_1_id].presence
    @selected_pokemon_2_id = params[:pokemon_2_id].presence

    return if @selected_pokemon_1_id.blank? || @selected_pokemon_2_id.blank?

    @pokemon_1 = @pokemons.find { |pokemon| pokemon.id == @selected_pokemon_1_id.to_i }
    @pokemon_2 = @pokemons.find { |pokemon| pokemon.id == @selected_pokemon_2_id.to_i }
    return if @pokemon_1.nil? || @pokemon_2.nil? || @pokemon_1.id == @pokemon_2.id

    @winner, @loser = decide_winner(@pokemon_1, @pokemon_2)
  end

  def create
    @pokemons = available_pokemons
    pokemon_1 = @pokemons.find { |pokemon| pokemon.id == params[:pokemon_1_id].to_i }
    pokemon_2 = @pokemons.find { |pokemon| pokemon.id == params[:pokemon_2_id].to_i }

    if pokemon_1.nil? || pokemon_2.nil?
      redirect_to new_pokemon_battle_path, alert: "Selecione dois pokemons validos."
      return
    end

    if pokemon_1.id == pokemon_2.id
      redirect_to new_pokemon_battle_path(
        pokemon_1_id: pokemon_1.id,
        pokemon_2_id: pokemon_2.id
      ), alert: "Escolha dois pokemons diferentes para batalhar."
      return
    end

    redirect_to new_pokemon_battle_path(
      pokemon_1_id: pokemon_1.id,
      pokemon_2_id: pokemon_2.id
    )
  end

  private

  def available_pokemons
    ApplicationRecord.connected_to(role: :writing) do
      Pokemon.order(:name, :id).to_a
    end
  end

  def decide_winner(pokemon_a, pokemon_b)
    attributes = %i[total attack defense sp_atk sp_def speed hp]

    attributes.each do |attribute|
      comparison = pokemon_a.public_send(attribute) <=> pokemon_b.public_send(attribute)
      return [ pokemon_a, pokemon_b ] if comparison.positive?
      return [ pokemon_b, pokemon_a ] if comparison.negative?
    end

    [ pokemon_a, pokemon_b ]
  end
end
