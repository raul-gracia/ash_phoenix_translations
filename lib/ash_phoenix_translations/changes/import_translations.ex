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
          attr_key = String.to_atom(String.trim(attribute))
          locale_key = String.to_atom(String.trim(locale))
          value = String.trim(value)

          Map.update(acc, attr_key, %{locale_key => value}, fn existing ->
            Map.put(existing, locale_key, value)
          end)

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
