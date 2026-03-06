class PokemonImportsController < ApplicationController
  def new; end

  def create
    csv_file = params.dig(:pokemon_import, :file)

    unless csv_file
      redirect_to pokedex_gea_path, alert: "Selecione um arquivo CSV."
      return
    end

    file_path = persist_uploaded_file(csv_file)
    PokemonCsvImportJob.perform_later(file_path)

    redirect_to pokedex_gea_path, notice: "Arquivo enviado. Importacao em background iniciada."
  end

  private

  def persist_uploaded_file(csv_file)
    uploads_dir = Rails.root.join("tmp", "uploads")
    FileUtils.mkdir_p(uploads_dir)

    file_path = uploads_dir.join("#{SecureRandom.uuid}_#{csv_file.original_filename}")
    IO.copy_stream(csv_file.tempfile, file_path)
    file_path.to_s
  end
end
