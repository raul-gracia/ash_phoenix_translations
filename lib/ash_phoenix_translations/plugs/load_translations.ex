defmodule AshPhoenixTranslations.Plugs.LoadTranslations do
  @moduledoc """
  Plug for preloading translations for specific resources.

  This plug can preload translations for resources that will be used
  in the request, improving performance by avoiding N+1 queries.

  ## Usage

  Add to your router pipeline or controller:

      plug AshPhoenixTranslations.Plugs.LoadTranslations,
        resources: [Product, Category],
        preload: [:name, :description]

  Or load based on the controller:

      plug AshPhoenixTranslations.Plugs.LoadTranslations,
        from_controller: true

  ## Options

    * `:resources` - List of resource modules to preload translations for
    
    * `:preload` - List of fields to preload. If not specified, loads all translatable fields
    
    * `:from_controller` - If `true`, determines resources from the controller module
    
    * `:cache` - Whether to cache loaded translations. Default: `true`
    
    * `:cache_ttl` - Cache TTL in seconds. Default: `3600`
  """

  import Plug.Conn

  def init(opts) do
    %{
      resources: Keyword.get(opts, :resources, []),
      preload: Keyword.get(opts, :preload),
      from_controller: Keyword.get(opts, :from_controller, false),
      cache: Keyword.get(opts, :cache, true),
      cache_ttl: Keyword.get(opts, :cache_ttl, 3600)
    }
  end

  def call(conn, config) do
    locale = conn.assigns[:locale] || "en"
    resources = determine_resources(conn, config)

    translations = load_translations(resources, locale, config)

    conn
    |> assign(:preloaded_translations, translations)
    |> assign(:translation_cache_key, build_cache_key(resources, locale))
  end

  # Determine which resources to load translations for
  defp determine_resources(conn, %{from_controller: true}) do
    case conn.private[:phoenix_controller] do
      nil ->
        []

      controller ->
        # Try to infer resource from controller name
        # e.g., MyAppWeb.ProductController -> MyApp.Product
        controller
        |> Module.split()
        |> infer_resource_module()
        |> List.wrap()
        |> Enum.filter(&resource_exists?/1)
    end
  end

  defp determine_resources(_conn, %{resources: resources}) do
    resources
  end

  # Infer resource module from controller module
  defp infer_resource_module(controller_parts) do
    # Remove "Web" and "Controller" parts
    resource_parts =
      controller_parts
      |> Enum.reject(&(&1 == "Web"))
      |> List.update_at(-1, fn name ->
        String.replace(name, "Controller", "")
      end)

    # Try singular and plural forms
    module = Module.concat(resource_parts)

    cond do
      resource_exists?(module) ->
        module

      true ->
        # Try singularizing the last part
        singular_parts = List.update_at(resource_parts, -1, &singularize/1)
        singular_module = Module.concat(singular_parts)

        if resource_exists?(singular_module) do
          singular_module
        else
          nil
        end
    end
  end

  # Check if a module exists and is an Ash resource
  defp resource_exists?(nil), do: false

  defp resource_exists?(module) when is_atom(module) do
    Code.ensure_loaded?(module) &&
      function_exported?(module, :spark_dsl_config, 0)
  end

  # Load translations for resources
  defp load_translations([], _locale, _config), do: %{}

  defp load_translations(resources, locale, config) do
    Enum.reduce(resources, %{}, fn resource, acc ->
      if resource && resource_exists?(resource) do
        translations =
          if config.cache do
            load_with_cache(resource, locale, config)
          else
            load_without_cache(resource, locale, config)
          end

        Map.put(acc, resource, translations)
      else
        acc
      end
    end)
  end

  # Load translations with caching
  defp load_with_cache(resource, locale, config) do
    cache_key = {resource, locale, config.preload}

    case get_from_cache(cache_key) do
      nil ->
        translations = load_without_cache(resource, locale, config)
        put_in_cache(cache_key, translations, config.cache_ttl)
        translations

      cached ->
        cached
    end
  end

  # Load translations without caching
  defp load_without_cache(resource, locale, config) do
    fields = config.preload || get_translatable_fields(resource)

    %{
      resource: resource,
      locale: locale,
      fields:
        Enum.reduce(fields, %{}, fn field, acc ->
          # This is a placeholder - actual implementation would
          # load from the appropriate backend
          Map.put(acc, field, %{
            available_locales: get_available_locales(resource, field),
            current_locale: locale,
            translations: %{}
          })
        end)
    }
  end

  # Get translatable fields for a resource
  defp get_translatable_fields(resource) do
    resource
    |> AshPhoenixTranslations.Info.translatable_attributes()
    |> Enum.map(& &1.name)
  end

  # Get available locales for a field
  defp get_available_locales(resource, field) do
    case AshPhoenixTranslations.Info.translatable_attribute(resource, field) do
      nil -> []
      attr -> attr.locales
    end
  end

  # Build cache key
  defp build_cache_key(resources, locale) do
    resources_hash =
      resources
      |> Enum.map(&to_string/1)
      |> Enum.sort()
      |> Enum.join(",")
      |> then(&:crypto.hash(:md5, &1))
      |> Base.encode16(case: :lower)

    "translations:#{resources_hash}:#{locale}"
  end

  # Cache implementation
  # In production, this would use ETS or another cache backend

  defp get_from_cache(key) do
    case Process.get({:translation_cache, key}) do
      {value, expiry} ->
        if expiry > System.system_time(:second) do
          value
        else
          nil
        end

      _ ->
        nil
    end
  end

  defp put_in_cache(key, value, ttl) do
    expiry = System.system_time(:second) + ttl
    Process.put({:translation_cache, key}, {value, expiry})
    value
  end

  # Simple singularization helper
  defp singularize(name) do
    cond do
      String.ends_with?(name, "ies") ->
        String.replace_trailing(name, "ies", "y")

      String.ends_with?(name, "ses") ->
        String.replace_trailing(name, "ses", "s")

      String.ends_with?(name, "ches") ->
        String.replace_trailing(name, "ches", "ch")

      String.ends_with?(name, "shes") ->
        String.replace_trailing(name, "shes", "sh")

      String.ends_with?(name, "xes") ->
        String.replace_trailing(name, "xes", "x")

      String.ends_with?(name, "zes") ->
        String.replace_trailing(name, "zes", "z")

      String.ends_with?(name, "ves") ->
        String.replace_trailing(name, "ves", "f")

      String.ends_with?(name, "oes") ->
        String.replace_trailing(name, "oes", "o")

      String.ends_with?(name, "s") ->
        String.replace_trailing(name, "s", "")

      true ->
        name
    end
  end
end
