# ExCoveralls configuration
# Exclude Redis backend files from coverage since they're deferred to a future release

%{
  coverage_options: %{
    minimum_coverage: 50.0,
    treat_no_relevant_lines_as_covered: true
  },
  skip_files: [
    # Redis backend files (deferred to future release)
    "lib/ash_phoenix_translations/redis_connection.ex",
    "lib/ash_phoenix_translations/redis_storage.ex",
    "lib/ash_phoenix_translations/calculations/redis_translation.ex",
    "lib/mix/tasks/ash_phoenix_translations.import.redis.ex",
    "lib/mix/tasks/ash_phoenix_translations.clear.redis.ex",
    "lib/mix/tasks/ash_phoenix_translations.sync.redis.ex",
    "lib/mix/tasks/ash_phoenix_translations.info.redis.ex",
    "lib/mix/tasks/ash_phoenix_translations.export.redis.ex",

    # Test Redis files
    "test/redis_storage_test.exs",
    "test/redis_connection_test.exs",
    "test/calculations/redis_translation_test.exs",
    "test/mix/redis_mix_tasks_test.exs",

    # Test support files
    "test/support"
  ]
}
