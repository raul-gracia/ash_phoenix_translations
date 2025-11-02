defmodule AshPhoenixTranslations.Application do
  @moduledoc """
  Supervision tree for AshPhoenixTranslations runtime components.

  This module provides a supervisor for the optional runtime components of AshPhoenixTranslations,
  including the Cache GenServer.

  ## Usage

  Add this supervisor to your application's supervision tree if you want automatic
  management of caching:

      children = [
        # ... your other children ...
        AshPhoenixTranslations.Application
      ]

      opts = [strategy: :one_for_one, name: MyApp.Supervisor]
      Supervisor.start_link(children, opts)

  ## Configuration

  Configure which components to supervise in your config files:

      config :ash_phoenix_translations,
        cache_enabled: true     # Supervise Cache GenServer

  If you don't add this to your supervision tree, you can still use the library,
  but you'll need to manually start the Cache GenServer if needed.

  ## Fault Tolerance

  The supervisor uses a `:one_for_one` strategy, meaning if one child process crashes,
  only that process will be restarted.

  ## Supervision Strategy

  - **Strategy**: `:one_for_one` - Restart only the failed child
  - **Intensity**: 3 - Maximum 3 restarts...
  - **Period**: 5 seconds - ...within 5 seconds before supervisor terminates
  """

  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Build list of children based on configuration
    children = build_children()

    # Strategy: one_for_one
    # - If a child process terminates, only that process is restarted
    #
    # Max restarts: 3 restarts within 5 seconds
    # - Prevents cascading failures
    # - If a child crashes more than 3 times in 5 seconds, the supervisor terminates
    Supervisor.init(children, strategy: :one_for_one, max_restarts: 3, max_seconds: 5)
  end

  # Build list of child specifications based on application configuration
  defp build_children do
    []
    |> maybe_add_cache()
  end

  # Add Cache GenServer if caching is enabled
  defp maybe_add_cache(children) do
    if cache_enabled?() do
      cache_spec = %{
        id: AshPhoenixTranslations.Cache,
        start: {AshPhoenixTranslations.Cache, :start_link, [[]]},
        restart: :permanent,
        shutdown: 5000,
        type: :worker
      }

      [cache_spec | children]
    else
      children
    end
  end

  # Check if caching is enabled in application configuration
  defp cache_enabled? do
    Application.get_env(:ash_phoenix_translations, :cache_enabled, false)
  end
end
