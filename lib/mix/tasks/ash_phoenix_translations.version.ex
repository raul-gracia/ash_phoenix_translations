defmodule Mix.Tasks.AshPhoenixTranslations.Version do
  @moduledoc """
  Version management for ash_phoenix_translations.

  ## Usage

      mix ash_phoenix_translations.version [command] [options]

  ## Commands

    * `get` - Show current version from mix.exs
    * `set VERSION` - Set specific version across all files
    * `bump TYPE` - Bump version (major|minor|patch)
    * `sync` - Synchronize version from mix.exs to all files
    * `check` - Check version consistency across files

  ## Examples

      mix ash_phoenix_translations.version get
      mix ash_phoenix_translations.version set 1.0.0
      mix ash_phoenix_translations.version bump patch
      mix ash_phoenix_translations.version sync
      mix ash_phoenix_translations.version check

  """
  @shortdoc "Manage ash_phoenix_translations version"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    case args do
      ["get"] ->
        get_version()

      ["set", version] ->
        set_version(version)

      ["bump", type] ->
        bump_version(type)

      ["sync"] ->
        sync_versions()

      ["check"] ->
        check_versions()

      _ ->
        Mix.shell().info("""
        ash_phoenix_translations version management

        Usage: mix ash_phoenix_translations.version <command> [options]

        Commands:
          get              Show current version from mix.exs
          set <version>    Set specific version across all files
          bump <type>      Bump version (major|minor|patch)
          sync             Synchronize version from mix.exs to all files
          check            Check version consistency across files

        Examples:
          mix ash_phoenix_translations.version get
          mix ash_phoenix_translations.version set 1.0.0
          mix ash_phoenix_translations.version bump patch
        """)
    end
  end

  defp get_version do
    version = Mix.Project.config()[:version]
    Mix.shell().info("Current version: #{version}")
    version
  end

  defp set_version(new_version) do
    unless valid_version?(new_version) do
      Mix.raise("Invalid version format: #{new_version}")
    end

    update_mix_exs(new_version)
    update_readme(new_version)
    update_changelog(new_version)

    Mix.shell().info([:green, "✓", :reset, " Version synchronized to #{new_version}"])
  end

  defp bump_version(type) do
    current = Mix.Project.config()[:version]
    new_version = bump_semver(current, type)

    Mix.shell().info("Bumping version from #{current} to #{new_version}")
    set_version(new_version)
  end

  defp sync_versions do
    version = Mix.Project.config()[:version]
    update_readme(version)
    update_changelog(version)

    Mix.shell().info([:green, "✓", :reset, " All files synchronized to version #{version}"])
  end

  defp check_versions do
    mix_version = Mix.Project.config()[:version]
    readme_version = extract_readme_version()

    Mix.shell().info("Checking version consistency...")
    Mix.shell().info("  mix.exs:   #{mix_version}")
    Mix.shell().info("  README.md: #{readme_version || "not found"}")

    if mix_version == readme_version do
      Mix.shell().info([:green, "✓", :reset, " Versions are synchronized"])
    else
      Mix.shell().error([:yellow, "⚠", :reset, " Version mismatch detected!"])
      Mix.shell().info("Run 'mix ash_phoenix_translations.version sync' to synchronize")
      exit({:shutdown, 1})
    end
  end

  defp update_mix_exs(version) do
    path = "mix.exs"
    content = File.read!(path)

    updated = Regex.replace(~r/version: "[^"]*"/, content, ~s(version: "#{version}"))

    File.write!(path, updated)
    Mix.shell().info([:green, "✓", :reset, " Updated mix.exs to version #{version}"])
  end

  defp update_readme(version) do
    path = "README.md"

    if File.exists?(path) do
      content = File.read!(path)

      # Update hex.pm dependency version
      updated =
        content
        |> String.replace(
          ~r/{:ash_phoenix_translations, "~> [^"]*"}/,
          ~s({:ash_phoenix_translations, "~> #{version}"})
        )
        |> String.replace(
          ~r/ash_phoenix_translations [0-9]+\.[0-9]+\.[0-9]+/,
          "ash_phoenix_translations #{version}"
        )

      File.write!(path, updated)
      Mix.shell().info([:green, "✓", :reset, " Updated README.md to version #{version}"])
    else
      Mix.shell().info([:yellow, "⚠", :reset, " README.md not found, skipping"])
    end
  end

  defp update_changelog(version) do
    path = "CHANGELOG.md"
    date = Date.utc_today() |> to_string()

    unless File.exists?(path) do
      File.write!(path, "# Changelog\n\n")
    end

    content = File.read!(path)

    if String.contains?(content, "## [#{version}]") do
      Mix.shell().info([
        :yellow,
        "⚠",
        :reset,
        " Version #{version} already exists in CHANGELOG.md"
      ])
    else
      lines = String.split(content, "\n")

      # Insert new version after the title
      updated =
        [
          Enum.at(lines, 0),
          "",
          "## [#{version}] - #{date}",
          "",
          "### Added",
          "",
          "### Changed",
          "",
          "### Fixed",
          "",
          "### Removed"
        ] ++ Enum.drop(lines, 1)

      File.write!(path, Enum.join(updated, "\n"))
      Mix.shell().info([:green, "✓", :reset, " Added version #{version} to CHANGELOG.md"])
    end
  end

  defp extract_readme_version do
    path = "README.md"

    if File.exists?(path) do
      content = File.read!(path)

      case Regex.run(~r/{:ash_phoenix_translations, "~> ([^"]*)"/, content) do
        [_, version] -> version
        _ -> nil
      end
    else
      nil
    end
  end

  defp bump_semver(version, type) do
    [major, minor, patch] =
      version
      |> String.split(".")
      |> Enum.map(&String.to_integer/1)

    case type do
      "major" ->
        "#{major + 1}.0.0"

      "minor" ->
        "#{major}.#{minor + 1}.0"

      "patch" ->
        "#{major}.#{minor}.#{patch + 1}"

      _ ->
        Mix.raise("Invalid bump type: #{type} (use major, minor, or patch)")
    end
  end

  defp valid_version?(version) do
    Regex.match?(~r/^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?(\+[a-zA-Z0-9.]+)?$/, version)
  end
end
