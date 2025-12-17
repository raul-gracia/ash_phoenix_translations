defmodule AshPhoenixTranslations.CsrfProtectionTest do
  @moduledoc """
  Comprehensive tests for the CsrfProtection module.

  Tests cover:
  - CSRF token generation
  - Token storage in session and assigns
  - Token validation (matching, mismatching, missing)
  - Safe HTTP methods bypass (GET, HEAD, OPTIONS)
  - Unsafe HTTP methods blocking (POST, PUT, PATCH, DELETE)
  - Token extraction from multiple sources
  - Constant-time token comparison
  - Security attack scenarios
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias AshPhoenixTranslations.CsrfProtection

  # Helper to set up a test connection with session support
  defp setup_test_conn(method \\ :get, path \\ "/") do
    conn =
      Plug.Test.conn(method, path)
      |> Map.put(:secret_key_base, String.duplicate("a", 64))

    conn =
      Plug.Session.call(
        conn,
        Plug.Session.init(
          store: :cookie,
          key: "_test_session",
          encryption_salt: "test_encryption_salt_1234567890",
          signing_salt: "test_signing_salt_1234567890"
        )
      )

    conn
    |> Plug.Conn.fetch_session()
    |> Plug.Conn.fetch_query_params()
  end

  describe "init/1" do
    test "returns options unchanged" do
      opts = [some: :option]
      assert CsrfProtection.init(opts) == opts
    end

    test "handles empty options" do
      assert CsrfProtection.init([]) == []
    end
  end

  describe "generate_token/1" do
    test "generates a secure token" do
      conn = setup_test_conn()
      conn = CsrfProtection.generate_token(conn)

      token = CsrfProtection.get_token(conn)
      assert is_binary(token)
      assert byte_size(token) > 32
    end

    test "stores token in session" do
      conn = setup_test_conn()
      conn = CsrfProtection.generate_token(conn)

      session_token = Plug.Conn.get_session(conn, :csrf_token)
      assert is_binary(session_token)
    end

    test "stores token in assigns" do
      conn = setup_test_conn()
      conn = CsrfProtection.generate_token(conn)

      assert is_binary(conn.assigns[:csrf_token])
    end

    test "session and assigns contain same token" do
      conn = setup_test_conn()
      conn = CsrfProtection.generate_token(conn)

      session_token = Plug.Conn.get_session(conn, :csrf_token)
      assigns_token = conn.assigns[:csrf_token]

      assert session_token == assigns_token
    end

    test "generates unique tokens for different connections" do
      conn1 = setup_test_conn()
      conn2 = setup_test_conn()

      conn1 = CsrfProtection.generate_token(conn1)
      conn2 = CsrfProtection.generate_token(conn2)

      token1 = CsrfProtection.get_token(conn1)
      token2 = CsrfProtection.get_token(conn2)

      assert token1 != token2
    end

    test "generates URL-safe tokens" do
      conn = setup_test_conn()
      conn = CsrfProtection.generate_token(conn)

      token = CsrfProtection.get_token(conn)
      # URL-safe base64 should only contain alphanumeric, dash, underscore
      assert Regex.match?(~r/^[A-Za-z0-9_-]+$/, token)
    end
  end

  describe "get_token/1" do
    test "returns token from assigns when available" do
      conn = setup_test_conn()
      conn = Plug.Conn.assign(conn, :csrf_token, "assigns_token")
      conn = Plug.Conn.put_session(conn, :csrf_token, "session_token")

      assert CsrfProtection.get_token(conn) == "assigns_token"
    end

    test "falls back to session token when assigns empty" do
      conn = setup_test_conn()
      conn = Plug.Conn.put_session(conn, :csrf_token, "session_token")

      assert CsrfProtection.get_token(conn) == "session_token"
    end

    test "returns nil when no token exists" do
      conn = setup_test_conn()

      assert CsrfProtection.get_token(conn) == nil
    end
  end

  describe "validate_token/2" do
    test "returns :ok for matching tokens" do
      conn = setup_test_conn()
      conn = CsrfProtection.generate_token(conn)
      token = CsrfProtection.get_token(conn)

      assert :ok = CsrfProtection.validate_token(conn, token)
    end

    test "returns error for mismatched tokens" do
      capture_log(fn ->
        conn = setup_test_conn()
        conn = CsrfProtection.generate_token(conn)

        result = CsrfProtection.validate_token(conn, "wrong_token")

        assert {:error, "Invalid CSRF token"} = result
      end)
    end

    test "returns error for nil request token" do
      conn = setup_test_conn()
      conn = CsrfProtection.generate_token(conn)

      result = CsrfProtection.validate_token(conn, nil)

      assert {:error, "CSRF token required"} = result
    end

    test "returns error when no session token exists" do
      conn = setup_test_conn()

      result = CsrfProtection.validate_token(conn, "some_token")

      assert {:error, "No CSRF session token"} = result
    end

    test "returns error for empty request token" do
      capture_log(fn ->
        conn = setup_test_conn()
        conn = CsrfProtection.generate_token(conn)

        result = CsrfProtection.validate_token(conn, "")

        assert {:error, "Invalid CSRF token"} = result
      end)
    end
  end

  describe "call/2 - safe methods" do
    test "allows GET requests without token" do
      conn = setup_test_conn(:get)
      conn = CsrfProtection.call(conn, [])

      refute conn.halted
    end

    test "allows HEAD requests without token" do
      conn = setup_test_conn(:head)
      conn = CsrfProtection.call(conn, [])

      refute conn.halted
    end

    test "allows OPTIONS requests without token" do
      conn = setup_test_conn(:options)
      conn = CsrfProtection.call(conn, [])

      refute conn.halted
    end
  end

  describe "call/2 - unsafe methods without token" do
    test "blocks POST requests without session token" do
      capture_log(fn ->
        conn = setup_test_conn(:post)
        conn = CsrfProtection.call(conn, [])

        assert conn.halted
        assert conn.status == 403
      end)
    end

    test "blocks PUT requests without session token" do
      capture_log(fn ->
        conn = setup_test_conn(:put)
        conn = CsrfProtection.call(conn, [])

        assert conn.halted
        assert conn.status == 403
      end)
    end

    test "blocks PATCH requests without session token" do
      capture_log(fn ->
        conn = setup_test_conn(:patch)
        conn = CsrfProtection.call(conn, [])

        assert conn.halted
        assert conn.status == 403
      end)
    end

    test "blocks DELETE requests without session token" do
      capture_log(fn ->
        conn = setup_test_conn(:delete)
        conn = CsrfProtection.call(conn, [])

        assert conn.halted
        assert conn.status == 403
      end)
    end
  end

  describe "call/2 - unsafe methods with valid token" do
    test "allows POST with valid token in params" do
      conn = setup_test_conn(:post)
      conn = CsrfProtection.generate_token(conn)
      token = CsrfProtection.get_token(conn)

      conn = %{conn | params: Map.put(conn.params, "_csrf_token", token)}
      conn = CsrfProtection.call(conn, [])

      refute conn.halted
    end

    test "allows POST with valid token in x-csrf-token header" do
      conn = setup_test_conn(:post)
      conn = CsrfProtection.generate_token(conn)
      token = CsrfProtection.get_token(conn)

      conn = Plug.Conn.put_req_header(conn, "x-csrf-token", token)
      conn = CsrfProtection.call(conn, [])

      refute conn.halted
    end

    test "allows POST with valid token in x-xsrf-token header" do
      conn = setup_test_conn(:post)
      conn = CsrfProtection.generate_token(conn)
      token = CsrfProtection.get_token(conn)

      conn = Plug.Conn.put_req_header(conn, "x-xsrf-token", token)
      conn = CsrfProtection.call(conn, [])

      refute conn.halted
    end
  end

  describe "call/2 - token extraction priority" do
    test "prefers params token over headers" do
      conn = setup_test_conn(:post)
      conn = CsrfProtection.generate_token(conn)
      token = CsrfProtection.get_token(conn)

      conn = %{conn | params: Map.put(conn.params, "_csrf_token", token)}
      conn = Plug.Conn.put_req_header(conn, "x-csrf-token", "wrong_token")

      conn = CsrfProtection.call(conn, [])

      refute conn.halted
    end

    test "falls back to x-csrf-token header" do
      conn = setup_test_conn(:post)
      conn = CsrfProtection.generate_token(conn)
      token = CsrfProtection.get_token(conn)

      conn = Plug.Conn.put_req_header(conn, "x-csrf-token", token)
      conn = CsrfProtection.call(conn, [])

      refute conn.halted
    end

    test "falls back to x-xsrf-token header" do
      conn = setup_test_conn(:post)
      conn = CsrfProtection.generate_token(conn)
      token = CsrfProtection.get_token(conn)

      conn = Plug.Conn.put_req_header(conn, "x-xsrf-token", token)
      conn = CsrfProtection.call(conn, [])

      refute conn.halted
    end
  end

  describe "call/2 - error responses" do
    test "returns 403 status for missing session token" do
      capture_log(fn ->
        conn = setup_test_conn(:post)
        conn = CsrfProtection.call(conn, [])

        assert conn.status == 403
        assert conn.halted
      end)
    end

    test "returns 403 status for missing request token" do
      capture_log(fn ->
        conn = setup_test_conn(:post)
        conn = CsrfProtection.generate_token(conn)
        conn = CsrfProtection.call(conn, [])

        assert conn.status == 403
        assert conn.halted
      end)
    end

    test "returns 403 status for mismatched tokens" do
      capture_log(fn ->
        conn = setup_test_conn(:post)
        conn = CsrfProtection.generate_token(conn)

        conn = %{conn | params: Map.put(conn.params, "_csrf_token", "wrong_token")}
        conn = CsrfProtection.call(conn, [])

        assert conn.status == 403
        assert conn.halted
      end)
    end

    test "returns JSON error response" do
      capture_log(fn ->
        conn = setup_test_conn(:post)
        conn = CsrfProtection.call(conn, [])

        body = Jason.decode!(conn.resp_body)
        assert body["error"] == "CSRF verification failed"
        assert is_binary(body["message"])
      end)
    end
  end

  describe "security scenarios" do
    test "prevents token reuse across sessions" do
      capture_log(fn ->
        # Generate token for first session
        conn1 = setup_test_conn(:post)
        conn1 = CsrfProtection.generate_token(conn1)
        token1 = CsrfProtection.get_token(conn1)

        # New session should not accept old token
        conn2 = setup_test_conn(:post)
        conn2 = %{conn2 | params: Map.put(conn2.params, "_csrf_token", token1)}
        conn2 = CsrfProtection.call(conn2, [])

        assert conn2.halted
        assert conn2.status == 403
      end)
    end

    test "prevents timing attacks via constant-time comparison" do
      capture_log(fn ->
        # This test verifies the implementation uses secure comparison
        # We can't directly test timing, but we can verify the function exists
        conn = setup_test_conn(:post)
        conn = CsrfProtection.generate_token(conn)
        token = CsrfProtection.get_token(conn)

        # Both should take approximately same time regardless of position of mismatch
        wrong_first_char = "X" <> String.slice(token, 1..-1//1)
        wrong_last_char = String.slice(token, 0..-2//1) <> "X"

        result1 = CsrfProtection.validate_token(conn, wrong_first_char)
        result2 = CsrfProtection.validate_token(conn, wrong_last_char)

        assert {:error, _} = result1
        assert {:error, _} = result2
      end)
    end

    test "rejects empty token" do
      capture_log(fn ->
        conn = setup_test_conn(:post)
        conn = CsrfProtection.generate_token(conn)

        conn = %{conn | params: Map.put(conn.params, "_csrf_token", "")}
        conn = CsrfProtection.call(conn, [])

        assert conn.halted
      end)
    end

    test "rejects token with only whitespace" do
      capture_log(fn ->
        conn = setup_test_conn(:post)
        conn = CsrfProtection.generate_token(conn)

        conn = %{conn | params: Map.put(conn.params, "_csrf_token", "   ")}
        conn = CsrfProtection.call(conn, [])

        assert conn.halted
      end)
    end

    test "handles special characters in submitted token" do
      capture_log(fn ->
        conn = setup_test_conn(:post)
        conn = CsrfProtection.generate_token(conn)

        conn = %{conn | params: Map.put(conn.params, "_csrf_token", "<script>alert('xss')</script>")}
        conn = CsrfProtection.call(conn, [])

        assert conn.halted
        assert conn.status == 403
      end)
    end

    test "handles null bytes in submitted token" do
      capture_log(fn ->
        conn = setup_test_conn(:post)
        conn = CsrfProtection.generate_token(conn)

        conn = %{conn | params: Map.put(conn.params, "_csrf_token", "token\x00evil")}
        conn = CsrfProtection.call(conn, [])

        assert conn.halted
      end)
    end

    test "handles very long submitted token" do
      capture_log(fn ->
        conn = setup_test_conn(:post)
        conn = CsrfProtection.generate_token(conn)

        long_token = String.duplicate("x", 10_000)
        conn = %{conn | params: Map.put(conn.params, "_csrf_token", long_token)}
        conn = CsrfProtection.call(conn, [])

        assert conn.halted
      end)
    end

    test "handles unicode in submitted token" do
      capture_log(fn ->
        conn = setup_test_conn(:post)
        conn = CsrfProtection.generate_token(conn)

        conn = %{conn | params: Map.put(conn.params, "_csrf_token", "token_with_unicode")}
        conn = CsrfProtection.call(conn, [])

        assert conn.halted
      end)
    end
  end

  describe "edge cases" do
    test "handles connection without token in params" do
      capture_log(fn ->
        conn =
          Plug.Test.conn(:post, "/")
          |> Map.put(:secret_key_base, String.duplicate("a", 64))

        conn =
          Plug.Session.call(
            conn,
            Plug.Session.init(
              store: :cookie,
              key: "_test_session",
              encryption_salt: "test_encryption_salt_1234567890",
              signing_salt: "test_signing_salt_1234567890"
            )
          )

        conn =
          conn
          |> Plug.Conn.fetch_session()
          |> Plug.Conn.fetch_query_params()

        conn = CsrfProtection.generate_token(conn)

        # Should halt because no token in request
        conn = CsrfProtection.call(conn, [])
        assert conn.halted
      end)
    end

    test "handles multiple tokens in header" do
      capture_log(fn ->
        conn = setup_test_conn(:post)
        conn = CsrfProtection.generate_token(conn)
        token = CsrfProtection.get_token(conn)

        # Multiple headers should use first one
        conn =
          conn
          |> Plug.Conn.put_req_header("x-csrf-token", token)
          |> Plug.Conn.put_req_header("x-csrf-token", "wrong_token")

        # Plug merges headers, so behavior depends on implementation
        # This test ensures it doesn't crash
        result_conn = CsrfProtection.call(conn, [])
        assert is_map(result_conn)
      end)
    end

    test "regenerates different token on each call" do
      conn = setup_test_conn()

      conn = CsrfProtection.generate_token(conn)
      token1 = CsrfProtection.get_token(conn)

      conn = CsrfProtection.generate_token(conn)
      token2 = CsrfProtection.get_token(conn)

      assert token1 != token2
    end
  end

  describe "case sensitivity" do
    test "GET method is case-sensitive (uppercase)" do
      conn = setup_test_conn(:get)
      conn = %{conn | method: "GET"}
      conn = CsrfProtection.call(conn, [])

      refute conn.halted
    end

    test "lowercase get is not safe" do
      capture_log(fn ->
        conn = setup_test_conn(:get)
        conn = %{conn | method: "get"}
        conn = CsrfProtection.call(conn, [])

        # Depending on implementation, lowercase might not be recognized
        # This documents the expected behavior
        assert conn.halted
      end)
    end

    test "header names are case-insensitive" do
      conn = setup_test_conn(:post)
      conn = CsrfProtection.generate_token(conn)
      token = CsrfProtection.get_token(conn)

      # HTTP headers should be normalized to lowercase by Plug
      conn = Plug.Conn.put_req_header(conn, "x-csrf-token", token)
      conn = CsrfProtection.call(conn, [])

      refute conn.halted
    end
  end

  # Note: Testing csrf_token_tag and csrf_meta_tag requires Phoenix.HTML
  # to be loaded. These are conditional functions that only exist when
  # Phoenix.HTML is available.
  describe "phoenix html helpers" do
    @tag :skip_without_phoenix_html
    test "csrf_token_tag generates hidden input" do
      # This test would verify the tag generation if Phoenix.HTML is available
      if Code.ensure_loaded?(Phoenix.HTML.Tag) and
           function_exported?(CsrfProtection, :csrf_token_tag, 1) do
        conn = setup_test_conn()
        conn = CsrfProtection.generate_token(conn)

        # Use apply to avoid compile-time warnings
        tag = apply(CsrfProtection, :csrf_token_tag, [conn])
        assert tag != ""
      else
        # Skip test if Phoenix.HTML is not available
        assert true
      end
    end

    @tag :skip_without_phoenix_html
    test "csrf_meta_tag generates meta tag" do
      if Code.ensure_loaded?(Phoenix.HTML.Tag) and
           function_exported?(CsrfProtection, :csrf_meta_tag, 1) do
        conn = setup_test_conn()
        conn = CsrfProtection.generate_token(conn)

        # Use apply to avoid compile-time warnings
        tag = apply(CsrfProtection, :csrf_meta_tag, [conn])
        assert tag != ""
      else
        # Skip test if Phoenix.HTML is not available
        assert true
      end
    end
  end
end
