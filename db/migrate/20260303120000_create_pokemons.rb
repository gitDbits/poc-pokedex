# frozen_string_literal: true

class CreatePokemons < ActiveRecord::Migration[8.1]
  def change
    create_table :pokemons do |t|
      t.integer :pokedex_number, null: false
      t.string :name, null: false
      t.string :type_1, null: false
      t.string :type_2
      t.integer :total, null: false
      t.integer :hp, null: false
      t.integer :attack, null: false
      t.integer :defense, null: false
      t.integer :sp_atk, null: false
      t.integer :sp_def, null: false
      t.integer :speed, null: false
      t.integer :generation, null: false
      t.boolean :legendary, null: false, default: false

      t.timestamps
    end

    add_index :pokemons, :pokedex_number
    add_index :pokemons, :name
    add_index :pokemons, :generation
    add_index :pokemons, :legendary
  end
end
