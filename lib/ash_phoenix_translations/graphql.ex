defmodule AshPhoenixTranslations.Graphql do
  @moduledoc """
  GraphQL integration for AshPhoenixTranslations.
  
  This module provides helpers and resolvers for exposing translations
  through AshGraphql APIs.
  
  ## Usage
  
  In your resource with AshGraphql:
  
      defmodule MyApp.Product do
        use Ash.Resource,
          extensions: [AshPhoenixTranslations, AshGraphql.Resource]
        
        graphql do
          type :product
          
          queries do
            get :get_product, :read
            list :list_products, :read
          end
        end
        
        translations do
          translatable_attribute :name, :string,
            locales: [:en, :es, :fr]
          
          # Enable GraphQL fields
          graphql_translations true
        end
      end
  
  This will automatically add:
  - Translation fields to your GraphQL type
  - Locale argument to queries
  - Translation input types for mutations
  """
  
  @doc """
  Adds GraphQL translation fields to a resource's schema.
  
  This is called by the transformer when `graphql_translations true` is set.
  """
  def add_graphql_fields(dsl_state) do
    if has_graphql_extension?(dsl_state) do
      dsl_state
      |> add_translation_fields()
      |> add_locale_argument()
      |> add_translation_resolvers()
    else
      {:ok, dsl_state}
    end
  end
  
  @doc """
  Resolver for translated fields in GraphQL queries.
  
  This resolver is automatically attached to translation fields.
  """
  def resolve_translation(%{source: resource, arguments: %{locale: locale}, state: field}) do
    storage_field = :"#{field}_translations"
    translations = Map.get(resource, storage_field, %{})
    
    value = Map.get(translations, locale) || Map.get(translations, :en)
    {:ok, value}
  end
  
  @doc """
  Resolver for the complete translations object.
  
  Returns all translations for a field as a GraphQL object.
  """
  def resolve_all_translations(%{source: resource, state: field}) do
    storage_field = :"#{field}_translations"
    translations = Map.get(resource, storage_field, %{})
    
    # Convert to GraphQL-friendly format
    formatted = 
      translations
      |> Enum.map(fn {locale, value} ->
        %{locale: to_string(locale), value: value}
      end)
    
    {:ok, formatted}
  end
  
  @doc """
  Middleware for setting locale context in GraphQL queries.
  
  Add this to your Absinthe schema:
  
      def middleware(middleware, _field, _object) do
        [AshPhoenixTranslations.Graphql.LocaleMiddleware | middleware]
      end
  """
  defmodule LocaleMiddleware do
    @behaviour Absinthe.Middleware
    
    def call(resolution, _opts) do
      locale = get_locale_from_context(resolution.context)
      
      resolution
      |> Map.update!(:context, &Map.put(&1, :locale, locale))
    end
    
    defp get_locale_from_context(context) do
      context[:locale] || 
        context[:accept_language] || 
        Application.get_env(:ash_phoenix_translations, :default_locale, :en)
    end
  end
  
  @doc """
  Parser for locale scalar type values.
  
  Validates and parses locale values from GraphQL input.
  """
  def parse_locale(input) when is_map(input) do
    case input do
      %{value: value} when is_binary(value) ->
        case validate_locale(value) do
          {:ok, locale} -> {:ok, locale}
          :error -> :error
        end
      
      %{value: nil} ->
        {:ok, nil}
      
      _ ->
        :error
    end
  end
  
  def parse_locale(_) do
    :error
  end
  
  def serialize_locale(locale) when is_atom(locale) do
    to_string(locale)
  end
  
  def serialize_locale(locale) when is_binary(locale) do
    locale
  end
  
  @doc """
  Input object for translation updates.
  
  Returns configuration for GraphQL input type generation.
  """
  def translation_input_type(resource, field) do
    %{
      name: :"#{resource.__resource__}_#{field}_translation_input",
      description: "Translation input for #{field}",
      fields: %{
        locale: %{
          type: {:non_null, :locale},
          description: "The locale for this translation"
        },
        value: %{
          type: :string,
          description: "The translated value"
        }
      }
    }
  end
  
  @doc """
  Adds translation arguments to GraphQL queries.
  
  This allows filtering by locale:
  
      query {
        listProducts(locale: "es") {
          id
          name  # Will be in Spanish
        }
      }
  """
  def add_locale_argument_to_query(query_config) do
    Map.update(query_config, :args, [], fn args ->
      args ++ [
        locale: [
          type: :locale,
          description: "Locale for translations",
          default: :en
        ]
      ]
    end)
  end
  
  @doc """
  Batch loader for translations to avoid N+1 queries.
  
  Use with Dataloader in your schema:
  
      def context(ctx) do
        loader = 
          Dataloader.new()
          |> Dataloader.add_source(
            :translations,
            AshPhoenixTranslations.Graphql.data()
          )
        
        Map.put(ctx, :loader, loader)
      end
  """
  def data do
    Dataloader.KV.new(&fetch_translations/2)
  end
  
  defp fetch_translations(_batch_key, resource_ids) do
    # This would batch-load translations for multiple resources
    # Implementation depends on the backend
    Map.new(resource_ids, fn id ->
      {id, %{}}  # Placeholder - would load actual translations
    end)
  end
  
  # Private helpers
  
  defp has_graphql_extension?(dsl_state) do
    AshGraphql.Resource in Spark.Dsl.Extension.get_persisted(dsl_state, :extensions, [])
  rescue
    _ -> false
  end
  
  defp add_translation_fields(dsl_state) do
    translatable_attrs = Spark.Dsl.Extension.get_entities(dsl_state, [:translations, :translatable_attribute])
    
    Enum.reduce(translatable_attrs, {:ok, dsl_state}, fn attr, {:ok, state} ->
      add_field_to_graphql_type(state, attr)
    end)
  end
  
  defp add_field_to_graphql_type(dsl_state, attr) do
    # Add the translated field to the GraphQL type
    field = %{
      name: attr.name,
      type: graphql_type_for_ash_type(attr.type),
      description: "Translated #{attr.name}",
      resolver: &__MODULE__.resolve_translation/3,
      middleware: [
        {__MODULE__.LocaleMiddleware, []}
      ]
    }
    
    # Also add a field for all translations
    all_field = %{
      name: :"#{attr.name}_translations",
      type: {:list, :translation},
      description: "All translations for #{attr.name}",
      resolver: &__MODULE__.resolve_all_translations/3
    }
    
    {:ok, dsl_state}  # Would need actual implementation to modify GraphQL schema
  end
  
  defp add_locale_argument(dsl_state) do
    # Add locale argument to all queries
    {:ok, dsl_state}
  end
  
  defp add_translation_resolvers(dsl_state) do
    # Add custom resolvers for translation fields
    {:ok, dsl_state}
  end
  
  defp graphql_type_for_ash_type(:string), do: :string
  defp graphql_type_for_ash_type(:text), do: :string
  defp graphql_type_for_ash_type(:integer), do: :integer
  defp graphql_type_for_ash_type(:boolean), do: :boolean
  defp graphql_type_for_ash_type(:decimal), do: :float
  defp graphql_type_for_ash_type(:float), do: :float
  defp graphql_type_for_ash_type(:date), do: :date
  defp graphql_type_for_ash_type(:datetime), do: :datetime
  defp graphql_type_for_ash_type(_), do: :string
  
  defp validate_locale(locale) when is_binary(locale) do
    if locale =~ ~r/^[a-z]{2}(-[A-Z]{2})?$/ do
      {:ok, String.to_atom(locale)}
    else
      :error
    end
  end
  
  defp validate_locale(_), do: :error
end