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
          
          :redis ->
            validate_redis_translations(changeset, attribute_name, required_locales)
          
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
        translation = Map.get(translations, locale)
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

  defp validate_redis_translations(changeset, attribute_name, required_locales) do
    cache_field = :"#{attribute_name}_cache"
    
    # Get the cache from the changeset or existing data
    cache = 
      case Ash.Changeset.fetch_change(changeset, cache_field) do
        {:ok, value} -> value
        :error -> 
          # If not changed, get from data
          Map.get(changeset.data, cache_field, %{})
      end
    
    # Check each required locale in cache
    missing_locales = 
      Enum.filter(required_locales, fn locale ->
        translation = Map.get(cache, locale)
        is_nil(translation) || translation == ""
      end)
    
    if Enum.any?(missing_locales) do
      # For Redis, we might want to try fetching from Redis first
      # before failing validation
      changeset
      |> maybe_fetch_from_redis(attribute_name, missing_locales)
      |> validate_after_redis_fetch(attribute_name, missing_locales)
    else
      changeset
    end
  end

  defp maybe_fetch_from_redis(changeset, attribute_name, _missing_locales) do
    # In production, this would fetch missing translations from Redis
    # For now, we'll just add a placeholder
    Ash.Changeset.before_action(changeset, fn changeset ->
      # Fetch from Redis here
      redis_key_field = :"#{attribute_name}_redis_key"
      redis_key = Map.get(changeset.data, redis_key_field)
      
      if redis_key do
        # In production: fetch_translations_from_redis(redis_key, missing_locales)
        # For now, just return the changeset
        changeset
      else
        changeset
      end
    end)
  end

  defp validate_after_redis_fetch(changeset, attribute_name, missing_locales) do
    # After attempting to fetch from Redis, validate again
    # If still missing, add error
    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      cache_field = :"#{attribute_name}_cache"
      cache = Map.get(record, cache_field, %{})
      
      still_missing = 
        Enum.filter(missing_locales, fn locale ->
          translation = Map.get(cache, locale)
          is_nil(translation) || translation == ""
        end)
      
      if Enum.any?(still_missing) do
        {:error, 
         Ash.Error.Changes.Required.exception(
           field: attribute_name,
           message: "Missing required translations for locales: #{inspect(still_missing)}"
         )}
      else
        {:ok, record}
      end
    end)
  end
end