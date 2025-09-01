defmodule AshPhoenixTranslations.Fallback do
  @moduledoc """
  Handles fallback logic for missing translations.

  Provides a fallback chain:
  1. Requested locale
  2. Fallback locale (if configured)
  3. Default locale (usually :en)
  4. First available translation
  5. Field name as last resort
  """

  @default_locale :en

  @doc """
  Gets a translation with fallback support.

  ## Options

    * `:locale` - The requested locale
    * `:fallback` - The fallback locale
    * `:default` - Default value if no translation found
    * `:raise_on_missing` - Raise error if translation missing (default: false)
  """
  def get_translation(translations, locale, opts \\ []) when is_map(translations) do
    locale = normalize_locale(locale)
    fallback = Keyword.get(opts, :fallback, @default_locale)
    default = Keyword.get(opts, :default)
    raise_on_missing = Keyword.get(opts, :raise_on_missing, false)

    # Build fallback chain
    fallback_chain = build_fallback_chain(locale, fallback, Map.keys(translations))

    # Try each locale in the chain
    result =
      Enum.find_value(fallback_chain, fn loc ->
        case Map.get(translations, loc) do
          nil -> nil
          # Treat empty strings as missing
          "" -> nil
          value -> value
        end
      end)

    cond do
      result ->
        result

      raise_on_missing ->
        raise AshPhoenixTranslations.MissingTranslationError,
          locale: locale,
          available: Map.keys(translations)

      default ->
        default

      true ->
        # Last resort: return first available or nil
        translations
        |> Map.values()
        |> Enum.find(&(&1 && &1 != ""))
    end
  end

  @doc """
  Builds a fallback chain for locale resolution.

  ## Examples

      iex> build_fallback_chain(:fr_CA, :fr, [:en, :fr, :fr_CA, :es])
      [:fr_CA, :fr, :en]
      
      iex> build_fallback_chain(:de, :en, [:en, :es])
      [:de, :en, :es]
  """
  def build_fallback_chain(locale, fallback, available_locales) do
    locale = normalize_locale(locale)
    fallback = normalize_locale(fallback)
    available = Enum.map(available_locales, &normalize_locale/1)

    chain = [locale]

    # Add language variant if locale is specific (e.g., fr_CA -> fr)
    chain =
      case locale do
        loc when is_atom(loc) ->
          case Atom.to_string(loc) do
            <<lang::binary-size(2), "_", _rest::binary>> ->
              safe_lang =
                try do
                  String.to_existing_atom(lang)
                rescue
                  ArgumentError -> nil
                end

              if safe_lang, do: chain ++ [safe_lang], else: chain

            _ ->
              chain
          end

        _ ->
          chain
      end

    # Add configured fallback
    chain =
      if fallback && fallback not in chain do
        chain ++ [fallback]
      else
        chain
      end

    # Add default locale if not already in chain
    chain =
      if @default_locale not in chain do
        chain ++ [@default_locale]
      else
        chain
      end

    # Add any remaining available locales
    remaining = available -- chain
    chain ++ remaining
  end

  @doc """
  Validates that required translations are present.

  Returns `:ok` or `{:error, missing_locales}`.
  """
  def validate_required(translations, required_locales) when is_map(translations) do
    required = Enum.map(required_locales, &normalize_locale/1)

    missing =
      Enum.filter(required, fn locale ->
        case Map.get(translations, locale) do
          nil -> true
          "" -> true
          _ -> false
        end
      end)

    if Enum.empty?(missing) do
      :ok
    else
      {:error, missing}
    end
  end

  @doc """
  Checks translation completeness for a resource.

  Returns a report with:
  - Total fields
  - Complete translations
  - Missing translations
  - Coverage percentage
  """
  def completeness_report(resource, locale) do
    translatable_attrs = AshPhoenixTranslations.Info.translatable_attributes(resource)
    locale = normalize_locale(locale)

    report =
      Enum.reduce(translatable_attrs, %{complete: 0, missing: [], total: 0}, fn _attr, acc ->
        # This would need actual data loading in practice
        # For now, just return the structure
        %{
          total: acc.total + 1,
          complete: acc.complete,
          missing: acc.missing
        }
      end)

    %{
      locale: locale,
      total_fields: report.total,
      complete: report.complete,
      missing: report.missing,
      coverage: if(report.total > 0, do: report.complete / report.total * 100, else: 0)
    }
  end

  @doc """
  Merges translations with priority to the first map.

  Useful for combining user translations with defaults.
  """
  def merge_translations(primary, secondary) when is_map(primary) and is_map(secondary) do
    Map.merge(secondary, primary, fn _key, v1, v2 ->
      if v1 && v1 != "", do: v1, else: v2
    end)
  end

  def merge_translations(primary, _secondary), do: primary

  # Private functions

  defp normalize_locale(locale) when is_binary(locale) do
    try do
      String.to_existing_atom(locale)
    rescue
      ArgumentError -> @default_locale
    end
  end

  defp normalize_locale(locale) when is_atom(locale), do: locale
  defp normalize_locale(_), do: @default_locale
end
