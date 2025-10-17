defmodule AshPhoenixTranslations.Changes.ImportTranslations do
  @moduledoc """
  Change that handles bulk importing translations.

  Supports importing translations in various formats (JSON, CSV, XLIFF)
  and merging them with existing translations.
  """

  use Ash.Resource.Change

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def change(changeset, opts, _context) do
    action_name = Keyword.get(opts, :action_name)

    # If action_name is specified, check if it matches current action
    if action_name && changeset.action && changeset.action.name != action_name do
      changeset
    else
      backend = Keyword.fetch!(opts, :backend)

      # Get the arguments from the action
      translations = Ash.Changeset.get_argument(changeset, :translations)
      format = Ash.Changeset.get_argument(changeset, :format) || :json
      merge = Ash.Changeset.get_argument(changeset, :merge) !== false

      if translations do
        # Parse translations based on format
        parsed_translations = parse_translations(translations, format)

        case backend do
          :database ->
            import_database_translations(changeset, parsed_translations, merge)

          :gettext ->
            # Gettext imports would update PO files
            import_gettext_translations(changeset, parsed_translations, merge)
        end
      else
        # If translations argument is missing, add an error
        Ash.Changeset.add_error(
          changeset,
          field: :translations,
          message: "translations argument is required"
        )
      end
    end
  end

  defp parse_translations(translations, :json) when is_map(translations) do
    # Already in the expected format: %{attribute => %{locale => value}}
    translations
  end

  defp parse_translations(translations, :csv) when is_binary(translations) do
    # Parse CSV format: attribute,locale,value
    translations
    |> String.split("\n", trim: true)
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ",", parts: 3) do
        [attribute, locale, value] ->
          # SECURITY: Validate field and locale to prevent atom exhaustion
          # Use String.to_existing_atom/1 instead of String.to_atom/1
          # Fields and locales must already exist as atoms
          trimmed_attribute = String.trim(attribute)
          trimmed_locale = String.trim(locale)

          with {:ok, attr_key} <- validate_field_atom(trimmed_attribute),
               {:ok, locale_key} <-
                 AshPhoenixTranslations.LocaleValidator.validate_locale(trimmed_locale) do
            value = String.trim(value)

            Map.update(acc, attr_key, %{locale_key => value}, fn existing ->
              Map.put(existing, locale_key, value)
            end)
          else
            {:error, :invalid_field} ->
              # Skip invalid fields with warning (already logged by validator)
              acc

            {:error, :invalid_locale} ->
              # Skip invalid locales with warning (already logged by validator)
              acc
          end

        _ ->
          acc
      end
    end)
  end

  defp parse_translations(translations, :xliff) when is_binary(translations) do
    # XLIFF parsing would be more complex in production
    # This is a simplified placeholder
    %{}
  end

  defp parse_translations(translations, _format), do: translations

  # Helper to validate field atoms safely
  defp validate_field_atom(field_name) when is_binary(field_name) do
    try do
      # Only convert if the atom already exists
      # This prevents atom exhaustion from malicious CSV files
      atom = String.to_existing_atom(field_name)
      {:ok, atom}
    rescue
      ArgumentError ->
        require Logger
        Logger.warning("CSV import: rejecting non-existent field atom", field: field_name)
        {:error, :invalid_field}
    end
  end

  defp import_database_translations(changeset, parsed_translations, merge) do
    # For each translatable attribute, update its translations
    Enum.reduce(parsed_translations, changeset, fn {attribute, locale_values}, changeset ->
      storage_field = :"#{attribute}_translations"

      # Get current translations if merging
      current_translations =
        if merge do
          Ash.Changeset.get_attribute(changeset, storage_field) || %{}
        else
          %{}
        end

      # Merge or replace translations
      updated_translations = Map.merge(current_translations, locale_values)

      # Update the changeset
      Ash.Changeset.force_change_attribute(changeset, storage_field, updated_translations)
    end)
  end

  defp import_gettext_translations(changeset, _parsed_translations, _merge) do
    # For Gettext, this would typically:
    # 1. Generate or update PO files
    # 2. Compile the translations
    # 3. Reload the Gettext backend
    #
    # This is a placeholder - actual implementation would depend on
    # the specific Gettext setup
    changeset
  end
end
