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
  def load(_query, opts, _context) do
    # Tell Ash to load the storage field before running the calculation
    attribute_name = Keyword.fetch!(opts, :attribute_name)
    storage_field = :"#{attribute_name}_translations"
    [storage_field]
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
    # For SQL data layers, we can express this as a JSON extraction
    # This prevents N+1 queries by executing in SQL
    attribute_name = Keyword.fetch!(opts, :attribute_name)
    storage_field = :"#{attribute_name}_translations"
    locale = get_locale(context)

    require Ash.Expr

    # Generate SQL fragment: name_translations->>'en'
    Ash.Expr.expr(fragment("?->>?", field(^storage_field), ^to_string(locale)))
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
