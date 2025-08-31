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
      
      # Get the arguments from the action
      attribute = Ash.Changeset.get_argument(changeset, :attribute)
      locale = Ash.Changeset.get_argument(changeset, :locale)
      value = Ash.Changeset.get_argument(changeset, :value)
      
      if attribute && locale do
        case backend do
          :database ->
            update_database_translation(changeset, attribute, locale, value)
          
          :redis ->
            update_redis_translation(changeset, attribute, locale, value)
          
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

  defp update_redis_translation(changeset, attribute, locale, value) do
    # For Redis, we would update the cache and mark for Redis sync
    cache_field = :"#{attribute}_cache"
    
    # Get current cache
    current_cache = 
      Ash.Changeset.get_attribute(changeset, cache_field) || %{}
    
    # Update the cache
    updated_cache = 
      if is_nil(value) do
        Map.delete(current_cache, locale)
      else
        Map.put(current_cache, locale, value)
      end
    
    changeset
    |> Ash.Changeset.force_change_attribute(cache_field, updated_cache)
    |> Ash.Changeset.after_action(fn _changeset, record ->
      # Here you would sync to Redis
      # In production, this would use Redix or similar
      sync_to_redis(record, attribute, locale, value)
      {:ok, record}
    end)
  end

  defp sync_to_redis(_record, _attribute, _locale, _value) do
    # Placeholder for Redis sync
    # In production:
    # redis_key_field = :"#{attribute}_redis_key"
    # redis_key = Map.get(record, redis_key_field)
    # full_key = "#{redis_key}:#{locale}"
    # Redix.command(:redis, ["SET", full_key, value])
    :ok
  end
end