defmodule AshPhoenixTranslations.Calculations.AllTranslations do
  @moduledoc """
  Calculation that returns all translations for an attribute.
  
  Returns a map of locale => translation for all configured locales.
  """

  use Ash.Resource.Calculation

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def calculate(records, opts, _context) do
    attribute_name = Keyword.fetch!(opts, :attribute_name)
    backend = Keyword.fetch!(opts, :backend)
    locales = Keyword.fetch!(opts, :locales)
    
    Enum.map(records, fn record ->
      case backend do
        :database ->
          # For database backend, just return the translations map
          storage_field = :"#{attribute_name}_translations"
          Map.get(record, storage_field, %{})
        
        :gettext ->
          # For Gettext, we need to fetch each locale
          fetch_all_gettext_translations(record, attribute_name, locales)
        
        :redis ->
          # For Redis, fetch from cache or Redis for all locales
          fetch_all_redis_translations(record, attribute_name, locales)
      end
    end)
  end

  @impl true
  def expression(opts, _context) do
    attribute_name = Keyword.fetch!(opts, :attribute_name)
    backend = Keyword.fetch!(opts, :backend)
    
    case backend do
      :database ->
        # For database, we can express this as a simple field reference
        storage_field = :"#{attribute_name}_translations"
        
        require Ash.Expr
        Ash.Expr.expr(^ref(storage_field))
      
      _ ->
        # For other backends, must be loaded at runtime
        :runtime
    end
  end

  defp fetch_all_gettext_translations(record, attribute_name, locales) do
    gettext_module = Application.get_env(:ash_phoenix_translations, :gettext_module)
    
    if gettext_module do
      message_id = build_message_id(record, attribute_name)
      
      # Fetch translation for each locale
      Enum.reduce(locales, %{}, fn locale, acc ->
        translation = 
          Gettext.with_locale(gettext_module, to_string(locale), fn ->
            Gettext.dgettext(gettext_module, "translations", message_id)
          end)
        
        # Only include if translation is different from message_id (i.e., translated)
        if translation != message_id do
          Map.put(acc, locale, translation)
        else
          acc
        end
      end)
    else
      %{}
    end
  end

  defp fetch_all_redis_translations(record, attribute_name, locales) do
    # Check cache first
    cache_field = :"#{attribute_name}_cache"
    cache = Map.get(record, cache_field, %{})
    
    # If cache has all locales, return it
    if Enum.all?(locales, &Map.has_key?(cache, &1)) do
      cache
    else
      # Fetch missing locales from Redis
      redis_key_field = :"#{attribute_name}_redis_key"
      redis_key = Map.get(record, redis_key_field)
      
      if redis_key do
        # Fetch each locale from Redis
        Enum.reduce(locales, cache, fn locale, acc ->
          if Map.has_key?(acc, locale) do
            acc
          else
            translation = fetch_from_redis(redis_key, locale)
            if translation do
              Map.put(acc, locale, translation)
            else
              acc
            end
          end
        end)
      else
        cache
      end
    end
  end

  defp build_message_id(record, attribute_name) do
    resource_name = record.__struct__ |> Module.split() |> List.last() |> Macro.underscore()
    
    if record.id do
      "#{resource_name}.#{attribute_name}.#{record.id}"
    else
      Map.get(record, attribute_name)
    end
  end

  defp fetch_from_redis(redis_key, locale) do
    # Placeholder for Redis integration
    full_key = "#{redis_key}:#{locale}"
    
    case redis_get(full_key) do
      {:ok, value} when not is_nil(value) -> value
      _ -> nil
    end
  end

  defp redis_get(_key) do
    # Placeholder for Redis GET operation
    {:ok, nil}
  end
end