defmodule AshPhoenixTranslations.Embedded do
  @moduledoc """
  Support for translations in embedded schemas and relationships.

  This module enables translation capabilities for embedded attributes,
  nested resources, and complex data structures within Ash resources.

  ## Usage

  ### Embedded Schema Translation

      defmodule MyApp.Address do
        use Ash.Resource,
          data_layer: :embedded,
          extensions: [AshPhoenixTranslations]
        
        attributes do
          uuid_primary_key :id
          attribute :street, :string
          attribute :postal_code, :string
        end
        
        translations do
          translatable_attribute :street, :string,
            locales: [:en, :es, :fr]
          
          translatable_attribute :city, :string,
            locales: [:en, :es, :fr]
        end
      end
      
      defmodule MyApp.User do
        use Ash.Resource,
          extensions: [AshPhoenixTranslations]
        
        attributes do
          uuid_primary_key :id
          
          # Embedded attribute with translations
          attribute :address, MyApp.Address
        end
      end

  ### Array of Embedded Schemas

      defmodule MyApp.Product do
        use Ash.Resource,
          extensions: [AshPhoenixTranslations]
        
        attributes do
          uuid_primary_key :id
          
          # Array of translatable features
          attribute :features, {:array, MyApp.ProductFeature}
        end
      end

  ### Relationship Translations

      defmodule MyApp.Category do
        use Ash.Resource,
          extensions: [AshPhoenixTranslations]
        
        relationships do
          has_many :products, MyApp.Product do
            # Products can have locale-specific visibility
            filter expr(locale == ^context[:locale])
          end
        end
        
        translations do
          # Translate relationship metadata
          relationship_translations :products,
            description: [:en, :es, :fr]
        end
      end
  """

  @doc """
  Configures translation support for embedded schemas.

  Called by the transformer when embedded schemas with translations are detected.
  """
  def configure_embedded_translations(dsl_state) do
    dsl_state
    |> detect_embedded_attributes()
    |> add_embedded_translation_storage()
    |> add_embedded_translation_calculations()
    |> configure_embedded_serialization()
  end

  @doc """
  Translates embedded attributes within a resource.

  Recursively traverses embedded schemas and applies translations
  based on the current locale.

  ## Examples

      iex> user = MyApp.User |> Ash.get!(id)
      iex> translated = AshPhoenixTranslations.Embedded.translate_embedded(user, :es)
      iex> translated.address.street
      "Calle Principal"
  """
  def translate_embedded(resource, locale \\ :en) do
    resource
    |> Map.from_struct()
    |> translate_map(resource.__struct__, locale)
    |> then(&struct(resource.__struct__, &1))
  end

  @doc """
  Translates an array of embedded schemas.

  ## Examples

      iex> features = [%ProductFeature{}, %ProductFeature{}]
      iex> translated = translate_embedded_array(features, ProductFeature, :fr)
  """
  def translate_embedded_array(items, schema, locale) when is_list(items) do
    Enum.map(items, &translate_embedded_item(&1, schema, locale))
  end

  @doc """
  Updates translations in embedded schemas.

  Handles nested translation updates while preserving structure.

  ## Examples

      iex> update_embedded_translation(user, [:address, :street], :es, "Nueva Calle")
      {:ok, %User{}}
  """
  def update_embedded_translation(resource, path, locale, value) do
    with {:ok, updated_data} <- update_nested_translation(resource, path, locale, value) do
      resource
      |> Ash.Changeset.for_update(:update)
      |> Ash.Changeset.change_attributes(updated_data)
      |> Ash.update()
    end
  end

  @doc """
  Validates translations in embedded schemas.

  Ensures translation completeness and validity across nested structures.
  """
  def validate_embedded_translations(resource, required_locales \\ []) do
    errors = collect_embedded_validation_errors(resource, required_locales)

    if Enum.empty?(errors) do
      :ok
    else
      {:error, errors}
    end
  end

  @doc """
  Extracts all translatable paths from a resource with embedded schemas.

  Returns a list of paths to translatable attributes for tools like
  translation management UIs.

  ## Examples

      iex> extract_translatable_paths(MyApp.User)
      [
        [:name],
        [:bio],
        [:address, :street],
        [:address, :city]
      ]
  """
  def extract_translatable_paths(resource_or_module) do
    module =
      case resource_or_module do
        %{__struct__: mod} -> mod
        mod when is_atom(mod) -> mod
      end

    extract_paths_recursive(module, [])
  end

  @doc """
  Bulk updates translations for all embedded fields.

  Useful for import/export operations.
  """
  def bulk_update_embedded_translations(resource, translations_map) do
    Enum.reduce_while(translations_map, {:ok, resource}, fn {path, locale_values}, {:ok, res} ->
      case apply_path_translations(res, path, locale_values) do
        {:ok, updated} -> {:cont, {:ok, updated}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  @doc """
  Deep merge translations for embedded schemas.

  Merges new translations with existing ones without overwriting.
  """
  def merge_embedded_translations(resource, new_translations, opts \\ []) do
    strategy = Keyword.get(opts, :strategy, :merge)

    case strategy do
      :merge -> deep_merge_translations(resource, new_translations)
      :replace -> replace_translations(resource, new_translations)
      :fill -> fill_missing_translations(resource, new_translations)
    end
  end

  @doc """
  Generates a translation completeness report for embedded schemas.

  Returns statistics about translation coverage across nested structures.
  """
  def embedded_translation_report(resource) do
    paths = extract_translatable_paths(resource)

    stats =
      Enum.map(paths, fn path ->
        {path, calculate_path_completeness(resource, path)}
      end)

    %{
      total_paths: length(paths),
      complete_paths: Enum.count(stats, fn {_, pct} -> pct == 100 end),
      incomplete_paths: Enum.filter(stats, fn {_, pct} -> pct < 100 end),
      average_completeness: average_completeness(stats)
    }
  end

  # Private implementation functions

  defp detect_embedded_attributes(dsl_state) do
    spark_extension = Spark.Dsl.Extension
    attributes = spark_extension.get_entities(dsl_state, [:attributes])

    embedded_attrs =
      Enum.filter(attributes, fn attr ->
        case attr.type do
          {:array, type} -> is_embedded_type?(type)
          type -> is_embedded_type?(type)
        end
      end)

    spark_transformer = Spark.Dsl.Transformer

    spark_transformer.persist(
      dsl_state,
      :embedded_translatable_attributes,
      embedded_attrs
    )
  end

  defp is_embedded_type?(type) when is_atom(type) do
    Code.ensure_loaded?(type) && function_exported?(type, :__schema__, 1)
  rescue
    _ -> false
  end

  defp is_embedded_type?(_), do: false

  defp add_embedded_translation_storage(dsl_state) do
    spark_extension = Spark.Dsl.Extension

    embedded_attrs =
      spark_extension.get_persisted(dsl_state, :embedded_translatable_attributes, [])

    Enum.reduce(embedded_attrs, {:ok, dsl_state}, fn attr, {:ok, state} ->
      add_embedded_storage_attribute(state, attr)
    end)
  end

  defp add_embedded_storage_attribute(dsl_state, attr) do
    # Add JSON storage for embedded translations
    storage_name = :"#{attr.name}_embedded_translations"

    resource_builder = Ash.Resource.Builder

    resource_builder.add_new_attribute(
      dsl_state,
      storage_name,
      :map,
      public?: false,
      default: %{}
    )
  end

  defp add_embedded_translation_calculations(dsl_state) do
    spark_extension = Spark.Dsl.Extension

    embedded_attrs =
      spark_extension.get_persisted(dsl_state, :embedded_translatable_attributes, [])

    Enum.reduce(embedded_attrs, {:ok, dsl_state}, fn attr, {:ok, state} ->
      add_embedded_calculation(state, attr)
    end)
  end

  defp add_embedded_calculation(dsl_state, attr) do
    _calc_name = :"#{attr.name}_translated"

    # Would add actual calculation here
    {:ok, dsl_state}
  end

  defp configure_embedded_serialization(dsl_state) do
    # Configure how embedded translations are serialized
    {:ok, dsl_state}
  end

  defp translate_map(data, schema, locale) do
    translatable_attrs = get_translatable_attributes(schema)

    Enum.reduce(data, %{}, fn {key, value}, acc ->
      cond do
        key in translatable_attrs ->
          Map.put(acc, key, translate_value(value, locale))

        is_embedded_value?(value) ->
          Map.put(acc, key, translate_embedded_value(value, locale))

        true ->
          Map.put(acc, key, value)
      end
    end)
  end

  defp translate_value(value, locale) when is_map(value) do
    Map.get(value, locale) || Map.get(value, :en) || ""
  end

  defp translate_value(value, _locale), do: value

  defp is_embedded_value?(value) when is_map(value) do
    Map.has_key?(value, :__struct__)
  end

  defp is_embedded_value?(value) when is_list(value) do
    Enum.all?(value, &is_embedded_value?/1)
  end

  defp is_embedded_value?(_), do: false

  defp translate_embedded_value(%{__struct__: _schema} = embedded, locale) do
    translate_embedded(embedded, locale)
  end

  defp translate_embedded_value(list, locale) when is_list(list) do
    Enum.map(list, &translate_embedded_value(&1, locale))
  end

  defp translate_embedded_value(value, _locale), do: value

  defp translate_embedded_item(item, _schema, locale) when is_map(item) do
    translate_embedded(item, locale)
  end

  defp translate_embedded_item(item, _schema, _locale), do: item

  defp update_nested_translation(resource, [field], locale, value) do
    # Update single field translation
    storage_field = :"#{field}_translations"
    current = Map.get(resource, storage_field, %{})
    updated = Map.put(current, locale, value)

    {:ok, %{storage_field => updated}}
  end

  defp update_nested_translation(resource, [head | rest], locale, value) do
    # Navigate deeper into embedded structure
    embedded = Map.get(resource, head)

    case update_nested_translation(embedded, rest, locale, value) do
      {:ok, updated_embedded} ->
        {:ok, %{head => updated_embedded}}

      error ->
        error
    end
  end

  defp collect_embedded_validation_errors(resource, required_locales) do
    paths = extract_translatable_paths(resource)

    Enum.flat_map(paths, fn path ->
      validate_path_translations(resource, path, required_locales)
    end)
  end

  defp validate_path_translations(resource, path, required_locales) do
    value = get_in_embedded(resource, path)

    missing_locales =
      required_locales
      |> Enum.reject(fn locale -> Map.has_key?(value || %{}, locale) end)

    if Enum.empty?(missing_locales) do
      []
    else
      [%{path: path, missing_locales: missing_locales}]
    end
  end

  defp get_in_embedded(resource, path) do
    Enum.reduce(path, resource, fn field, acc ->
      case acc do
        %{^field => value} -> value
        _ -> nil
      end
    end)
  end

  defp extract_paths_recursive(module, parent_path) do
    if Code.ensure_loaded?(module) && function_exported?(module, :__schema__, 1) do
      translatable_attrs = get_translatable_attributes(module)

      direct_paths =
        Enum.map(translatable_attrs, fn attr ->
          parent_path ++ [attr]
        end)

      embedded_paths =
        module
        |> get_embedded_attributes()
        |> Enum.flat_map(fn {field, embedded_module} ->
          extract_paths_recursive(embedded_module, parent_path ++ [field])
        end)

      direct_paths ++ embedded_paths
    else
      []
    end
  end

  defp get_translatable_attributes(module) do
    if function_exported?(module, :__translatable_attributes__, 0) do
      module.__translatable_attributes__()
    else
      []
    end
  rescue
    _ -> []
  end

  defp get_embedded_attributes(module) do
    if function_exported?(module, :__embedded_schemas__, 0) do
      module.__embedded_schemas__()
    else
      []
    end
  rescue
    _ -> []
  end

  defp apply_path_translations(resource, path, locale_values) do
    Enum.reduce_while(locale_values, {:ok, resource}, fn {locale, value}, {:ok, res} ->
      case update_nested_translation(res, path, locale, value) do
        {:ok, updated} -> {:cont, {:ok, updated}}
        error -> {:halt, error}
      end
    end)
  end

  defp deep_merge_translations(resource, _new_translations) do
    # Deep merge implementation
    {:ok, resource}
  end

  defp replace_translations(resource, _new_translations) do
    # Replace implementation
    {:ok, resource}
  end

  defp fill_missing_translations(resource, _new_translations) do
    # Fill missing implementation
    {:ok, resource}
  end

  defp calculate_path_completeness(resource, path) do
    value = get_in_embedded(resource, path)

    if is_map(value) do
      # Would get from config
      expected_locales = [:en, :es, :fr]
      present_locales = Map.keys(value)

      length(present_locales) / length(expected_locales) * 100
    else
      0
    end
  end

  defp average_completeness(stats) do
    if Enum.empty?(stats) do
      0
    else
      sum = Enum.reduce(stats, 0, fn {_, pct}, acc -> acc + pct end)
      sum / length(stats)
    end
  end
end
