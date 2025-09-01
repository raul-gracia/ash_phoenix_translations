defmodule AshPhoenixTranslations.Changes.ValidateRequiredTranslations do
  @moduledoc """
  Change that validates required translations are present.
  
  Ensures that translations for required locales are provided
  for translatable attributes.
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
      attribute_name = Keyword.fetch!(opts, :attribute_name)
      required_locales = Keyword.fetch!(opts, :required_locales)
      backend = Keyword.fetch!(opts, :backend)
      
      if Enum.any?(required_locales) do
        case backend do
          :database ->
            validate_database_translations(changeset, attribute_name, required_locales)
          
          :gettext ->
            # For Gettext, we assume translations exist in PO files
            # Validation would happen at compile time
            changeset
        end
      else
        changeset
      end
    end
  end

  defp validate_database_translations(changeset, attribute_name, required_locales) do
    storage_field = :"#{attribute_name}_translations"
    
    # Get the translations from the changeset or existing data
    translations = 
      case Ash.Changeset.fetch_change(changeset, storage_field) do
        {:ok, value} -> value
        :error -> 
          # If not changed, get from data
          Map.get(changeset.data, storage_field, %{})
      end
    
    # Check each required locale
    missing_locales = 
      Enum.filter(required_locales, fn locale ->
        translation = Map.get(translations || %{}, locale)
        is_nil(translation) || translation == ""
      end)
    
    if Enum.any?(missing_locales) do
      Ash.Changeset.add_error(
        changeset,
        field: attribute_name,
        message: "Missing required translations for locales: #{inspect(missing_locales)}",
        vars: [
          attribute: attribute_name,
          missing_locales: missing_locales
        ]
      )
    else
      changeset
    end
  end

end