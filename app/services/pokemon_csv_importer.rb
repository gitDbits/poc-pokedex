# frozen_string_literal: true

require "csv"

class PokemonCsvImporter
  BATCH_SIZE = 100
  IMPORT_BUFFER_SIZE = 2_000

  REQUIRED_HEADERS = [
    "#",
    "Name",
    "Type 1",
    "Total",
    "HP",
    "Attack",
    "Defense",
    "Sp. Atk",
    "Sp. Def",
    "Speed",
    "Generation",
    "Legendary"
  ].freeze

  COLUMNS = %i[
    pokedex_number
    name
    type_1
    type_2
    total
    hp
    attack
    defense
    sp_atk
    sp_def
    speed
    generation
    legendary
    created_at
    updated_at
  ].freeze

  def initialize(file_path:, progress_callback: nil)
    @file_path = file_path
    @progress_callback = progress_callback
  end

  def call
    ApplicationRecord.connected_to(role: :writing) do
      Pokemon.transaction do
        Pokemon.delete_all
        import_all_rows
      end
    end
  ensure
    File.delete(@file_path) if @file_path && File.exist?(@file_path)
  end

  private

  def import_all_rows
    processed = 0
    imported = 0
    skipped = 0
    buffer = []
    now = Time.current
    headers_checked = false

    CSV.foreach(@file_path, headers: true, encoding: "bom|utf-8").with_index(2) do |row, line_number|
      unless headers_checked
        validate_headers!(row.headers)
        headers_checked = true
      end

      processed += 1
      values = build_values(row, now, line_number: line_number)

      unless values
        skipped += 1
        next
      end

      buffer << values

      if buffer.size >= IMPORT_BUFFER_SIZE
        imported += import_buffer(
          buffer,
          imported_so_far: imported,
          processed_so_far: processed,
          skipped_so_far: skipped
        )
        buffer.clear
      end
    end

    imported += import_buffer(
      buffer,
      imported_so_far: imported,
      processed_so_far: processed,
      skipped_so_far: skipped
    ) if buffer.any?
    { processed: processed, imported: imported, skipped: skipped }
  end

  def validate_headers!(headers)
    missing = REQUIRED_HEADERS - headers
    return if missing.empty?

    raise ArgumentError, "CSV invalido. Colunas ausentes: #{missing.join(', ')}"
  end

  def build_values(row, now, line_number:)
    [
      to_integer(row["#"]),
      row["Name"]&.strip,
      row["Type 1"]&.strip,
      row["Type 2"]&.strip.presence,
      to_integer(row["Total"]),
      to_integer(row["HP"]),
      to_integer(row["Attack"]),
      to_integer(row["Defense"]),
      to_integer(row["Sp. Atk"]),
      to_integer(row["Sp. Def"]),
      to_integer(row["Speed"]),
      to_integer(row["Generation"]),
      to_boolean(row["Legendary"]),
      now,
      now
    ]
  rescue ArgumentError => error
    Rails.logger.warn("PokemonCsvImporter row_skipped line=#{line_number} error=\"#{error.message}\"")
    nil
  end

  def import_buffer(buffer, imported_so_far:, processed_so_far:, skipped_so_far:)
    Pokemon.import(
      COLUMNS,
      buffer,
      validate: false,
      batch_size: BATCH_SIZE,
      batch_progress: lambda { |rows_size, num_batches, current_batch_number, batch_duration_in_secs|
        log_batch_progress(
          rows_size: rows_size,
          num_batches: num_batches,
          current_batch_number: current_batch_number,
          batch_duration_in_secs: batch_duration_in_secs,
          imported_so_far: imported_so_far,
          processed_so_far: processed_so_far,
          skipped_so_far: skipped_so_far
        )
      }
    )

    buffer.size
  end

  def log_batch_progress(rows_size:, num_batches:, current_batch_number:, batch_duration_in_secs:, imported_so_far:, processed_so_far:, skipped_so_far:)
    imported_in_current_call = [ current_batch_number * BATCH_SIZE, rows_size ].min
    total_imported = imported_so_far + imported_in_current_call
    total_expected = imported_so_far + rows_size
    progress = processed_so_far.zero? ? 0 : ((total_imported.to_f / processed_so_far) * 100).round

    Rails.logger.info(
      "PokemonCsvImporter progress batch=#{current_batch_number}/#{num_batches} " \
      "imported=#{total_imported}/#{total_expected} duration=#{format('%.3f', batch_duration_in_secs)}s"
    )

    @progress_callback&.call(
      processed: processed_so_far,
      imported: total_imported,
      skipped: skipped_so_far,
      progress: [ progress, 100 ].min
    )
  end

  def to_integer(value)
    Integer(value.to_s.strip)
  rescue ArgumentError
    raise ArgumentError, "valor inteiro invalido: #{value.inspect}"
  end

  def to_boolean(value)
    %w[true t 1 yes y].include?(value.to_s.strip.downcase)
  end
end
