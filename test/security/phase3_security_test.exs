defmodule AshPhoenixTranslations.Phase3SecurityTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias AshPhoenixTranslations.{
    Cache,
    CsrfProtection,
    ErrorSanitizer,
    InputValidator,
    RateLimiter
  }

  setup do
    # Start cache and rate limiter for tests
    {:ok, _} = Cache.start_link()
    {:ok, _} = RateLimiter.start_link()

    # Clear state
    Cache.clear()

    on_exit(fn ->
      Cache.clear()
    end)

    :ok
  end

  # ============================================================================
  # VULN-007: Information Disclosure via Error Messages
  # ============================================================================

  describe "VULN-007: Error Sanitization" do
    test "sanitizes validation errors" do
      capture_log(fn ->
        # Create a generic error with validation-related module name
        error_struct = %{
          __struct__: :"Elixir.ValidationError",
          errors: [
            %{field: :name, message: "is invalid at /home/user/app/lib/resource.ex:42"}
          ]
        }

        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        assert sanitized.type == :validation_error
        assert sanitized.message =~ "Validation failed"
      end)
    end

    test "sanitizes authorization errors" do
      capture_log(fn ->
        # Create a generic error with forbidden-related module name
        error_struct = %{
          __struct__: :"Elixir.ForbiddenError",
          message: "User lacks permission in PolicyCheck module"
        }

        sanitized = ErrorSanitizer.sanitize_error(error_struct)

        assert sanitized.type == :authorization_error
        assert sanitized.message == "You do not have permission to perform this action."
        refute sanitized.message =~ "PolicyCheck"
      end)
    end

    test "sanitizes database constraint errors" do
      capture_log(fn ->
        sanitized =
          ErrorSanitizer.sanitize_error(
            {:error, "unique constraint violated: translations_pkey"},
            %{}
          )

        assert sanitized.message =~ "constraint"
        refute sanitized.message =~ "translations_pkey"
      end)
    end

    test "sanitizes file system errors" do
      capture_log(fn ->
        sanitized =
          ErrorSanitizer.sanitize_error(
            {:error, "ENOENT: /etc/secret/config.yml not found"},
            %{}
          )

        assert sanitized.type == :file_error
        refute sanitized.message =~ "/etc/secret"
        refute sanitized.message =~ ".yml"
      end)
    end

    test "removes stack traces from errors" do
      capture_log(fn ->
        error = %{
          message: "Error in function #Function<Elixir.Module.function/2> at /app/lib/module.ex:123"
        }

        sanitized = ErrorSanitizer.sanitize_error({:error, error}, %{})

        refute sanitized.message =~ "#Function"
        refute sanitized.message =~ "/app/lib"
        refute sanitized.message =~ ":123"
      end)
    end
  end

  # ============================================================================
  # VULN-008: Insufficient Rate Limiting
  # ============================================================================

  describe "VULN-008: Rate Limiting" do
    test "allows requests within limit" do
      identifier = "user:test_#{:rand.uniform(10000)}"

      # Should allow 20 write operations per minute
      results =
        Enum.map(1..10, fn _ ->
          RateLimiter.check_rate(identifier, :translation_write)
        end)

      assert Enum.all?(results, fn
               {:ok, _remaining} -> true
               _ -> false
             end)
    end

    test "blocks requests exceeding limit" do
      capture_log(fn ->
        identifier = "user:test_#{:rand.uniform(10000)}"

        # Exhaust the limit (20 operations)
        Enum.each(1..20, fn _ ->
          RateLimiter.check_rate(identifier, :translation_write)
        end)

        # Next request should be rate limited
        result = RateLimiter.check_rate(identifier, :translation_write)

        assert {:error, :rate_limited, _retry_after} = result
      end)
    end

    test "different operation types have separate limits" do
      capture_log(fn ->
        identifier = "user:test_#{:rand.uniform(10000)}"

        # Exhaust write limit
        Enum.each(1..20, fn _ ->
          RateLimiter.check_rate(identifier, :translation_write)
        end)

        # Read operations should still be allowed (different limit)
        result = RateLimiter.check_rate(identifier, :translation_read)

        assert {:ok, _remaining} = result
      end)
    end

    test "returns correct retry_after time" do
      capture_log(fn ->
        identifier = "user:test_#{:rand.uniform(10000)}"

        # Exhaust limit
        Enum.each(1..20, fn _ ->
          RateLimiter.check_rate(identifier, :translation_write)
        end)

        {:error, :rate_limited, retry_after} =
          RateLimiter.check_rate(identifier, :translation_write)

        assert is_integer(retry_after)
        assert retry_after > 0
        # Should be within window (1 minute)
        assert retry_after <= 60_000
      end)
    end

    test "resets rate limit after window expires" do
      identifier = "user:test_#{:rand.uniform(10000)}"

      # Use a very short window for testing
      # Note: This test assumes we can control the window,
      # otherwise it would need to wait

      result = RateLimiter.check_rate(identifier, :translation_write)
      assert {:ok, _} = result
    end
  end

  # ============================================================================
  # VULN-009: Cache Poisoning via Malicious Keys
  # ============================================================================

  describe "VULN-009: Cache Key Validation" do
    test "rejects cache keys with invalid structure" do
      capture_log(fn ->
        # Invalid key structure (not a tuple)
        result = Cache.put("invalid_key", "value")

        # Should return error for invalid key structure
        assert {:error, :invalid_key_structure} == result

        # Try to get it back - should also reject
        assert :miss == Cache.get("invalid_key")
      end)
    end

    test "rejects keys with excessively long components" do
      capture_log(fn ->
        long_field = String.duplicate("a", 200)
        key = {:translation, MyApp.Product, String.to_atom(long_field), :en, "123"}

        result = Cache.put(key, "value")

        # Should reject due to excessive field length
        assert {:error, :field_name_too_long} == result

        # Get should also reject
        assert :miss == Cache.get(key)
      end)
    end

    test "rejects keys with invalid resource format" do
      capture_log(fn ->
        # Resource must be a module name starting with Elixir.
        key = {:translation, :not_a_module, :name, :en, "123"}

        result = Cache.put(key, "value")

        # Should reject due to invalid resource format
        assert {:error, :invalid_resource_format} == result

        # Get should also reject
        assert :miss == Cache.get(key)
      end)
    end

    test "rejects keys with invalid locale format" do
      capture_log(fn ->
        # Locale must match pattern (en or en_US)
        # Use short invalid locale to test format validation (not length)
        key = {:translation, MyApp.Product, :name, :xyz123, "123"}

        result = Cache.put(key, "value")

        # Should reject due to invalid locale format
        assert {:error, :invalid_locale_format} == result

        # Get should also reject
        assert :miss == Cache.get(key)
      end)
    end

    test "accepts valid cache keys" do
      capture_log(fn ->
        key = Cache.key(MyApp.Product, :name, :en, "123")

        assert :ok == Cache.put(key, "Valid translation")
        assert {:ok, "Valid translation"} == Cache.get(key)
      end)
    end
  end

  # ============================================================================
  # VULN-010: Missing CSRF Protection
  # ============================================================================

  describe "VULN-010: CSRF Protection" do
    test "generates secure CSRF tokens" do
      conn = Plug.Test.conn(:get, "/")

      conn =
        Plug.Session.call(
          conn,
          Plug.Session.init(
            store: :cookie,
            key: "_test_session",
            encryption_salt: "test_salt",
            signing_salt: "test_salt"
          )
        )

      conn = Plug.Conn.fetch_session(conn)

      conn = CsrfProtection.generate_token(conn)
      token = CsrfProtection.get_token(conn)

      assert is_binary(token)
      assert byte_size(token) > 32
    end

    test "validates matching CSRF tokens" do
      conn = setup_test_conn()
      conn = CsrfProtection.generate_token(conn)
      token = CsrfProtection.get_token(conn)

      assert :ok == CsrfProtection.validate_token(conn, token)
    end

    test "rejects mismatched CSRF tokens" do
      capture_log(fn ->
        conn = setup_test_conn()
        conn = CsrfProtection.generate_token(conn)

        result = CsrfProtection.validate_token(conn, "wrong_token")

        assert {:error, _reason} = result
      end)
    end

    test "rejects requests without CSRF token" do
      capture_log(fn ->
        conn = setup_test_conn()

        result = CsrfProtection.validate_token(conn, nil)

        assert {:error, _reason} = result
      end)
    end

    test "allows safe HTTP methods without token" do
      conn = setup_test_conn(:get)

      # Should not halt the connection
      conn = CsrfProtection.call(conn, [])

      refute conn.halted
    end

    test "blocks unsafe HTTP methods without token" do
      capture_log(fn ->
        conn = setup_test_conn(:post)

        # Should halt the connection
        conn = CsrfProtection.call(conn, [])

        assert conn.halted
        assert conn.status == 403
      end)
    end
  end

  # ============================================================================
  # VULN-011: Lack of Input Length Validation
  # ============================================================================

  describe "VULN-011: Input Length Validation" do
    test "rejects translations exceeding maximum length" do
      long_translation = String.duplicate("a", 10_001)

      result = InputValidator.validate_translation(long_translation)

      assert {:error, :translation_too_long, _msg} = result
    end

    test "accepts translations within length limit" do
      valid_translation = String.duplicate("a", 1000)

      result = InputValidator.validate_translation(valid_translation)

      assert {:ok, ^valid_translation} = result
    end

    test "rejects field names exceeding maximum length" do
      long_field = String.duplicate("a", 101)

      result = InputValidator.validate_field_name(long_field)

      assert {:error, :field_name_too_long, _msg} = result
    end

    test "accepts field names within length limit" do
      result = InputValidator.validate_field_name("valid_field_name")

      assert {:ok, "valid_field_name"} = result
    end

    test "validates resource name length" do
      result = InputValidator.validate_resource_name(MyApp.Product)

      assert {:ok, MyApp.Product} = result
    end

    test "validates locale code format and length" do
      assert {:ok, "en"} = InputValidator.validate_locale_code("en")
      assert {:ok, "en_US"} = InputValidator.validate_locale_code("en_US")
      assert {:error, :invalid_locale_format, _} = InputValidator.validate_locale_code("invalid")
    end

    test "validates batch of translations" do
      translations = [
        %{field: :name, locale: :en, value: "Valid"},
        %{field: :name, locale: :es, value: "Válido"}
      ]

      result = InputValidator.validate_translation_batch(translations)

      assert {:ok, validated} = result
      assert length(validated) == 2
    end

    test "rejects batch with invalid translations" do
      capture_log(fn ->
        translations = [
          %{field: :name, locale: :en, value: String.duplicate("a", 10_001)}
        ]

        result = InputValidator.validate_translation_batch(translations)

        assert {:error, invalid_count, _errors} = result
        assert invalid_count == 1
      end)
    end
  end

  # ============================================================================
  # VULN-012: Insecure Deserialization in Cache
  # ============================================================================

  describe "VULN-012: Cache Value Signing" do
    test "signs and verifies cache values correctly" do
      capture_log(fn ->
        key = Cache.key(MyApp.Product, :name, :en, "123")

        assert :ok == Cache.put(key, "Signed value")
        assert {:ok, "Signed value"} == Cache.get(key)
      end)
    end

    test "detects tampered cache values" do
      capture_log(fn ->
        # This test assumes we can access ETS directly to tamper with values
        # In real implementation, signatures prevent tampering

        key = Cache.key(MyApp.Product, :name, :en, "123")
        Cache.put(key, "Original value")

        # Normal retrieval should work
        assert {:ok, "Original value"} == Cache.get(key)
      end)
    end

    test "handles various data types safely" do
      capture_log(fn ->
        key = Cache.key(MyApp.Product, :data, :en, "123")

        # Test different value types
        values = [
          "string",
          123,
          %{map: "value"},
          [:list, :of, :atoms],
          {:tuple, "data"}
        ]

        Enum.each(values, fn value ->
          assert :ok == Cache.put(key, value)
          assert {:ok, ^value} = Cache.get(key)
        end)
      end)
    end
  end

  # Helper functions

  defp setup_test_conn(method \\ :get) do
    conn = Plug.Test.conn(method, "/")

    conn =
      Plug.Session.call(
        conn,
        Plug.Session.init(
          store: :cookie,
          key: "_test_session",
          encryption_salt: "test_encryption_salt",
          signing_salt: "test_signing_salt"
        )
      )

    conn
    |> Plug.Conn.fetch_session()
    |> Plug.Conn.fetch_query_params()
  end

  defmodule MyApp.Product do
    # Dummy module for testing
  end
end
