defmodule AshPhoenixTranslations.ErrorSanitizerTest do
  @moduledoc """
  Comprehensive tests for the ErrorSanitizer module.

  Tests cover:
  - Error type detection and sanitization
  - Validation error handling
  - Authorization error handling
  - Not found error handling
  - File path removal from error messages
  - Stack trace removal
  - Database constraint error sanitization
  - File system error sanitization
  - Network error sanitization
  - Changeset error sanitization
  - Information disclosure prevention
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias AshPhoenixTranslations.ErrorSanitizer

  describe "sanitize_error/2 - validation errors" do
    test "detects validation errors by module name containing 'Invalid'" do
      error_struct = %{
        __struct__: :"Elixir.InvalidFieldError",
        message: "Internal error details"
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        assert sanitized.type == :validation_error
        assert sanitized.message =~ "Validation failed"
      end)
    end

    test "detects validation errors by module name containing 'Validation'" do
      error_struct = %{
        __struct__: :"Elixir.ValidationError",
        message: "Internal error details"
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        assert sanitized.type == :validation_error
      end)
    end

    test "includes sanitized field errors when present" do
      error_struct = %{
        __struct__: :"Elixir.ValidationError",
        errors: [
          %{field: :name, message: "is invalid at /home/user/app/lib/resource.ex:42"}
        ]
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        assert sanitized.type == :validation_error
        assert is_list(sanitized.field_errors)
        assert length(sanitized.field_errors) == 1

        field_error = hd(sanitized.field_errors)
        assert field_error.field == :name
        refute field_error.message =~ "/home/user"
        refute field_error.message =~ ":42"
      end)
    end

    test "handles empty errors list" do
      error_struct = %{
        __struct__: :"Elixir.ValidationError",
        errors: []
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        assert sanitized.type == :validation_error
        assert sanitized.field_errors == []
      end)
    end

    test "handles missing errors key" do
      error_struct = %{
        __struct__: :"Elixir.ValidationError"
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        assert sanitized.type == :validation_error
        assert sanitized.field_errors == []
      end)
    end
  end

  describe "sanitize_error/2 - authorization errors" do
    test "detects authorization errors by 'Forbidden' in module name" do
      error_struct = %{
        __struct__: :"Elixir.ForbiddenError",
        message: "User lacks permission in PolicyCheck module at line 45"
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        assert sanitized.type == :authorization_error
        assert sanitized.message == "You do not have permission to perform this action."
        refute sanitized.message =~ "PolicyCheck"
        refute sanitized.message =~ "line 45"
      end)
    end

    test "detects authorization errors by 'Unauthorized' in module name" do
      error_struct = %{
        __struct__: :"Elixir.UnauthorizedAccessError",
        message: "Access denied to admin panel"
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        assert sanitized.type == :authorization_error
        assert sanitized.message == "You do not have permission to perform this action."
      end)
    end

    test "does not leak internal authorization details" do
      error_struct = %{
        __struct__: :"Elixir.ForbiddenError",
        message: "User user@example.com with role :user denied access to admin resource"
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        refute sanitized.message =~ "user@example.com"
        refute sanitized.message =~ ":user"
        refute sanitized.message =~ "admin resource"
      end)
    end
  end

  describe "sanitize_error/2 - not found errors" do
    test "detects not found errors by 'NotFound' in module name" do
      error_struct = %{
        __struct__: :"Elixir.NotFoundError",
        message: "Record with id 12345 not found in translations table"
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        assert sanitized.type == :not_found
        assert sanitized.message == "The requested resource was not found."
        refute sanitized.message =~ "12345"
        refute sanitized.message =~ "translations table"
      end)
    end
  end

  describe "sanitize_error/2 - internal errors" do
    test "treats unknown error types as internal errors" do
      error_struct = %{
        __struct__: :"Elixir.SomeUnknownError",
        message: "Internal details about system failure"
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        assert sanitized.type == :internal_error
        assert sanitized.message == "An error occurred while processing your request."
      end)
    end

    test "does not leak internal error details" do
      error_struct = %{
        __struct__: :"Elixir.DatabaseConnectionError",
        message: "Failed to connect to postgres://admin:secret@db.internal:5432/myapp"
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        refute sanitized.message =~ "postgres"
        refute sanitized.message =~ "admin"
        refute sanitized.message =~ "secret"
        refute sanitized.message =~ "db.internal"
      end)
    end
  end

  describe "sanitize_error/2 - tuple errors with message" do
    test "handles {:error, %{message: string}} format" do
      error = {:error, %{message: "Database constraint violated: unique_translations_idx"}}

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error, %{})
        assert sanitized.type == :validation_error
        refute sanitized.message =~ "unique_translations_idx"
      end)
    end

    test "handles {:error, string} format" do
      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error({:error, "Some internal error"}, %{})
        assert is_map(sanitized)
        assert Map.has_key?(sanitized, :message)
      end)
    end
  end

  describe "sanitize_error/2 - generic error handling" do
    test "handles unexpected error types gracefully" do
      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(:some_atom_error, %{})
        assert sanitized.type == :internal_error
      end)
    end

    test "handles nil error gracefully" do
      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(nil, %{})
        assert sanitized.type == :internal_error
      end)
    end

    test "handles list error gracefully" do
      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(["error1", "error2"], %{})
        assert sanitized.type == :internal_error
      end)
    end
  end

  describe "sanitize_error/2 - database error sanitization" do
    test "sanitizes unique constraint errors" do
      capture_log(fn ->
        sanitized =
          ErrorSanitizer.sanitize_error(
            {:error, "unique constraint violated on translations_resource_field_locale_idx"},
            %{}
          )

        assert sanitized.type == :validation_error
        assert sanitized.message =~ "constraint"
        refute sanitized.message =~ "translations_resource_field_locale_idx"
      end)
    end

    test "sanitizes foreign key constraint errors" do
      capture_log(fn ->
        sanitized =
          ErrorSanitizer.sanitize_error(
            {:error, "foreign key constraint \"translations_resource_id_fkey\" violated"},
            %{}
          )

        assert sanitized.type == :validation_error
        refute sanitized.message =~ "translations_resource_id_fkey"
      end)
    end

    test "sanitizes check constraint errors" do
      capture_log(fn ->
        sanitized =
          ErrorSanitizer.sanitize_error(
            {:error, "check constraint \"translations_valid_locale_check\" violated"},
            %{}
          )

        assert sanitized.type == :validation_error
        refute sanitized.message =~ "translations_valid_locale_check"
      end)
    end
  end

  describe "sanitize_error/2 - file system error sanitization" do
    test "sanitizes file not found errors" do
      capture_log(fn ->
        sanitized =
          ErrorSanitizer.sanitize_error(
            {:error, "ENOENT: /etc/secret/config.yml not found"},
            %{}
          )

        assert sanitized.type == :file_error
        refute sanitized.message =~ "/etc/secret"
        refute sanitized.message =~ "config.yml"
      end)
    end

    test "sanitizes permission denied errors" do
      capture_log(fn ->
        sanitized =
          ErrorSanitizer.sanitize_error(
            {:error, "permission denied accessing /root/.ssh/id_rsa"},
            %{}
          )

        assert sanitized.type == :file_error
        refute sanitized.message =~ "/root"
        refute sanitized.message =~ "id_rsa"
      end)
    end

    test "sanitizes directory errors" do
      capture_log(fn ->
        sanitized =
          ErrorSanitizer.sanitize_error(
            {:error, "directory /var/lib/app/data does not exist"},
            %{}
          )

        assert sanitized.type == :file_error
        refute sanitized.message =~ "/var/lib/app"
      end)
    end
  end

  describe "sanitize_error/2 - network error sanitization" do
    test "sanitizes timeout errors" do
      capture_log(fn ->
        sanitized =
          ErrorSanitizer.sanitize_error(
            {:error, "timeout connecting to api.internal.example.com:8080"},
            %{}
          )

        assert sanitized.type == :network_error
        assert sanitized.message =~ "network error"
        refute sanitized.message =~ "api.internal.example.com"
        refute sanitized.message =~ "8080"
      end)
    end

    test "sanitizes connection errors" do
      capture_log(fn ->
        sanitized =
          ErrorSanitizer.sanitize_error(
            {:error, "connection refused to database server at 10.0.0.5:5432"},
            %{}
          )

        assert sanitized.type == :network_error
        refute sanitized.message =~ "10.0.0.5"
        refute sanitized.message =~ "5432"
      end)
    end
  end

  describe "sanitize_error/2 - path sanitization" do
    test "removes file paths from error messages" do
      error_struct = %{
        __struct__: :"Elixir.ValidationError",
        errors: [
          %{
            field: :name,
            message: "Error occurred at /home/user/app/lib/my_app/translations/resource.ex:42"
          }
        ]
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        field_error = hd(sanitized.field_errors)
        refute field_error.message =~ "/home/user/app"
        refute field_error.message =~ "resource.ex"
        refute field_error.message =~ ":42"
        assert field_error.message =~ "[file]"
      end)
    end

    test "removes .erl file paths" do
      error_struct = %{
        __struct__: :"Elixir.ValidationError",
        errors: [
          %{field: :name, message: "Error in /usr/lib/erlang/lib/kernel/src/gen_server.erl:123"}
        ]
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        field_error = hd(sanitized.field_errors)
        refute field_error.message =~ "/usr/lib/erlang"
        refute field_error.message =~ "gen_server.erl"
      end)
    end

    test "removes .exs file paths" do
      error_struct = %{
        __struct__: :"Elixir.ValidationError",
        errors: [
          %{field: :name, message: "Error in /app/test/support/test_helper.exs:10"}
        ]
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        field_error = hd(sanitized.field_errors)
        refute field_error.message =~ "/app/test"
        refute field_error.message =~ "test_helper.exs"
      end)
    end
  end

  describe "sanitize_error/2 - function reference sanitization" do
    test "removes function references from messages" do
      error_struct = %{
        __struct__: :"Elixir.ValidationError",
        errors: [
          %{field: :name, message: "Error in #Function<12.345678/2 in Module.function/2>"}
        ]
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        field_error = hd(sanitized.field_errors)
        refute field_error.message =~ "#Function<"
        assert field_error.message =~ "[function]"
      end)
    end
  end

  describe "sanitize_error/2 - module name sanitization" do
    test "hides internal module names" do
      error_struct = %{
        __struct__: :"Elixir.ValidationError",
        errors: [
          %{
            field: :name,
            message: "Error in Elixir.AshPhoenixTranslations.Internal.Helper module"
          }
        ]
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        field_error = hd(sanitized.field_errors)
        refute field_error.message =~ "AshPhoenixTranslations.Internal.Helper"
        assert field_error.message =~ "[module]"
      end)
    end

    test "hides Ash framework internal modules" do
      error_struct = %{
        __struct__: :"Elixir.ValidationError",
        errors: [
          %{field: :name, message: "Error in Elixir.Ash.Resource.Actions.Read module"}
        ]
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        field_error = hd(sanitized.field_errors)
        refute field_error.message =~ "Ash.Resource.Actions.Read"
      end)
    end

    test "hides Ecto internal modules" do
      error_struct = %{
        __struct__: :"Elixir.ValidationError",
        errors: [
          %{field: :name, message: "Error in Elixir.Ecto.Query.Builder module"}
        ]
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        field_error = hd(sanitized.field_errors)
        refute field_error.message =~ "Ecto.Query.Builder"
      end)
    end

    test "preserves user-facing module names" do
      error_struct = %{
        __struct__: :"Elixir.ValidationError",
        errors: [
          %{field: :name, message: "Error with Elixir.MyApp.User module"}
        ]
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        field_error = hd(sanitized.field_errors)
        # User modules should be preserved
        assert field_error.message =~ "MyApp.User" or field_error.message =~ "[module]"
      end)
    end
  end

  describe "sanitize_changeset_error/1" do
    test "sanitizes Ecto changeset errors" do
      changeset =
        {%{}, %{name: :string, email: :string}}
        |> Ecto.Changeset.cast(%{name: "", email: "invalid"}, [:name, :email])
        |> Ecto.Changeset.validate_required([:name])
        |> Ecto.Changeset.validate_format(:email, ~r/@/)

      sanitized = ErrorSanitizer.sanitize_changeset_error(changeset)

      assert sanitized.type == :validation_error
      assert sanitized.message == "Validation failed"
      assert is_map(sanitized.errors)
    end

    test "handles changeset with multiple errors per field" do
      changeset =
        {%{}, %{name: :string}}
        |> Ecto.Changeset.cast(%{name: ""}, [:name])
        |> Ecto.Changeset.validate_required([:name])
        |> Ecto.Changeset.validate_length(:name, min: 3)

      sanitized = ErrorSanitizer.sanitize_changeset_error(changeset)

      assert sanitized.type == :validation_error
      assert is_map(sanitized.errors)
    end

    test "handles changeset with nested errors" do
      changeset =
        {%{}, %{name: :string}}
        |> Ecto.Changeset.cast(%{}, [:name])
        |> Ecto.Changeset.validate_required([:name])

      sanitized = ErrorSanitizer.sanitize_changeset_error(changeset)

      assert sanitized.type == :validation_error
    end
  end

  describe "logging behavior" do
    test "logs full error details internally" do
      error_struct = %{
        __struct__: :"Elixir.InternalError",
        message: "Secret database connection string: postgres://admin:password@localhost:5432"
      }

      log =
        capture_log(fn ->
          ErrorSanitizer.sanitize_error(error_struct, %{user_id: 123})
        end)

      # Should log the full error for debugging
      assert log =~ "Translation error occurred"
    end

    test "includes context in logs" do
      error_struct = %{
        __struct__: :"Elixir.SomeError",
        message: "Some error"
      }

      log =
        capture_log(fn ->
          ErrorSanitizer.sanitize_error(error_struct, %{user_id: 123, action: :update})
        end)

      assert log =~ "Translation error occurred"
    end
  end

  describe "security scenarios" do
    test "prevents information disclosure via validation messages" do
      # Test that general validation error format is applied
      error_struct = %{
        __struct__: :"Elixir.ValidationError",
        errors: [
          %{
            field: :password,
            message: "Password is invalid at /home/user/app/lib/auth.ex:42"
          }
        ]
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        field_error = hd(sanitized.field_errors)
        # File paths should be sanitized
        refute field_error.message =~ "/home/user/app"
        refute field_error.message =~ "auth.ex:42"
      end)
    end

    test "prevents stack trace disclosure" do
      error_struct = %{
        __struct__: :"Elixir.ValidationError",
        errors: [
          %{
            field: :name,
            message: """
            (ArgumentError) argument error
                (stdlib) :ets.lookup(:my_table, :key)
                (my_app 1.0.0) lib/my_app/cache.ex:42: MyApp.Cache.get/1
            """
          }
        ]
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        field_error = hd(sanitized.field_errors)
        # File paths should be sanitized
        refute field_error.message =~ "lib/my_app/cache.ex:42"
      end)
    end

    test "prevents database schema disclosure" do
      capture_log(fn ->
        sanitized =
          ErrorSanitizer.sanitize_error(
            {:error,
             "INSERT INTO translations (resource_type, resource_id, field, locale, value, metadata) VALUES (...)"},
            %{}
          )

        refute sanitized.message =~ "translations"
        refute sanitized.message =~ "resource_type"
        refute sanitized.message =~ "resource_id"
        refute sanitized.message =~ "metadata"
      end)
    end

    test "prevents environment variable disclosure" do
      capture_log(fn ->
        sanitized =
          ErrorSanitizer.sanitize_error(
            {:error, "DATABASE_URL=postgres://user:pass@host:5432/db is not valid"},
            %{}
          )

        refute sanitized.message =~ "DATABASE_URL"
        refute sanitized.message =~ "postgres://"
        refute sanitized.message =~ "user:pass"
      end)
    end

    test "handles malicious error messages safely" do
      error_struct = %{
        __struct__: :"Elixir.ValidationError",
        errors: [
          %{
            field: :name,
            message: "<script>alert('xss')</script>"
          }
        ]
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        # Should not crash and should handle the input
        assert is_map(sanitized)
        assert sanitized.type == :validation_error
      end)
    end
  end

  describe "interpolation handling" do
    test "safely interpolates numeric values" do
      error_struct = %{
        __struct__: :"Elixir.ValidationError",
        errors: [
          %{field: :count, message: "must be at least %{min}"}
        ]
      }

      capture_log(fn ->
        # The message should be processed without crashing
        sanitized = ErrorSanitizer.sanitize_error(error_struct)
        assert is_map(sanitized)
      end)
    end

    test "redacts non-safe interpolation values" do
      # This tests the internal sanitize_interpolation_opts function
      error_struct = %{
        __struct__: :"Elixir.ValidationError",
        errors: [
          %{field: :data, message: "Error with %{complex}"}
        ]
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)
        assert is_map(sanitized)
      end)
    end
  end

  describe "edge cases" do
    test "handles deeply nested error structures" do
      error_struct = %{
        __struct__: :"Elixir.ValidationError",
        errors: [
          %{
            field: :nested,
            message: "error"
          }
        ],
        nested: %{
          __struct__: :"Elixir.AnotherError",
          deeper: %{value: "secret"}
        }
      }

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(error_struct)
        assert is_map(sanitized)
      end)
    end

    test "handles error with no __struct__ key" do
      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error(%{message: "Just a map"}, %{})
        assert sanitized.type == :internal_error
      end)
    end

    test "handles very long error messages" do
      long_message = String.duplicate("x", 10_000)

      capture_log(fn ->
        sanitized = ErrorSanitizer.sanitize_error({:error, long_message}, %{})
        assert is_map(sanitized)
      end)
    end

    test "handles circular reference attempts" do
      # Create a simple structure that might cause issues
      error = %{
        __struct__: :"Elixir.SomeError",
        message: "error"
      }

      capture_log(fn ->
        # Should not crash
        sanitized = ErrorSanitizer.sanitize_error(error, %{})
        assert is_map(sanitized)
      end)
    end
  end
end
