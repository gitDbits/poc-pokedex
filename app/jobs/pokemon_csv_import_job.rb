# frozen_string_literal: true

class PokemonCsvImportJob < ApplicationJob
  queue_as :pokemon

  def perform(file_path)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    filename = File.basename(file_path.to_s)

    Rails.logger.info(
      "PokemonCsvImportJob started job_id=#{job_id} provider_job_id=#{provider_job_id} " \
      "queue=#{queue_name} file=#{filename}"
    )

    result = PokemonCsvImporter.new(file_path: file_path).call
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

    Rails.logger.info(
      "PokemonCsvImportJob finished job_id=#{job_id} provider_job_id=#{provider_job_id} " \
      "queue=#{queue_name} file=#{filename} processed=#{result[:processed]} " \
      "imported=#{result[:imported]} skipped=#{result[:skipped]} duration=#{format('%.3f', duration)}s"
    )
  rescue StandardError => error
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

    Rails.logger.error(
      "PokemonCsvImportJob failed job_id=#{job_id} provider_job_id=#{provider_job_id} " \
      "queue=#{queue_name} file=#{filename} duration=#{format('%.3f', duration)}s " \
      "error_class=#{error.class} error_message=\"#{error.message}\""
    )

    raise
  end
end
