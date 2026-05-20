# frozen_string_literal: true

namespace :mixin_bot do
  desc 'Report API_COVERAGE.md missing entries (expects bot-api-go-client checkout)'
  task :api_coverage do
    coverage_path = File.expand_path('../../API_COVERAGE.md', __dir__)
    unless File.exist?(coverage_path)
      warn "Missing #{coverage_path}"
      exit 1
    end

    missing = File.read(coverage_path).scan('| missing |').length
    if missing.positive?
      warn "API_COVERAGE: #{missing} entries still missing"
      exit 1
    end

    puts 'API_COVERAGE: all entries marked done'
  end
end
