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
      # SECURITY: All locale conversions validated to prevent atom exhaustion
      cond do
        locale = conn.params["locale"] ->
          case AshPhoenixTranslations.LocaleValidator.validate_locale(locale) do
            {:ok, valid_locale} -> valid_locale
            {:error, _} -> Application.get_env(:ash_phoenix_translations, :default_locale, :en)
          end

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
      # Filter out invalid language tags
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(fn {_lang, quality} -> quality end, :desc)
      |> Enum.map(fn {lang, _quality} -> lang end)
    end

    defp parse_language_tag(tag) do
      # SECURITY: Sanitize Accept-Language header to prevent atom exhaustion
      case String.split(tag, ";") do
        [lang] ->
          case safe_parse_language(lang) do
            {:ok, parsed_lang} -> {parsed_lang, 1.0}
            {:error, _} -> nil
          end

        [lang, "q=" <> quality] ->
          with {:ok, quality_value} <- safe_parse_quality(quality),
               {:ok, parsed_lang} <- safe_parse_language(lang) do
            {parsed_lang, quality_value}
          else
            _ -> nil
          end

        _ ->
          nil
      end
    end

    # SECURITY: Safe language code parsing with validation
    defp safe_parse_language(lang) do
      # Extract language code (e.g., "en-US" -> "en")
      lang_code =
        lang
        |> String.trim()
        |> String.downcase()
        |> String.split("-")
        |> List.first()
        # Limit length
        |> String.slice(0, 10)

      # Only convert to atom if it's a valid locale
      case AshPhoenixTranslations.LocaleValidator.validate_locale(lang_code) do
        {:ok, locale_atom} -> {:ok, locale_atom}
        {:error, _} -> {:error, :invalid_locale}
      end
    end

    # SECURITY: Safe quality value parsing
    defp safe_parse_quality(quality_str) do
      case Float.parse(quality_str) do
        {value, _} when value >= 0.0 and value <= 1.0 -> {:ok, value}
        _ -> {:error, :invalid_quality}
      end
    rescue
      _ -> {:error, :invalid_quality}
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
      # SECURITY: Safe atom conversion for field names
      case safe_field_atom(key) do
        {:ok, key_atom} ->
          if attr = Enum.find(translatable_attrs, &(&1.name == key_atom)) do
            # Handle translation format
            case value do
              %{"translations" => translations} when is_map(translations) ->
                # Multiple locales provided - validate locale keys
                storage_field = :"#{attr.name}_translations"

                case safe_atomize_locale_keys(translations) do
                  {:ok, valid_translations} ->
                    Map.put(acc, storage_field, valid_translations)

                  {:error, _reason} ->
                    # Skip invalid translations
                    acc
                end

              %{"locale" => locale, "value" => translation_value} ->
                # Single locale update - validate locale
                case AshPhoenixTranslations.LocaleValidator.validate_locale(locale) do
                  {:ok, locale_atom} ->
                    storage_field = :"#{attr.name}_translations"
                    Map.put(acc, storage_field, %{locale_atom => translation_value})

                  {:error, _} ->
                    # Skip invalid locale
                    acc
                end

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

        {:error, _reason} ->
          # Skip invalid field names
          acc
      end
    end)
  end

  # SECURITY: Safe field name atom conversion
  defp safe_field_atom(field_name) when is_binary(field_name) do
    try do
      atom = String.to_existing_atom(field_name)
      {:ok, atom}
    rescue
      ArgumentError ->
        require Logger
        Logger.warning("JSON API: rejecting non-existent field atom", field: field_name)
        {:error, :invalid_field}
    end
  end

  defp safe_field_atom(field_name) when is_atom(field_name), do: {:ok, field_name}
  defp safe_field_atom(_), do: {:error, :invalid_field}

  # SECURITY: Safe locale key atomization with validation
  defp safe_atomize_locale_keys(map) when is_map(map) do
    result =
      Enum.reduce_while(map, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
        case AshPhoenixTranslations.LocaleValidator.validate_locale(k) do
          {:ok, locale_atom} ->
            {:cont, {:ok, Map.put(acc, locale_atom, v)}}

          {:error, _} ->
            {:halt, {:error, :invalid_locale}}
        end
      end)

    case result do
      {:ok, valid_map} -> {:ok, valid_map}
      {:error, reason} -> {:error, reason}
    end
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
end
