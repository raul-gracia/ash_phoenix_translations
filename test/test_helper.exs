ExUnit.start()

# The translation cache is a globally named GenServer shared across many test
# files. Start it once here, supervised by the long-lived test runner process,
# so a finishing test process can never take it down mid-run. Individual test
# setups still call Cache.start_link/0 and get the already-running instance
# back without linking to it.
{:ok, _} = Supervisor.start_link([AshPhoenixTranslations.Cache], strategy: :one_for_one)
