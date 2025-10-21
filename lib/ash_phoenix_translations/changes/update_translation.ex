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
      attribute =
        Ash.Changeset.get_argument(changeset, :attribute) ||
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

          :redis ->
            update_redis_translation(changeset, attribute, locale, value)
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
    # Get the resource and record ID
    resource = changeset.resource
    record_id = get_record_id(changeset)

    # Only proceed if we have a record ID (for updates, not creates)
    if record_id do
      # Store or delete the translation in Redis
      result =
        if is_nil(value) do
          AshPhoenixTranslations.RedisStorage.delete_translation(
            resource,
            record_id,
            attribute,
            locale
          )
        else
          AshPhoenixTranslations.RedisStorage.set_translation(
            resource,
            record_id,
            attribute,
            locale,
            value
          )
        end

      case result do
        :ok ->
          # Add an after_action hook to invalidate cache if enabled
          Ash.Changeset.after_action(changeset, fn _changeset, result ->
            if cache_running?() do
              cache_key = build_cache_key(resource, record_id, attribute, locale)
              AshPhoenixTranslations.Cache.delete(cache_key)
            end

            {:ok, result}
          end)

        {:error, reason} ->
          Ash.Changeset.add_error(
            changeset,
            field: attribute,
            message: "Failed to update Redis translation: #{inspect(reason)}"
          )
      end
    else
      # For new records, we'll handle translation storage in after_action
      Ash.Changeset.after_action(changeset, fn _changeset, result ->
        record_id = get_record_id_from_result(result)

        if record_id && value do
          case AshPhoenixTranslations.RedisStorage.set_translation(
                 resource,
                 record_id,
                 attribute,
                 locale,
                 value
               ) do
            :ok -> {:ok, result}
            {:error, reason} -> {:error, "Failed to store translation: #{inspect(reason)}"}
          end
        else
          {:ok, result}
        end
      end)
    end
  end

  defp get_record_id(changeset) do
    # Try to get record ID from changeset data
    cond do
      changeset.data && Map.get(changeset.data, :id) ->
        to_string(Map.get(changeset.data, :id))

      changeset.data && Map.get(changeset.data, :uuid) ->
        to_string(Map.get(changeset.data, :uuid))

      true ->
        nil
    end
  end

  defp get_record_id_from_result(result) do
    cond do
      Map.get(result, :id) -> to_string(Map.get(result, :id))
      Map.get(result, :uuid) -> to_string(Map.get(result, :uuid))
      true -> nil
    end
  end

  defp build_cache_key(resource, record_id, field, locale) do
    resource_name =
      resource
      |> Atom.to_string()
      |> String.replace("Elixir.", "")

    "translation:#{resource_name}:#{record_id}:#{field}:#{locale}"
  end

  defp cache_running? do
    Process.whereis(AshPhoenixTranslations.Cache) != nil
  end
end
