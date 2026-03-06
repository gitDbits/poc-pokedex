# frozen_string_literal: true

class PokemonsController < ApplicationController
  def index
    ApplicationRecord.connected_to(role: :writing) do
      @pagy, @pokemons = pagy(:offset, Pokemon.order(:pokedex_number, :id))
    end
  end

  def show
    @pokemon = ApplicationRecord.connected_to(role: :reading) do
      Pokemon.find(params[:id])
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to pokemons_path, alert: "Pokemon ainda nao encontrado na replica. Pode ser lag de replicacao."
  end

  def destroy_all
    deleted_count = ApplicationRecord.connected_to(role: :writing) do
      count = Pokemon.count
      Pokemon.delete_all
      count
    end

    redirect_to new_pokemon_import_path, notice: "#{deleted_count} pokemons excluidos com sucesso."
  end
end
