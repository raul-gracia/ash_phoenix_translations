defmodule AshPhoenixTranslations.Calculations.DatabaseTranslation do
  @moduledoc """
  Calculation for fetching translations from database storage.

  Returns the translation for the current locale, with fallback support.
  """

  use Ash.Resource.Calculation

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def calculate(records, opts, context) do
    attribute_name = Keyword.fetch!(opts, :attribute_name)
    fallback = Keyword.get(opts, :fallback)

    # Get the current locale from context
    locale = get_locale(context)

    # Get translations for each record
    Enum.map(records, fn record ->
      storage_field = :"#{attribute_name}_translations"
      translations = Map.get(record, storage_field, %{})

      # Use the fallback module for robust translation fetching
      AshPhoenixTranslations.Fallback.get_translation(
        translations,
        locale,
        fallback: fallback,
        default: nil
      )
    end)
  end

  @impl true
  def expression(opts, context) do
    attribute_name = Keyword.fetch!(opts, :attribute_name)
    fallback = Keyword.get(opts, :fallback)
    locale = get_locale(context)

    storage_field = :"#{attribute_name}_translations"

    # Build the expression to get the translation
    if fallback do
      # With fallback: translations[locale] || translations[fallback]
      require Ash.Expr

      Ash.Expr.expr(
        fragment(
          "COALESCE((?)::jsonb->>?, (?)::jsonb->>?)",
          ^ref(storage_field),
          ^to_string(locale),
          ^ref(storage_field),
          ^to_string(fallback)
        )
      )
    else
      # Without fallback: translations[locale]
      require Ash.Expr

      Ash.Expr.expr(fragment("(?)::jsonb->>?", ^ref(storage_field), ^to_string(locale)))
    end
  end

  defp get_locale(context) when is_map(context) do
    # Handle different context types
    locale =
      case context do
        %{locale: locale} -> locale
        %{source_context: %{locale: locale}} -> locale
        _ -> nil
      end

    locale ||
      Process.get(:locale) ||
      Application.get_env(:ash_phoenix_translations, :default_locale, :en)
  end
end
