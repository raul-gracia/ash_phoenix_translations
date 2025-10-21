[
  # Mix.Task behavior - Mix modules not available in PLT
  ~r/lib\/mix\/tasks.*callback_info_missing/,
  ~r/lib\/mix\/tasks.*Function Mix\./,

  # Defensive catch-all clauses for safety - these are intentional
  ~r/lib\/ash_phoenix_translations\/fallback.ex.*pattern_match_cov/,
  ~r/lib\/ash_phoenix_translations\/graphql.ex.*pattern_match_cov/,
  ~r/lib\/ash_phoenix_translations\/locale_resolver.ex.*pattern_match_cov/,
  ~r/lib\/ash_phoenix_translations\/policy_check.ex.*pattern_match_cov/,

  # Optional dependency availability checks (Phoenix.HTML, HtmlSanitizeEx)
  # These are valid checks for optional dependencies
  ~r/lib\/ash_phoenix_translations\/helpers.ex.*pattern_match/,
  ~r/lib\/ash_phoenix_translations\/input_validator.ex.*pattern_match/,

  # Redis backend files - deferred to future release, not currently implemented
  ~r/lib\/ash_phoenix_translations\/redis_connection.ex/,
  ~r/lib\/ash_phoenix_translations\/redis_storage.ex/,
  ~r/lib\/ash_phoenix_translations\/calculations\/redis_translation.ex/,
  ~r/lib\/mix\/tasks\/ash_phoenix_translations\..*\.redis.ex/
]
