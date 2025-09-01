defmodule AshPhoenixTranslations.Changes.UpdateTranslation do
  @moduledoc """
  Change that handles updating a single translation for an attribute.
  
  This change is applied to the update_translation action and handles
  the logic of updating the translation storage based on the backend.
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
      
      # Get the arguments from the action - support both attribute and field names
      attribute = Ash.Changeset.get_argument(changeset, :attribute) || 
                  Ash.Changeset.get_argument(changeset, :field)
      locale = Ash.Changeset.get_argument(changeset, :locale)
      value = Ash.Changeset.get_argument(changeset, :value)
      
      if attribute && locale do
        case backend do
          :database ->
            update_database_translation(changeset, attribute, locale, value)
          
          :gettext ->
            # Gettext updates would typically be done through PO file management
            # This could trigger a background job or notify translators
            changeset
        end
      else
        # If arguments are missing, add an error
        Ash.Changeset.add_error(
          changeset,
          field: :base,
          message: "attribute and locale arguments are required"
        )
      end
    end
  end

  defp update_database_translation(changeset, attribute, locale, value) do
    storage_field = :"#{attribute}_translations"
    
    # Get current translations
    current_translations = 
      Ash.Changeset.get_attribute(changeset, storage_field) || %{}
    
    # Update the specific locale
    updated_translations = 
      if is_nil(value) do
        # Remove translation if value is nil
        Map.delete(current_translations, locale)
      else
        Map.put(current_translations, locale, value)
      end
    
    # Update the changeset
    Ash.Changeset.force_change_attribute(changeset, storage_field, updated_translations)
  end

end