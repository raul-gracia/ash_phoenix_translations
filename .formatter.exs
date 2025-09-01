[
  import_deps: [:ash, :spark, :phoenix, :phoenix_live_view],
  plugins: [Spark.Formatter],
  inputs: [
    "{mix,.formatter}.exs",
    "{config,lib,test}/**/*.{ex,exs}"
  ],
  locals_without_parens: [
    # DSL functions
    translatable_attribute: 2,
    translatable_attribute: 3,
    locales: 1,
    required: 1,
    backend: 1,
    cache_ttl: 1,
    audit_changes: 1,
    gettext_module: 1,
    auto_validate: 1,
    policy: 1
  ]
]
