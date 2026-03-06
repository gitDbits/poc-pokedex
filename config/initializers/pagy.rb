# frozen_string_literal: true

if Pagy.respond_to?(:options)
  Pagy.options[:limit] = 100
else
  pagy_defaults = Pagy::DEFAULT.merge(limit: 100).freeze
  Pagy.send(:remove_const, :DEFAULT)
  Pagy.const_set(:DEFAULT, pagy_defaults)
end
