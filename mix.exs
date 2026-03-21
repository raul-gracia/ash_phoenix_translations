defmodule AshPhoenixTranslations.MixProject do
  use Mix.Project

  @version "1.0.0"
  @description "A powerful Ash Framework extension for handling translations in Phoenix applications with policy-aware, multi-backend support"

  def project do
    [
      app: :ash_phoenix_translations,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      package: package(),
      description: @description,
      docs: docs(),
      source_url: "https://github.com/raul-gracia/ash_phoenix_translations",
      homepage_url: "https://github.com/raul-gracia/ash_phoenix_translations",
      test_coverage: [
        tool: ExCoveralls,
        summary: [threshold: 32]
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        ignore_warnings: ".dialyzer_ignore.exs"
      ],
      aliases: aliases(),
      cli: cli()
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:usage_rules, "~> 0.1", only: [:dev]},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      # Core dependencies
      {:ash, "~> 3.0"},
      {:spark, "~> 2.0"},
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 0.20 or ~> 1.0"},
      {:plug, "~> 1.15"},
      {:jason, "~> 1.4"},
      {:phoenix_html, "~> 3.0 or ~> 4.0"},

      # Optional backend dependencies
      {:gettext, "~> 1.0", optional: true},
      {:absinthe, "~> 1.7", optional: true},
      {:dataloader, "~> 2.0", optional: true},

      # Required for import/export functionality
      {:csv, "~> 3.0"},

      # Security dependencies
      {:html_sanitize_ex, "~> 1.4", optional: true},

      # Development and test dependencies
      {:ex_doc, "~> 0.29", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.16", only: :test},
      {:mix_test_watch, "~> 1.1", only: :dev, runtime: false},
      {:ex_machina, "~> 2.7", only: :test},
      {:ash_postgres, "~> 2.0", only: :test}
    ]
  end

  defp package do
    [
      name: "ash_phoenix_translations",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/raul-gracia/ash_phoenix_translations",
        "Changelog" =>
          "https://github.com/raul-gracia/ash_phoenix_translations/blob/main/CHANGELOG.md"
      },
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "LICENSE",
        "guides/getting_started.md",
        "guides/backends.md",
        "guides/phoenix_integration.md",
        "guides/policies.md",
        "guides/import_export.md",
        "guides/liveview.md"
      ],
      groups_for_modules: [
        Core: [
          AshPhoenixTranslations,
          AshPhoenixTranslations.Info
        ],
        DSL: [
          AshPhoenixTranslations.TranslatableAttribute
        ],
        Transformers: ~r/AshPhoenixTranslations.Transformers.*/,
        Calculations: ~r/AshPhoenixTranslations.Calculations.*/,
        Changes: ~r/AshPhoenixTranslations.Changes.*/,
        Preparations: ~r/AshPhoenixTranslations.Preparations.*/,
        "Phoenix Integration": [
          AshPhoenixTranslations.Controller,
          AshPhoenixTranslations.Helpers,
          AshPhoenixTranslations.LiveView
        ],
        Plugs: ~r/AshPhoenixTranslations.Plug.*/,
        "Locale Resolution": ~r/AshPhoenixTranslations.LocaleResolver.*/,
        Cache: ~r/AshPhoenixTranslations.Cache.*/,
        "Mix Tasks": ~r/Mix.Tasks.*/
      ]
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "compile"],
      test: ["test --trace"],
      "test.watch": ["test.watch --trace"],
      quality: ["format", "credo --strict", "sobelow", "dialyzer"],
      "quality.ci": ["format --check-formatted", "credo --strict", "sobelow --exit", "dialyzer"]
    ]
  end
end
