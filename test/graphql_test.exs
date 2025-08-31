defmodule AshPhoenixTranslations.GraphqlTest do
  use ExUnit.Case, async: true
  
  alias AshPhoenixTranslations.Graphql
  
  describe "resolve_translation/3" do
    test "resolves translation for requested locale" do
      resource = %{
        name_translations: %{
          en: "Product",
          es: "Producto",
          fr: "Produit"
        }
      }
      
      resolution = %{
        source: resource,
        arguments: %{locale: :es},
        state: :name
      }
      
      assert {:ok, "Producto"} = Graphql.resolve_translation(resolution)
    end
    
    test "falls back to English when locale not found" do
      resource = %{
        name_translations: %{
          en: "Product"
        }
      }
      
      resolution = %{
        source: resource,
        arguments: %{locale: :de},
        state: :name
      }
      
      assert {:ok, "Product"} = Graphql.resolve_translation(resolution)
    end
    
    test "handles missing translations gracefully" do
      resource = %{}
      
      resolution = %{
        source: resource,
        arguments: %{locale: :es},
        state: :name
      }
      
      assert {:ok, nil} = Graphql.resolve_translation(resolution)
    end
  end
  
  describe "resolve_all_translations/2" do
    test "returns all translations formatted for GraphQL" do
      resource = %{
        description_translations: %{
          en: "A great product",
          es: "Un gran producto",
          fr: "Un excellent produit"
        }
      }
      
      resolution = %{
        source: resource,
        state: :description
      }
      
      {:ok, translations} = Graphql.resolve_all_translations(resolution)
      
      assert length(translations) == 3
      assert %{locale: "en", value: "A great product"} in translations
      assert %{locale: "es", value: "Un gran producto"} in translations
      assert %{locale: "fr", value: "Un excellent produit"} in translations
    end
    
    test "handles empty translations" do
      resource = %{}
      
      resolution = %{
        source: resource,
        state: :description
      }
      
      assert {:ok, []} = Graphql.resolve_all_translations(resolution)
    end
  end
  
  describe "LocaleMiddleware" do
    test "extracts locale from context" do
      resolution = %{
        context: %{locale: :fr}
      }
      
      result = Graphql.LocaleMiddleware.call(resolution, [])
      
      assert result.context.locale == :fr
    end
    
    test "falls back to accept_language" do
      resolution = %{
        context: %{accept_language: :es}
      }
      
      result = Graphql.LocaleMiddleware.call(resolution, [])
      
      assert result.context.locale == :es
    end
    
    test "falls back to default locale" do
      resolution = %{
        context: %{}
      }
      
      result = Graphql.LocaleMiddleware.call(resolution, [])
      
      assert result.context.locale == :en
    end
  end
  
  describe "parse_locale/1" do
    test "parses valid locale string" do
      input = %Absinthe.Blueprint.Input.String{value: "es"}
      assert {:ok, :es} = Graphql.parse_locale(input)
    end
    
    test "parses locale with country code" do
      input = %Absinthe.Blueprint.Input.String{value: "en-US"}
      assert {:ok, :"en-US"} = Graphql.parse_locale(input)
    end
    
    test "rejects invalid locale format" do
      input = %Absinthe.Blueprint.Input.String{value: "invalid"}
      assert :error = Graphql.parse_locale(input)
    end
    
    test "handles null input" do
      input = %Absinthe.Blueprint.Input.Null{}
      assert {:ok, nil} = Graphql.parse_locale(input)
    end
  end
  
  describe "serialize_locale/1" do
    test "serializes atom locale to string" do
      assert "es" = Graphql.serialize_locale(:es)
    end
    
    test "passes through string locale" do
      assert "fr" = Graphql.serialize_locale("fr")
    end
  end
  
  describe "translation_input_type/2" do
    defmodule TestResource do
      def __resource__, do: :test_resource
    end
    
    test "creates input type for translation field" do
      input_type = Graphql.translation_input_type(TestResource, :name)
      
      assert input_type.name == :test_resource_name_translation_input
      assert input_type.description == "Translation input for name"
      assert Map.has_key?(input_type.fields, :locale)
      assert Map.has_key?(input_type.fields, :value)
    end
  end
  
  describe "add_locale_argument_to_query/1" do
    test "adds locale argument to query config" do
      query_config = %{
        args: [
          limit: [type: :integer, description: "Limit results"]
        ]
      }
      
      updated = Graphql.add_locale_argument_to_query(query_config)
      
      assert Keyword.has_key?(updated.args, :locale)
      assert Keyword.has_key?(updated.args, :limit)
    end
    
    test "handles query without existing args" do
      query_config = %{}
      
      updated = Graphql.add_locale_argument_to_query(query_config)
      
      assert Keyword.has_key?(updated.args, :locale)
    end
  end
end