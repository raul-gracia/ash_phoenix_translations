defmodule AshPhoenixTranslations.ErrorsTest do
  @moduledoc """
  Tests for the error modules in AshPhoenixTranslations.

  This module tests the custom exception structs used throughout
  the translation library.
  """

  use ExUnit.Case, async: true

  alias AshPhoenixTranslations.MissingTranslationError
  alias AshPhoenixTranslations.InvalidLocaleError
  alias AshPhoenixTranslations.BackendError

  describe "MissingTranslationError" do
    test "can be created with locale and available locales" do
      error = %MissingTranslationError{
        locale: :es,
        available: [:en, :fr]
      }

      assert error.locale == :es
      assert error.available == [:en, :fr]
    end

    test "can include field information" do
      error = %MissingTranslationError{
        locale: :es,
        available: [:en],
        field: :name
      }

      assert error.field == :name
    end

    test "can include resource information" do
      error = %MissingTranslationError{
        locale: :es,
        available: [:en],
        resource: MyApp.Product
      }

      assert error.resource == MyApp.Product
    end

    test "generates descriptive message" do
      error = %MissingTranslationError{
        locale: :es,
        available: [:en, :fr]
      }

      message = Exception.message(error)

      assert message =~ "Missing translation"
      assert message =~ ":es"
      assert message =~ ":en"
      assert message =~ ":fr"
    end

    test "message includes field when provided" do
      error = %MissingTranslationError{
        locale: :de,
        available: [:en],
        field: :description
      }

      message = Exception.message(error)

      assert message =~ "Field: description"
    end

    test "message includes resource when provided" do
      error = %MissingTranslationError{
        locale: :de,
        available: [:en],
        resource: MyApp.Product
      }

      message = Exception.message(error)

      assert message =~ "Resource:"
    end

    test "can be raised" do
      assert_raise MissingTranslationError, fn ->
        raise %MissingTranslationError{
          locale: :es,
          available: [:en]
        }
      end
    end

    test "can be raised with options" do
      assert_raise MissingTranslationError, ~r/Missing translation/, fn ->
        raise MissingTranslationError,
          locale: :es,
          available: [:en, :fr],
          field: :name
      end
    end

    test "handles empty available list" do
      error = %MissingTranslationError{
        locale: :es,
        available: []
      }

      message = Exception.message(error)

      assert message =~ "Missing translation"
      assert message =~ ":es"
    end

    test "handles nil field gracefully" do
      error = %MissingTranslationError{
        locale: :es,
        available: [:en],
        field: nil
      }

      message = Exception.message(error)

      # Should not crash when field is nil
      assert is_binary(message)
    end

    test "handles nil resource gracefully" do
      error = %MissingTranslationError{
        locale: :es,
        available: [:en],
        resource: nil
      }

      message = Exception.message(error)

      # Should not crash when resource is nil
      assert is_binary(message)
    end
  end

  describe "InvalidLocaleError" do
    test "can be created with locale and supported locales" do
      error = %InvalidLocaleError{
        locale: :xyz,
        supported: [:en, :es, :fr]
      }

      assert error.locale == :xyz
      assert error.supported == [:en, :es, :fr]
    end

    test "generates descriptive message" do
      error = %InvalidLocaleError{
        locale: :invalid,
        supported: [:en, :es]
      }

      message = Exception.message(error)

      assert message =~ "Invalid locale"
      assert message =~ ":invalid"
      assert message =~ ":en"
      assert message =~ ":es"
    end

    test "can be raised" do
      assert_raise InvalidLocaleError, fn ->
        raise %InvalidLocaleError{
          locale: :xyz,
          supported: [:en, :es]
        }
      end
    end

    test "can be raised with options" do
      assert_raise InvalidLocaleError, ~r/Invalid locale/, fn ->
        raise InvalidLocaleError,
          locale: :invalid_locale,
          supported: [:en, :es, :fr]
      end
    end

    test "handles string locale" do
      error = %InvalidLocaleError{
        locale: "bad-locale",
        supported: [:en, :es]
      }

      message = Exception.message(error)

      assert message =~ "Invalid locale"
      assert message =~ "bad-locale"
    end

    test "handles empty supported list" do
      error = %InvalidLocaleError{
        locale: :es,
        supported: []
      }

      message = Exception.message(error)

      assert message =~ "Invalid locale"
    end
  end

  describe "BackendError" do
    test "can be created with backend, operation, and reason" do
      error = %BackendError{
        backend: :database,
        operation: :fetch,
        reason: :timeout
      }

      assert error.backend == :database
      assert error.operation == :fetch
      assert error.reason == :timeout
    end

    test "generates descriptive message" do
      error = %BackendError{
        backend: :database,
        operation: :update,
        reason: {:connection_error, "Host unreachable"}
      }

      message = Exception.message(error)

      assert message =~ "Backend operation failed"
      assert message =~ "database"
      assert message =~ "update"
      assert message =~ "connection_error"
    end

    test "can be raised" do
      assert_raise BackendError, fn ->
        raise %BackendError{
          backend: :gettext,
          operation: :compile,
          reason: "PO file not found"
        }
      end
    end

    test "can be raised with options" do
      assert_raise BackendError, ~r/Backend operation failed/, fn ->
        raise BackendError,
          backend: :database,
          operation: :fetch,
          reason: :not_found
      end
    end

    test "handles complex reason tuples" do
      error = %BackendError{
        backend: :database,
        operation: :query,
        reason: {:invalid_sql, "syntax error", line: 42}
      }

      message = Exception.message(error)

      assert message =~ "Backend operation failed"
      assert message =~ "invalid_sql"
    end

    test "handles error struct as reason" do
      inner_error = %RuntimeError{message: "Something went wrong"}

      error = %BackendError{
        backend: :database,
        operation: :save,
        reason: inner_error
      }

      message = Exception.message(error)

      assert message =~ "Backend operation failed"
      assert message =~ "RuntimeError"
    end

    test "handles nil reason" do
      error = %BackendError{
        backend: :gettext,
        operation: :load,
        reason: nil
      }

      message = Exception.message(error)

      assert message =~ "Backend operation failed"
      assert message =~ "nil"
    end
  end

  describe "error integration" do
    test "MissingTranslationError can be caught" do
      result =
        try do
          raise MissingTranslationError,
            locale: :es,
            available: [:en]
        rescue
          e in MissingTranslationError ->
            {:caught, e.locale}
        end

      assert result == {:caught, :es}
    end

    test "InvalidLocaleError can be caught" do
      result =
        try do
          raise InvalidLocaleError,
            locale: :invalid,
            supported: [:en, :es]
        rescue
          e in InvalidLocaleError ->
            {:caught, e.locale, e.supported}
        end

      assert result == {:caught, :invalid, [:en, :es]}
    end

    test "BackendError can be caught" do
      result =
        try do
          raise BackendError,
            backend: :database,
            operation: :save,
            reason: :conflict
        rescue
          e in BackendError ->
            {:caught, e.backend, e.operation, e.reason}
        end

      assert result == {:caught, :database, :save, :conflict}
    end

    test "errors can be pattern matched in case" do
      error = %MissingTranslationError{locale: :es, available: [:en]}

      result =
        case error do
          %MissingTranslationError{locale: :es} -> :spanish_missing
          %MissingTranslationError{locale: _} -> :other_missing
        end

      assert result == :spanish_missing
    end
  end

  describe "error equality" do
    test "MissingTranslationError with same fields are equal" do
      error1 = %MissingTranslationError{locale: :es, available: [:en]}
      error2 = %MissingTranslationError{locale: :es, available: [:en]}

      assert error1 == error2
    end

    test "InvalidLocaleError with same fields are equal" do
      error1 = %InvalidLocaleError{locale: :xyz, supported: [:en, :es]}
      error2 = %InvalidLocaleError{locale: :xyz, supported: [:en, :es]}

      assert error1 == error2
    end

    test "BackendError with same fields are equal" do
      error1 = %BackendError{backend: :database, operation: :save, reason: :error}
      error2 = %BackendError{backend: :database, operation: :save, reason: :error}

      assert error1 == error2
    end
  end
end
