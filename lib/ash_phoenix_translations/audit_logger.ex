defmodule AshPhoenixTranslations.AuditLogger do
  @moduledoc """
  Security audit logging for translation operations.

  SECURITY: VULN-014 - Security audit logging

  Provides comprehensive logging for security-relevant events including:
  - Policy decisions and access control
  - Input validation failures
  - Authentication and authorization events
  - Suspicious activity detection
  """

  require Logger

  @doc """
  Logs a policy decision event.

  ## Examples

      iex> log_policy_decision(:allowed, actor, action, resource)
      :ok

      iex> log_policy_decision(:denied, actor, action, resource)
      :ok
  """
  def log_policy_decision(result, actor, action, resource, reason \\ nil) do
    details = [
      "result: #{result_status(result)}",
      "actor_id: #{inspect(get_actor_id(actor))}",
      "actor_role: #{inspect(get_actor_role(actor))}",
      "action: #{inspect(action.name)}",
      "resource: #{inspect(resource)}"
    ]

    details =
      if reason do
        ["reason: #{reason}" | Enum.reverse(details)] |> Enum.reverse()
      else
        details
      end

    Logger.info("Translation policy decision - #{Enum.join(details, ", ")}")
  end

  @doc """
  Logs a locale validation event.
  """
  def log_locale_validation(result, locale, context \\ %{}) do
    level = if match?({:ok, _}, result), do: :debug, else: :warning

    details = [
      "result: #{result_status(result)}",
      "locale: #{inspect(locale)}",
      "context: #{inspect(context)}"
    ]

    Logger.log(level, "Locale validation - #{Enum.join(details, ", ")}")
  end

  @doc """
  Logs a field validation event.
  """
  def log_field_validation(result, field, resource, context \\ %{}) do
    level = if match?({:ok, _}, result), do: :debug, else: :warning

    details = [
      "result: #{result_status(result)}",
      "field: #{inspect(field)}",
      "resource: #{inspect(resource)}",
      "context: #{inspect(context)}"
    ]

    Logger.log(level, "Field validation - #{Enum.join(details, ", ")}")
  end

  @doc """
  Logs a path validation event for file operations.
  """
  def log_path_validation(result, path, operation, context \\ %{}) do
    level = if match?({:ok, _}, result), do: :info, else: :warning

    details = [
      "result: #{result_status(result)}",
      "path: #{sanitize_path(path)}",
      "operation: #{operation}",
      "context: #{inspect(context)}"
    ]

    Logger.log(level, "Path validation - #{Enum.join(details, ", ")}")
  end

  @doc """
  Logs a cache key validation event.
  """
  def log_cache_validation(result, key, operation) do
    level = if match?({:ok, _}, result), do: :debug, else: :warning

    details = [
      "result: #{result_status(result)}",
      "key_type: #{key_type(key)}",
      "operation: #{operation}"
    ]

    Logger.log(level, "Cache key validation - #{Enum.join(details, ", ")}")
  end

  @doc """
  Logs a rate limit event.
  """
  def log_rate_limit(result, identifier, operation_type) do
    level = if match?({:ok, _}, result), do: :debug, else: :warning

    details = [
      "result: #{result_status(result)}",
      "identifier: #{sanitize_identifier(identifier)}",
      "operation_type: #{operation_type}"
    ]

    Logger.log(level, "Rate limit check - #{Enum.join(details, ", ")}")
  end

  @doc """
  Logs input validation failures.
  """
  def log_input_validation(result, input_type, value, context \\ %{}) do
    details = [
      "result: #{result_status(result)}",
      "input_type: #{input_type}",
      "value: #{sanitize_value(value)}",
      "context: #{inspect(context)}"
    ]

    Logger.warning("Input validation failed - #{Enum.join(details, ", ")}")
  end

  @doc """
  Logs suspicious activity that may indicate an attack.
  """
  def log_suspicious_activity(event_type, details_map, severity \\ :warning) do
    log_details = [
      "event_type: #{event_type}",
      "details: #{inspect(details_map)}",
      "severity: #{severity}"
    ]

    Logger.log(severity, "Suspicious activity detected - #{Enum.join(log_details, ", ")}")
  end

  @doc """
  Logs authentication events.
  """
  def log_auth_event(event_type, actor, resource, result) do
    level = if match?({:ok, _}, result), do: :info, else: :warning

    details = [
      "event_type: #{event_type}",
      "actor_id: #{get_actor_id(actor)}",
      "actor_role: #{get_actor_role(actor)}",
      "resource: #{inspect(resource)}",
      "result: #{result_status(result)}"
    ]

    Logger.log(level, "Authentication event - #{Enum.join(details, ", ")}")
  end

  @doc """
  Logs CSRF token validation events.
  """
  def log_csrf_validation(result, context \\ %{}) do
    level = if match?(:ok, result), do: :debug, else: :warning

    details = [
      "result: #{result_status(result)}",
      "context: #{inspect(context)}"
    ]

    Logger.log(level, "CSRF token validation - #{Enum.join(details, ", ")}")
  end

  # Private helper functions

  defp get_actor_id(nil), do: nil
  defp get_actor_id(actor) when is_map(actor), do: Map.get(actor, :id)
  defp get_actor_id(actor) when is_list(actor), do: Keyword.get(actor, :id)
  defp get_actor_id(_), do: nil

  defp get_actor_role(nil), do: nil
  defp get_actor_role(actor) when is_map(actor), do: Map.get(actor, :role)
  defp get_actor_role(actor) when is_list(actor), do: Keyword.get(actor, :role)
  defp get_actor_role(_), do: nil

  defp result_status({:ok, _}), do: "success"
  defp result_status({:error, _}), do: "failure"
  defp result_status(:ok), do: "success"
  defp result_status(:error), do: "failure"
  defp result_status(true), do: "allowed"
  defp result_status(false), do: "denied"
  defp result_status(other) when is_atom(other), do: Atom.to_string(other)
  defp result_status(other), do: inspect(other)

  defp sanitize_path(path) when is_binary(path) do
    # Only show relative path, not absolute to avoid leaking system info
    case String.split(path, "/") do
      parts when length(parts) > 3 ->
        ".../" <> Enum.join(Enum.take(parts, -2), "/")

      _ ->
        path
    end
  end

  defp sanitize_path(path), do: inspect(path)

  defp sanitize_identifier(identifier) when is_binary(identifier) do
    # Hash long identifiers to prevent log flooding
    if String.length(identifier) > 50 do
      hash = :crypto.hash(:sha256, identifier) |> Base.encode16() |> String.slice(0..15)
      "#{String.slice(identifier, 0..20)}...##{hash}"
    else
      identifier
    end
  end

  defp sanitize_identifier(identifier), do: inspect(identifier)

  defp sanitize_value(value) when is_binary(value) do
    # Truncate long values
    if String.length(value) > 100 do
      String.slice(value, 0..100) <> "...[truncated]"
    else
      value
    end
  end

  defp sanitize_value(value), do: inspect(value)

  defp key_type({:translation, _, _, _, _}), do: :translation
  defp key_type(key) when is_tuple(key), do: :tuple
  defp key_type(_), do: :other
end
