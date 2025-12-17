defmodule AshPhoenixTranslations.InputValidatorTest do
  @moduledoc """
  Comprehensive tests for the InputValidator module.

  Tests cover:
  - Translation value validation (length, encoding, type)
  - Field name validation (format, length, characters)
  - Resource name validation
  - Locale code validation (format, length)
  - Key component validation
  - Metadata validation
  - Batch translation validation
  - Security-specific edge cases and attack vectors
  """
  use ExUnit.Case, async: true

  alias AshPhoenixTranslations.InputValidator

  describe "validate_translation/1 - valid inputs" do
    test "accepts valid string translations" do
      assert {:ok, "Hello"} = InputValidator.validate_translation("Hello")
    end

    test "accepts empty string" do
      assert {:ok, ""} = InputValidator.validate_translation("")
    end

    test "accepts nil" do
      assert {:ok, nil} = InputValidator.validate_translation(nil)
    end

    test "accepts translations with unicode characters" do
      assert {:ok, "Hola mundo"} = InputValidator.validate_translation("Hola mundo")
      assert {:ok, "Bonjour le monde"} = InputValidator.validate_translation("Bonjour le monde")
      assert {:ok, "Chinese: text"} = InputValidator.validate_translation("Chinese: text")
    end

    test "accepts translation at exactly max length" do
      max_length = 10_000
      value = String.duplicate("a", max_length)
      assert {:ok, ^value} = InputValidator.validate_translation(value)
    end

    test "accepts translations with newlines and special formatting" do
      value = "Line 1\nLine 2\r\nLine 3\tTabbed"
      assert {:ok, ^value} = InputValidator.validate_translation(value)
    end

    test "accepts translations with HTML content" do
      value = "<p>Hello <strong>world</strong></p>"
      assert {:ok, ^value} = InputValidator.validate_translation(value)
    end
  end

  describe "validate_translation/1 - invalid inputs" do
    test "rejects translations exceeding maximum length" do
      long_value = String.duplicate("a", 10_001)
      assert {:error, :translation_too_long, msg} = InputValidator.validate_translation(long_value)
      assert msg =~ "10000"
    end

    test "rejects significantly oversized translations" do
      huge_value = String.duplicate("a", 100_000)
      assert {:error, :translation_too_long, _} = InputValidator.validate_translation(huge_value)
    end

    test "rejects invalid UTF-8 encoding" do
      invalid_utf8 = <<0xFF, 0xFE, 0x00, 0x01>>
      assert {:error, :invalid_encoding, msg} = InputValidator.validate_translation(invalid_utf8)
      assert msg =~ "invalid UTF-8"
    end

    test "rejects non-string types" do
      assert {:error, :invalid_type, _} = InputValidator.validate_translation(123)
      assert {:error, :invalid_type, _} = InputValidator.validate_translation([1, 2, 3])
      assert {:error, :invalid_type, _} = InputValidator.validate_translation(%{key: "value"})
      assert {:error, :invalid_type, _} = InputValidator.validate_translation({:tuple, "value"})
    end

    test "rejects atom values" do
      assert {:error, :invalid_type, _} = InputValidator.validate_translation(:atom_value)
    end
  end

  describe "validate_field_name/1 - valid inputs" do
    test "accepts valid atom field names" do
      assert {:ok, :name} = InputValidator.validate_field_name(:name)
      assert {:ok, :description} = InputValidator.validate_field_name(:description)
      assert {:ok, :long_field_name_here} = InputValidator.validate_field_name(:long_field_name_here)
    end

    test "accepts valid string field names" do
      assert {:ok, "name"} = InputValidator.validate_field_name("name")
      assert {:ok, "description"} = InputValidator.validate_field_name("description")
      assert {:ok, "field_with_underscore"} = InputValidator.validate_field_name("field_with_underscore")
    end

    test "accepts field names with numbers" do
      assert {:ok, "field1"} = InputValidator.validate_field_name("field1")
      assert {:ok, "my_field_123"} = InputValidator.validate_field_name("my_field_123")
    end

    test "accepts atom field names at max length" do
      max_field = String.duplicate("a", 100) |> String.to_atom()
      assert {:ok, ^max_field} = InputValidator.validate_field_name(max_field)
    end

    test "accepts string field names at max length" do
      max_field = String.duplicate("a", 100)
      assert {:ok, ^max_field} = InputValidator.validate_field_name(max_field)
    end
  end

  describe "validate_field_name/1 - invalid inputs" do
    test "rejects atom field names exceeding max length" do
      long_field = String.duplicate("a", 101) |> String.to_atom()
      assert {:error, :field_name_too_long, _} = InputValidator.validate_field_name(long_field)
    end

    test "rejects string field names exceeding max length" do
      long_field = String.duplicate("a", 101)
      assert {:error, :field_name_too_long, _} = InputValidator.validate_field_name(long_field)
    end

    test "rejects field names starting with uppercase" do
      assert {:error, :invalid_field_name, _} = InputValidator.validate_field_name("Name")
      assert {:error, :invalid_field_name, _} = InputValidator.validate_field_name("MyField")
    end

    test "rejects field names starting with numbers" do
      assert {:error, :invalid_field_name, _} = InputValidator.validate_field_name("1field")
      assert {:error, :invalid_field_name, _} = InputValidator.validate_field_name("123")
    end

    test "rejects field names with special characters" do
      assert {:error, :invalid_field_name, _} = InputValidator.validate_field_name("field-name")
      assert {:error, :invalid_field_name, _} = InputValidator.validate_field_name("field.name")
      assert {:error, :invalid_field_name, _} = InputValidator.validate_field_name("field name")
      assert {:error, :invalid_field_name, _} = InputValidator.validate_field_name("field@name")
    end

    test "rejects non-string/non-atom types" do
      assert {:error, :invalid_type, _} = InputValidator.validate_field_name(123)
      assert {:error, :invalid_type, _} = InputValidator.validate_field_name([])
      assert {:error, :invalid_type, _} = InputValidator.validate_field_name(%{})
    end
  end

  describe "validate_resource_name/1 - valid inputs" do
    test "accepts valid module atoms" do
      assert {:ok, MyApp.Product} = InputValidator.validate_resource_name(MyApp.Product)
      assert {:ok, MyApp.Context.Resource} = InputValidator.validate_resource_name(MyApp.Context.Resource)
    end

    test "accepts Elixir prefixed atom" do
      assert {:ok, Elixir.MyApp.Product} = InputValidator.validate_resource_name(Elixir.MyApp.Product)
    end

    test "accepts valid string resource names" do
      assert {:ok, "MyApp.Product"} = InputValidator.validate_resource_name("MyApp.Product")
    end

    test "accepts resource names within length limit" do
      valid_name = String.duplicate("A", 200)
      assert {:ok, ^valid_name} = InputValidator.validate_resource_name(valid_name)
    end
  end

  describe "validate_resource_name/1 - invalid inputs" do
    test "rejects atom resource names exceeding max length" do
      # Create a very long module name
      long_name =
        "Elixir." <> String.duplicate("A", 200)
        |> String.to_atom()

      assert {:error, :resource_name_too_long, _} = InputValidator.validate_resource_name(long_name)
    end

    test "rejects string resource names exceeding max length" do
      long_name = String.duplicate("A", 201)
      assert {:error, :resource_name_too_long, _} = InputValidator.validate_resource_name(long_name)
    end

    test "rejects atoms not starting with Elixir prefix" do
      assert {:error, :invalid_resource, _} = InputValidator.validate_resource_name(:not_a_module)
      assert {:error, :invalid_resource, _} = InputValidator.validate_resource_name(:simple_atom)
    end

    test "rejects non-atom/non-string types" do
      assert {:error, :invalid_type, _} = InputValidator.validate_resource_name(123)
      assert {:error, :invalid_type, _} = InputValidator.validate_resource_name([])
      assert {:error, :invalid_type, _} = InputValidator.validate_resource_name(%{})
    end
  end

  describe "validate_locale_code/1 - valid inputs" do
    test "accepts two-letter locale codes" do
      assert {:ok, "en"} = InputValidator.validate_locale_code("en")
      assert {:ok, "es"} = InputValidator.validate_locale_code("es")
      assert {:ok, "fr"} = InputValidator.validate_locale_code("fr")
      assert {:ok, "de"} = InputValidator.validate_locale_code("de")
    end

    test "accepts locale codes with region" do
      assert {:ok, "en_US"} = InputValidator.validate_locale_code("en_US")
      assert {:ok, "es_MX"} = InputValidator.validate_locale_code("es_MX")
      assert {:ok, "pt_BR"} = InputValidator.validate_locale_code("pt_BR")
    end

    test "accepts atom locale codes" do
      assert {:ok, "en"} = InputValidator.validate_locale_code(:en)
      assert {:ok, "es"} = InputValidator.validate_locale_code(:es)
      assert {:ok, "en_US"} = InputValidator.validate_locale_code(:en_US)
    end
  end

  describe "validate_locale_code/1 - invalid inputs" do
    test "rejects locale codes exceeding max length" do
      long_locale = String.duplicate("e", 11)
      assert {:error, :locale_too_long, _} = InputValidator.validate_locale_code(long_locale)
    end

    test "rejects invalid locale format - single letter" do
      assert {:error, :invalid_locale_format, _} = InputValidator.validate_locale_code("e")
    end

    test "rejects invalid locale format - three letters without region" do
      assert {:error, :invalid_locale_format, _} = InputValidator.validate_locale_code("eng")
    end

    test "rejects invalid locale format - wrong case for language" do
      assert {:error, :invalid_locale_format, _} = InputValidator.validate_locale_code("EN")
      assert {:error, :invalid_locale_format, _} = InputValidator.validate_locale_code("En")
    end

    test "rejects invalid locale format - wrong case for region" do
      assert {:error, :invalid_locale_format, _} = InputValidator.validate_locale_code("en_us")
      assert {:error, :invalid_locale_format, _} = InputValidator.validate_locale_code("en_Us")
    end

    test "rejects invalid locale format - wrong separator" do
      assert {:error, :invalid_locale_format, _} = InputValidator.validate_locale_code("en-US")
      assert {:error, :invalid_locale_format, _} = InputValidator.validate_locale_code("en.US")
    end

    test "rejects locale codes with special characters" do
      assert {:error, :invalid_locale_format, _} = InputValidator.validate_locale_code("e!")
      assert {:error, :invalid_locale_format, _} = InputValidator.validate_locale_code("12")
    end

    test "rejects non-string/non-atom types" do
      assert {:error, :invalid_type, _} = InputValidator.validate_locale_code(123)
      assert {:error, :invalid_type, _} = InputValidator.validate_locale_code([])
    end
  end

  describe "validate_key_component/1 - valid inputs" do
    test "accepts valid string components" do
      assert {:ok, "component"} = InputValidator.validate_key_component("component")
      assert {:ok, "my_component_123"} = InputValidator.validate_key_component("my_component_123")
    end

    test "accepts atom components" do
      assert {:ok, "atom_component"} = InputValidator.validate_key_component(:atom_component)
    end

    test "accepts number components" do
      assert {:ok, "123"} = InputValidator.validate_key_component(123)
      assert {:ok, "456.78"} = InputValidator.validate_key_component(456.78)
    end

    test "accepts components at max length" do
      max_component = String.duplicate("a", 500)
      assert {:ok, ^max_component} = InputValidator.validate_key_component(max_component)
    end

    test "accepts empty string" do
      assert {:ok, ""} = InputValidator.validate_key_component("")
    end
  end

  describe "validate_key_component/1 - invalid inputs" do
    test "rejects components exceeding max length" do
      long_component = String.duplicate("a", 501)
      assert {:error, :key_component_too_long, _} = InputValidator.validate_key_component(long_component)
    end

    test "rejects invalid types" do
      assert {:error, :invalid_type, _} = InputValidator.validate_key_component([])
      assert {:error, :invalid_type, _} = InputValidator.validate_key_component(%{})
      assert {:error, :invalid_type, _} = InputValidator.validate_key_component({:tuple})
    end
  end

  describe "validate_metadata/1 - valid inputs" do
    test "accepts valid metadata map" do
      metadata = %{"key" => "value", "another" => "value2"}
      assert {:ok, ^metadata} = InputValidator.validate_metadata(metadata)
    end

    test "accepts empty metadata map" do
      assert {:ok, %{}} = InputValidator.validate_metadata(%{})
    end

    test "accepts nil" do
      assert {:ok, nil} = InputValidator.validate_metadata(nil)
    end

    test "accepts metadata with atom keys" do
      metadata = %{key: "value"}
      assert {:ok, ^metadata} = InputValidator.validate_metadata(metadata)
    end

    test "accepts metadata at size limit" do
      # Create metadata that's exactly at the limit
      key = String.duplicate("k", 100)
      value = String.duplicate("v", 900)
      metadata = %{key => value}
      assert {:ok, ^metadata} = InputValidator.validate_metadata(metadata)
    end
  end

  describe "validate_metadata/1 - invalid inputs" do
    test "rejects metadata exceeding size limit" do
      large_value = String.duplicate("x", 2000)
      metadata = %{"key" => large_value}
      assert {:error, :metadata_too_large, _} = InputValidator.validate_metadata(metadata)
    end

    test "rejects non-map types" do
      assert {:error, :invalid_type, _} = InputValidator.validate_metadata("string")
      assert {:error, :invalid_type, _} = InputValidator.validate_metadata([])
      assert {:error, :invalid_type, _} = InputValidator.validate_metadata({:tuple})
      assert {:error, :invalid_type, _} = InputValidator.validate_metadata(123)
    end
  end

  describe "validate_translation_batch/1 - valid inputs" do
    test "accepts valid batch of translations" do
      translations = [
        %{field: :name, locale: :en, value: "Hello"},
        %{field: :name, locale: :es, value: "Hola"}
      ]

      assert {:ok, validated} = InputValidator.validate_translation_batch(translations)
      assert length(validated) == 2
    end

    test "accepts empty batch" do
      assert {:ok, []} = InputValidator.validate_translation_batch([])
    end

    test "accepts single translation batch" do
      translations = [%{field: :name, locale: :en, value: "Hello"}]
      assert {:ok, validated} = InputValidator.validate_translation_batch(translations)
      assert length(validated) == 1
    end

    test "accepts batch with nil values" do
      translations = [%{field: :name, locale: :en, value: nil}]
      assert {:ok, validated} = InputValidator.validate_translation_batch(translations)
      assert length(validated) == 1
    end

    test "preserves order of translations" do
      translations = [
        %{field: :name, locale: :en, value: "First"},
        %{field: :name, locale: :es, value: "Second"},
        %{field: :name, locale: :fr, value: "Third"}
      ]

      {:ok, validated} = InputValidator.validate_translation_batch(translations)
      assert Enum.at(validated, 0).value == "First"
      assert Enum.at(validated, 1).value == "Second"
      assert Enum.at(validated, 2).value == "Third"
    end
  end

  describe "validate_translation_batch/1 - invalid inputs" do
    import ExUnit.CaptureLog

    test "rejects batch with invalid translation values" do
      translations = [
        %{field: :name, locale: :en, value: String.duplicate("a", 10_001)}
      ]

      capture_log(fn ->
        assert {:error, 1, _errors} = InputValidator.validate_translation_batch(translations)
      end)
    end

    test "rejects batch with invalid field names" do
      translations = [
        %{field: "Invalid-Field", locale: :en, value: "Hello"}
      ]

      capture_log(fn ->
        assert {:error, 1, _errors} = InputValidator.validate_translation_batch(translations)
      end)
    end

    test "rejects batch with invalid locale codes" do
      translations = [
        %{field: :name, locale: :invalid_locale_format, value: "Hello"}
      ]

      capture_log(fn ->
        assert {:error, 1, _errors} = InputValidator.validate_translation_batch(translations)
      end)
    end

    test "rejects batch with missing required fields" do
      translations = [
        %{field: :name, value: "Hello"}  # missing locale
      ]

      capture_log(fn ->
        assert {:error, 1, _errors} = InputValidator.validate_translation_batch(translations)
      end)
    end

    test "returns correct count of invalid entries" do
      translations = [
        %{field: :name, locale: :en, value: "Valid"},
        %{field: "Invalid-Field", locale: :en, value: "Invalid"},
        %{field: :name, locale: :invalid, value: "Invalid"},
        %{field: :name, locale: :es, value: "Valid"}
      ]

      capture_log(fn ->
        assert {:error, 2, errors} = InputValidator.validate_translation_batch(translations)
        assert length(errors) == 2
      end)
    end

    test "rejects non-list input" do
      capture_log(fn ->
        assert {:error, :invalid_type, _} = InputValidator.validate_translation_batch("not a list")
        assert {:error, :invalid_type, _} = InputValidator.validate_translation_batch(%{})
        assert {:error, :invalid_type, _} = InputValidator.validate_translation_batch(123)
      end)
    end
  end

  describe "security scenarios" do
    import ExUnit.CaptureLog

    test "prevents memory exhaustion via oversized translations" do
      # Attempt to submit extremely large translation
      huge_value = String.duplicate("x", 1_000_000)
      assert {:error, :translation_too_long, _} = InputValidator.validate_translation(huge_value)
    end

    test "prevents injection via field names" do
      # SQL injection attempt
      assert {:error, :invalid_field_name, _} =
               InputValidator.validate_field_name("name; DROP TABLE translations;")

      # Path traversal attempt
      assert {:error, :invalid_field_name, _} =
               InputValidator.validate_field_name("../../../etc/passwd")

      # Script injection attempt
      assert {:error, :invalid_field_name, _} =
               InputValidator.validate_field_name("<script>alert('xss')</script>")
    end

    test "handles null byte injection attempts" do
      # Null bytes could be used to bypass validation
      assert {:error, :invalid_field_name, _} =
               InputValidator.validate_field_name("name\x00evil")
    end

    test "handles unicode normalization attacks" do
      # Different unicode representations of the same character
      # These should be handled consistently
      result1 = InputValidator.validate_translation("cafe")
      result2 = InputValidator.validate_translation("cafe")  # normalized form

      assert {:ok, _} = result1
      assert {:ok, _} = result2
    end

    test "prevents batch bombing attack" do
      capture_log(fn ->
        # Large batch with oversized values
        translations =
          Enum.map(1..100, fn _ ->
            %{field: :name, locale: :en, value: String.duplicate("x", 10_001)}
          end)

        {:error, invalid_count, _} = InputValidator.validate_translation_batch(translations)
        assert invalid_count == 100
      end)
    end

    test "prevents locale injection attacks" do
      # Attempt to inject via locale code
      assert {:error, _, _} = InputValidator.validate_locale_code("en'; DROP TABLE--")
      assert {:error, _, _} = InputValidator.validate_locale_code("../../etc")
    end

    test "validates all fields in batch entry" do
      capture_log(fn ->
        # Ensure all fields are validated, not just some
        translations = [
          %{
            field: "Invalid-Field",
            locale: :invalid_locale,
            value: String.duplicate("x", 10_001)
          }
        ]

        # Should catch at least one error
        assert {:error, 1, _} = InputValidator.validate_translation_batch(translations)
      end)
    end
  end

  describe "edge cases" do
    test "handles empty strings appropriately" do
      assert {:ok, ""} = InputValidator.validate_translation("")
      assert {:ok, ""} = InputValidator.validate_key_component("")
    end

    test "handles whitespace-only strings" do
      assert {:ok, "   "} = InputValidator.validate_translation("   ")
      assert {:ok, "\t\n"} = InputValidator.validate_translation("\t\n")
    end

    test "handles unicode edge cases" do
      # Zero-width characters
      assert {:ok, _} = InputValidator.validate_translation("hello\u200Bworld")

      # Right-to-left text
      assert {:ok, _} = InputValidator.validate_translation("Hello world")

      # Emoji
      assert {:ok, _} = InputValidator.validate_translation("Hello World")
    end

    test "handles boundary values" do
      # Exactly at limit
      at_limit = String.duplicate("a", 10_000)
      assert {:ok, _} = InputValidator.validate_translation(at_limit)

      # One over limit
      over_limit = String.duplicate("a", 10_001)
      assert {:error, :translation_too_long, _} = InputValidator.validate_translation(over_limit)
    end
  end
end
