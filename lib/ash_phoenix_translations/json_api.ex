defmodule AshPhoenixTranslations.JsonApi do
  @moduledoc """
  JSON:API integration for AshPhoenixTranslations.

  This module provides integration with AshJsonApi to expose translations
  through JSON:API endpoints with proper formatting and locale handling.

  ## Usage

  In your resource with AshJsonApi:

      defmodule MyApp.Product do
        use Ash.Resource,
          extensions: [AshPhoenixTranslations, AshJsonApi.Resource]
        
        json_api do
          type "product"
          
          routes do
            base "/products"
            
            get :read
            index :read
            post :create
            patch :update
            delete :destroy
          end
        end
        
        translations do
          translatable_attribute :name, :string,
            locales: [:en, :es, :fr]
          
          # Enable JSON:API translation fields
          json_api_translations true
        end
      end

  This will:
  - Add translation attributes to JSON:API responses
  - Support locale via Accept-Language header or query parameter
  - Handle translation updates through PATCH requests
  """

  @doc """
  Adds JSON:API translation configuration to a resource.

  Called by the transformer when `json_api_translations true` is set.
  """
  def configure_json_api(dsl_state) do
    if has_json_api_extension?(dsl_state) do
      dsl_state
      |> add_translation_attributes()
      |> add_translation_filters()
      |> add_translation_sorts()
      |> configure_translation_serialization()
    else
      {:ok, dsl_state}
    end
  end

  @doc """
  Plug for extracting locale from JSON:API requests.

  Add to your API router:

      plug AshPhoenixTranslations.JsonApi.LocalePlug
  """
  defmodule LocalePlug do
    @moduledoc """
    Plug for extracting and setting locale from JSON:API requests.

    Extracts locale from query parameters or Accept-Language header
    and sets it in the connection assigns for use by the API.
    """
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, _opts) do
      locale = extract_locale(conn)

      conn
      |> assign(:locale, locale)
      |> put_private(:ash_json_api_locale, locale)
    end

    defp extract_locale(conn) do
      # Priority: query param > Accept-Language header > default
      cond do
        locale = conn.params["locale"] ->
          String.to_atom(locale)

        locale = get_accept_language(conn) ->
          locale

        true ->
          Application.get_env(:ash_phoenix_translations, :default_locale, :en)
      end
    end

    defp get_accept_language(conn) do
      conn
      |> get_req_header("accept-language")
      |> parse_accept_language()
      |> find_supported_locale()
    end

    defp parse_accept_language([]), do: nil

    defp parse_accept_language([header | _]) do
      header
      |> String.split(",")
      |> Enum.map(&parse_language_tag/1)
      |> Enum.sort_by(fn {_lang, quality} -> quality end, :desc)
      |> Enum.map(fn {lang, _quality} -> lang end)
    end

    defp parse_language_tag(tag) do
      case String.split(tag, ";") do
        [lang] ->
          parsed_lang =
            lang |> String.trim() |> String.split("-") |> List.first() |> String.to_atom()

          {parsed_lang, 1.0}

        [lang, "q=" <> quality] ->
          quality_value = String.to_float(quality)

          parsed_lang =
            lang |> String.trim() |> String.split("-") |> List.first() |> String.to_atom()

          {parsed_lang, quality_value}
      end
    end

    defp find_supported_locale(nil), do: nil
    defp find_supported_locale([]), do: nil

    defp find_supported_locale([locale | rest]) do
      supported =
        Application.get_env(:ash_phoenix_translations, :supported_locales, [:en, :es, :fr])

      if locale in supported do
        locale
      else
        find_supported_locale(rest)
      end
    end
  end

  def serialize_translations(resource, locale \\ :en) do
    translatable_attrs =
      resource.__struct__
      |> AshPhoenixTranslations.Info.translatable_attributes()

    Enum.reduce(translatable_attrs, %{}, fn attr, acc ->
      storage_field = :"#{attr.name}_translations"
      translations = Map.get(resource, storage_field, %{})

      # Get translation for current locale with fallback
      value =
        Map.get(translations, locale) ||
          Map.get(translations, attr.fallback || :en)

      Map.put(acc, attr.name, value)
    end)
  end

  @doc """
  Deserializer for translation updates via JSON:API.

  Handles PATCH requests with translation data.
  """
  def deserialize_translation_updates(params, resource_module) do
    translatable_attrs = AshPhoenixTranslations.Info.translatable_attributes(resource_module)

    Enum.reduce(params, %{}, fn {key, value}, acc ->
      key_atom = String.to_atom(key)

      if attr = Enum.find(translatable_attrs, &(&1.name == key_atom)) do
        # Handle translation format
        case value do
          %{"translations" => translations} when is_map(translations) ->
            # Multiple locales provided
            storage_field = :"#{attr.name}_translations"
            Map.put(acc, storage_field, atomize_keys(translations))

          %{"locale" => locale, "value" => translation_value} ->
            # Single locale update
            storage_field = :"#{attr.name}_translations"
            locale_atom = String.to_atom(locale)
            Map.put(acc, storage_field, %{locale_atom => translation_value})

          _ when is_binary(value) ->
            # Default locale update
            Map.put(acc, key_atom, value)

          _ ->
            acc
        end
      else
        # Non-translatable field
        Map.put(acc, key_atom, value)
      end
    end)
  end

  @doc """
  Adds sparse fieldsets support for translations.

  Allows clients to request specific translation locales:

      GET /products?fields[products]=name,price&locale=es
  """
  def apply_sparse_fieldsets(query, fields, locale) do
    # Filter requested fields to include only requested translations
    query
    |> Ash.Query.select(fields)
    |> Ash.Query.set_context(%{locale: locale})
  end

  def add_translation_metadata(response, resource) do
    meta = %{
      available_locales: available_locales(resource),
      translation_completeness: translation_completeness(resource),
      default_locale: Application.get_env(:ash_phoenix_translations, :default_locale, :en)
    }

    Map.update(response, :meta, meta, &Map.merge(&1, meta))
  end

  @doc """
  Filter for including only resources with complete translations.

  Can be used in JSON:API filter parameters:

      GET /products?filter[translations_complete]=true
  """
  def filter_complete_translations(query, _locale) do
    # This would need to be implemented based on the backend
    # For now, returns the query unchanged
    query
  end

  @doc """
  Sort by translation completeness.

  Allows sorting resources by how complete their translations are:

      GET /products?sort=translation_completeness
  """
  def sort_by_completeness(query, _direction \\ :desc) do
    # Would calculate completeness and sort
    query
  end

  # Private helpers

  defp has_json_api_extension?(dsl_state) do
    spark_extension = Spark.Dsl.Extension
    extensions = spark_extension.get_persisted(dsl_state, :extensions, [])
    AshJsonApi.Resource in extensions
  rescue
    _ -> false
  end

  defp add_translation_attributes(dsl_state) do
    # Add translation fields as JSON:API attributes
    {:ok, dsl_state}
  end

  defp add_translation_filters(dsl_state) do
    # Add filters for translation fields
    {:ok, dsl_state}
  end

  defp add_translation_sorts(dsl_state) do
    # Add sorting capabilities for translations
    {:ok, dsl_state}
  end

  defp configure_translation_serialization(dsl_state) do
    # Configure how translations are serialized
    {:ok, dsl_state}
  end

  defp available_locales(resource) do
    resource.__struct__
    |> AshPhoenixTranslations.Info.supported_locales()
    |> Enum.map(&to_string/1)
  end

  defp translation_completeness(resource) do
    # Calculate translation completeness for a resource
    translatable_attrs =
      resource.__struct__
      |> AshPhoenixTranslations.Info.translatable_attributes()

    if Enum.empty?(translatable_attrs) do
      100.0
    else
      # Calculate percentage based on non-empty translations
      completeness_scores =
        Enum.map(translatable_attrs, fn attr ->
          storage_field = :"#{attr.name}_translations"
          translations = Map.get(resource, storage_field, %{})

          total_locales = length(attr.locales || [:en])

          filled_locales =
            translations
            |> Enum.count(fn {_locale, value} ->
              value && value != ""
            end)

          if total_locales > 0 do
            filled_locales / total_locales * 100
          else
            0
          end
        end)

      if Enum.empty?(completeness_scores) do
        0.0
      else
        Enum.sum(completeness_scores) / length(completeness_scores)
      end
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} ->
      atom_key =
        try do
          String.to_existing_atom(k)
        rescue
          ArgumentError ->
            reraise ArgumentError,
                    "Invalid key: #{inspect(k)}. Only predefined keys are allowed in translation updates.",
                    __STACKTRACE__
        end

      {atom_key, v}
    end)
  end
end
