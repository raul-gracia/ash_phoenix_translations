defmodule AshPhoenixTranslations.MixProject do
  use Mix.Project

  @version "1.0.0"
  @description "A powerful Ash Framework extension for handling translations in Phoenix applications with policy-aware, multi-backend support"

  def project do
    [
      app: :ash_phoenix_translations,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      package: package(),
      description: @description,
      docs: docs(),
      source_url: "https://github.com/yourusername/ash_phoenix_translations",
      homepage_url: "https://github.com/yourusername/ash_phoenix_translations",
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ],
      aliases: aliases()
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
      # Core dependencies
      {:ash, "~> 3.0"},
      {:spark, "~> 2.0"},
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 1.0"},
      {:plug, "~> 1.15"},
      
      # Optional backend dependencies
      {:gettext, "~> 0.20", optional: true},
      {:redix, "~> 1.1", optional: true},
      {:jason, "~> 1.4"},
      
      # Development and test dependencies
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.16", only: :test},
      {:mix_test_watch, "~> 1.1", only: :dev, runtime: false},
      {:ex_machina, "~> 2.7", only: :test}
    ]
  end

  defp package do
    [
      name: "ash_phoenix_translations",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/yourusername/ash_phoenix_translations",
        "Changelog" => "https://github.com/yourusername/ash_phoenix_translations/blob/main/CHANGELOG.md"
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
        "guides/getting_started.md",
        "guides/backends.md",
        "guides/phoenix_integration.md",
        "guides/policies.md"
      ],
      groups_for_modules: [
        "Core": [
          AshPhoenixTranslations,
          AshPhoenixTranslations.Info
        ],
        "DSL": [
          AshPhoenixTranslations.TranslatableAttribute
        ],
        "Transformers": ~r/AshPhoenixTranslations.Transformers.*/,
        "Calculations": ~r/AshPhoenixTranslations.Calculations.*/,
        "Changes": ~r/AshPhoenixTranslations.Changes.*/,
        "Preparations": ~r/AshPhoenixTranslations.Preparations.*/,
        "Phoenix Integration": [
          AshPhoenixTranslations.Controller,
          AshPhoenixTranslations.Helpers,
          AshPhoenixTranslations.LiveView
        ],
        "Plugs": ~r/AshPhoenixTranslations.Plug.*/,
        "Locale Resolution": ~r/AshPhoenixTranslations.LocaleResolver.*/,
        "Cache": ~r/AshPhoenixTranslations.Cache.*/,
        "Mix Tasks": ~r/Mix.Tasks.*/
      ]
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "compile"],
      test: ["test --trace"],
      "test.watch": ["test.watch --trace"],
      quality: ["format", "credo --strict", "dialyzer"],
      "quality.ci": ["format --check-formatted", "credo --strict", "dialyzer"]
    ]
  end
end