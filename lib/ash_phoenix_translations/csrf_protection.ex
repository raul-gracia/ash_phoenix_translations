defmodule AshPhoenixTranslations.CsrfProtection do
  @moduledoc """
  CSRF protection for translation update operations.

  SECURITY: VULN-010 - Missing CSRF protection

  Provides CSRF token validation for state-changing operations
  in translation management.
  """

  import Plug.Conn
  require Logger

  @doc """
  Plug for CSRF protection on translation update endpoints.

  Add to your router for protected routes:

      scope "/api/translations" do
        pipe_through [:api, AshPhoenixTranslations.CsrfProtection]

        post "/update", TranslationController, :update
        patch "/batch", TranslationController, :batch_update
      end
  """
  def init(opts), do: opts

  def call(conn, _opts) do
    # Skip CSRF check for safe methods
    if safe_method?(conn.method) do
      conn
    else
      verify_csrf_token(conn)
    end
  end

  @doc """
  Generates a CSRF token for a session.

  Store this token on the client side and include it in all
  state-changing requests.
  """
  def generate_token(conn) do
    token = generate_secure_token()

    conn
    |> put_session(:csrf_token, token)
    |> assign(:csrf_token, token)
  end

  @doc """
  Gets the current CSRF token from the connection.
  """
  def get_token(conn) do
    conn.assigns[:csrf_token] || get_session(conn, :csrf_token)
  end

  # Private functions

  defp safe_method?("GET"), do: true
  defp safe_method?("HEAD"), do: true
  defp safe_method?("OPTIONS"), do: true
  defp safe_method?(_), do: false

  defp verify_csrf_token(conn) do
    session_token = get_session(conn, :csrf_token)
    request_token = extract_token_from_request(conn)

    cond do
      is_nil(session_token) ->
        Logger.warning("CSRF: No session token found")
        reject_request(conn, "No CSRF session token")

      is_nil(request_token) ->
        Logger.warning("CSRF: No request token provided")
        reject_request(conn, "CSRF token required")

      not tokens_match?(session_token, request_token) ->
        Logger.warning("CSRF: Token mismatch",
          session_token_hash: hash_token(session_token),
          request_token_hash: hash_token(request_token)
        )

        reject_request(conn, "Invalid CSRF token")

      true ->
        conn
    end
  end

  defp extract_token_from_request(conn) do
    # Check multiple sources for the token
    conn.params["_csrf_token"] ||
      get_req_header(conn, "x-csrf-token") |> List.first() ||
      get_req_header(conn, "x-xsrf-token") |> List.first()
  end

  defp tokens_match?(token1, token2) do
    # Use constant-time comparison to prevent timing attacks
    :crypto.hash_equals(
      :crypto.hash(:sha256, token1),
      :crypto.hash(:sha256, token2)
    )
  end

  defp reject_request(conn, reason) do
    conn
    |> put_status(:forbidden)
    |> Phoenix.Controller.json(%{
      error: "CSRF verification failed",
      message: reason
    })
    |> halt()
  end

  defp generate_secure_token do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end

  defp hash_token(token) do
    :crypto.hash(:sha256, token)
    |> Base.encode16()
    |> String.slice(0, 8)
  end

  @doc """
  Validates CSRF token for API requests without Plug pipeline.

  Useful for programmatic validation in controllers or actions.

  ## Examples

      def update_translation(conn, params) do
        with :ok <- CsrfProtection.validate_token(conn, params["_csrf_token"]) do
          # Perform update
        else
          {:error, reason} -> {:error, :forbidden, reason}
        end
      end
  """
  def validate_token(conn, request_token) do
    session_token = get_session(conn, :csrf_token)

    cond do
      is_nil(session_token) ->
        {:error, "No CSRF session token"}

      is_nil(request_token) ->
        {:error, "CSRF token required"}

      not tokens_match?(session_token, request_token) ->
        Logger.warning("CSRF validation failed")
        {:error, "Invalid CSRF token"}

      true ->
        :ok
    end
  end

  if Code.ensure_loaded?(Phoenix.HTML.Tag) do
    # Alias within conditional block to satisfy Credo without triggering unused alias warning
    alias Phoenix.HTML.Tag

    @doc """
    Helper for including CSRF token in forms.

    In your templates:

        <%= csrf_token_tag(@conn) %>

    Note: Requires phoenix_html dependency.
    """
    def csrf_token_tag(conn) do
      token = get_token(conn)

      if token do
        Tag.tag(:input,
          type: "hidden",
          name: "_csrf_token",
          value: token
        )
      else
        Logger.warning("No CSRF token available for form")
        ""
      end
    end

    @doc """
    Helper for including CSRF token in meta tags.

    In your layout:

        <%= csrf_meta_tag(@conn) %>

    Then in JavaScript:

        const token = document.querySelector('meta[name="csrf-token"]').content
        fetch('/api/translations/update', {
          method: 'POST',
          headers: { 'X-CSRF-Token': token }
        })

    Note: Requires phoenix_html dependency.
    """
    def csrf_meta_tag(conn) do
      token = get_token(conn)

      if token do
        Tag.tag(:meta, name: "csrf-token", content: token)
      else
        ""
      end
    end
  end
end
