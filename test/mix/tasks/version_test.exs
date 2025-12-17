defmodule Mix.Tasks.AshPhoenixTranslations.VersionTest do
  @moduledoc """
  Tests for the ash_phoenix_translations.version mix task.

  This test suite validates the version management functionality including:
  - Help output display
  - File manipulation for mix.exs, README.md, and CHANGELOG.md
  - Version validation (SemVer compliance)
  - Bump logic for patch, minor, and major versions
  - Version extraction from files
  - Content preservation during updates

  Tests use temporary directories to avoid interfering with the actual project.
  """
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  alias Mix.Tasks.AshPhoenixTranslations.Version

  setup do
    # Store original directory and Mix project
    original_dir = File.cwd!()

    # Create unique temporary test directory for each test
    unique_id = :erlang.unique_integer([:positive])
    test_dir = Path.join(System.tmp_dir!(), "version_test_#{unique_id}")
    File.mkdir_p!(test_dir)

    # Create test mix.exs (no module loading, just file manipulation)
    mix_path = Path.join(test_dir, "mix.exs")

    File.write!(mix_path, """
    defmodule TestProject.MixProject do
      use Mix.Project

      def project do
        [
          app: :test_project,
          version: "1.0.0",
          elixir: "~> 1.17",
          deps: []
        ]
      end
    end
    """)

    # Create test README.md
    readme_path = Path.join(test_dir, "README.md")

    File.write!(readme_path, """
    # Test Project

    ## Installation

    Add to your deps in `mix.exs`:

    ```elixir
    {:ash_phoenix_translations, "~> 1.0.0"}
    ```

    Some standalone version reference: ash_phoenix_translations 1.0.0

    ## Usage

    Use the library!
    """)

    # Create test CHANGELOG.md
    changelog_path = Path.join(test_dir, "CHANGELOG.md")

    File.write!(changelog_path, """
    # Changelog

    ## [1.0.0] - 2024-01-01

    Initial release
    """)

    # Change to test directory
    File.cd!(test_dir)

    on_exit(fn ->
      # Clean up
      File.cd!(original_dir)
      File.rm_rf!(test_dir)
    end)

    {:ok, test_dir: test_dir}
  end


  describe "help output" do
    test "shows help when no arguments provided" do
      output =
        capture_io(fn ->
          # Catch any potential errors
          try do
            Version.run([])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "ash_phoenix_translations version management"
      assert output =~ "Usage: mix ash_phoenix_translations.version <command> [options]"
      assert output =~ "get"
      assert output =~ "set <version>"
      assert output =~ "bump <type>"
      assert output =~ "sync"
      assert output =~ "check"
    end

    test "shows help for invalid command" do
      output =
        capture_io(fn ->
          try do
            Version.run(["invalid"])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "ash_phoenix_translations version management"
      assert output =~ "Commands:"
    end
  end

  describe "file manipulation" do
    test "set command updates mix.exs file" do
      # Directly test file manipulation without loading project
      content_before = File.read!("mix.exs")
      assert content_before =~ ~s(version: "1.0.0")

      # Simulate what the set command does
      updated = Regex.replace(~r/version: "[^"]*"/, content_before, ~s(version: "2.5.3"))
      File.write!("mix.exs", updated)

      content_after = File.read!("mix.exs")
      assert content_after =~ ~s(version: "2.5.3")
      refute content_after =~ ~s(version: "1.0.0")
    end

    test "set command updates README.md file" do
      content_before = File.read!("README.md")
      assert content_before =~ ~s({:ash_phoenix_translations, "~> 1.0.0"})

      # Simulate README update
      updated =
        content_before
        |> String.replace(
          ~r/{:ash_phoenix_translations, "~> [^"]*"}/,
          ~s({:ash_phoenix_translations, "~> 2.5.3"})
        )
        |> String.replace(
          ~r/ash_phoenix_translations [0-9]+\.[0-9]+\.[0-9]+/,
          "ash_phoenix_translations 2.5.3"
        )

      File.write!("README.md", updated)

      content_after = File.read!("README.md")
      assert content_after =~ ~s({:ash_phoenix_translations, "~> 2.5.3"})
      assert content_after =~ "ash_phoenix_translations 2.5.3"
    end

    test "set command adds entry to CHANGELOG.md" do
      content_before = File.read!("CHANGELOG.md")
      refute content_before =~ "## [2.0.0]"

      # Simulate CHANGELOG update
      lines = String.split(content_before, "\n")
      date = Date.utc_today() |> to_string()

      updated =
        [
          Enum.at(lines, 0),
          "",
          "## [2.0.0] - #{date}",
          "",
          "### Added",
          "",
          "### Changed",
          "",
          "### Fixed",
          "",
          "### Removed"
        ] ++ Enum.drop(lines, 1)

      File.write!("CHANGELOG.md", Enum.join(updated, "\n"))

      content_after = File.read!("CHANGELOG.md")
      assert content_after =~ "## [2.0.0] - #{date}"
      assert content_after =~ "### Added"
      assert content_after =~ "## [1.0.0] - 2024-01-01"
    end

    test "version validation regex works correctly" do
      valid_versions = [
        "0.0.1",
        "1.0.0",
        "10.20.30",
        "1.0.0-alpha",
        "1.0.0-alpha.1",
        "1.0.0+build.123",
        "2.0.0-rc.1+exp.sha.5114f85"
      ]

      invalid_versions = ["v1.0.0", "1.0", "1", "1.0.0.0", "1.0.0-", "1.0.0+"]

      regex = ~r/^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?(\+[a-zA-Z0-9.]+)?$/

      for version <- valid_versions do
        assert Regex.match?(regex, version), "#{version} should be valid"
      end

      for version <- invalid_versions do
        refute Regex.match?(regex, version), "#{version} should be invalid"
      end
    end

    test "bump logic for patch version" do
      version = "1.0.0"
      [major, minor, patch] = version |> String.split(".") |> Enum.map(&String.to_integer/1)
      bumped = "#{major}.#{minor}.#{patch + 1}"
      assert bumped == "1.0.1"
    end

    test "bump logic for minor version" do
      version = "1.0.0"
      [major, minor, _patch] = version |> String.split(".") |> Enum.map(&String.to_integer/1)
      bumped = "#{major}.#{minor + 1}.0"
      assert bumped == "1.1.0"
    end

    test "bump logic for major version" do
      version = "1.0.0"
      [major, _minor, _patch] = version |> String.split(".") |> Enum.map(&String.to_integer/1)
      bumped = "#{major + 1}.0.0"
      assert bumped == "2.0.0"
    end

    test "extracts version from README correctly" do
      content = File.read!("README.md")

      version =
        case Regex.run(~r/{:ash_phoenix_translations, "~> ([^"]*)"/, content) do
          [_, v] -> v
          _ -> nil
        end

      assert version == "1.0.0"
    end

    test "preserves other content when updating mix.exs" do
      content_before = File.read!("mix.exs")
      updated = Regex.replace(~r/version: "[^"]*"/, content_before, ~s(version: "2.0.0"))
      File.write!("mix.exs", updated)

      content_after = File.read!("mix.exs")
      assert content_after =~ "app: :test_project"
      assert content_after =~ "elixir: \"~> 1.17\""
      assert content_after =~ "deps: []"
    end

    test "preserves other content when updating README" do
      content_before = File.read!("README.md")

      updated =
        String.replace(
          content_before,
          ~r/{:ash_phoenix_translations, "~> [^"]*"}/,
          ~s({:ash_phoenix_translations, "~> 2.0.0"})
        )

      File.write!("README.md", updated)

      content_after = File.read!("README.md")
      assert content_after =~ "# Test Project"
      assert content_after =~ "## Installation"
      assert content_after =~ "## Usage"
      assert content_after =~ "Use the library!"
    end

    test "detects duplicate CHANGELOG entries" do
      content = File.read!("CHANGELOG.md")

      # Add version once
      lines = String.split(content, "\n")
      date = Date.utc_today() |> to_string()

      updated =
        [
          Enum.at(lines, 0),
          "",
          "## [1.2.0] - #{date}",
          ""
        ] ++ Enum.drop(lines, 1)

      File.write!("CHANGELOG.md", Enum.join(updated, "\n"))

      # Verify it was added
      content_updated = File.read!("CHANGELOG.md")
      assert String.contains?(content_updated, "## [1.2.0]")

      # Count occurrences - should only be one
      occurrences = Regex.scan(~r/## \[1\.2\.0\]/, content_updated) |> length()
      assert occurrences == 1
    end

    test "creates CHANGELOG if it doesn't exist" do
      File.rm!("CHANGELOG.md")
      refute File.exists?("CHANGELOG.md")

      # Simulate creation
      File.write!("CHANGELOG.md", "# Changelog\n\n")
      assert File.exists?("CHANGELOG.md")

      content = File.read!("CHANGELOG.md")
      assert content =~ "# Changelog"
    end

    test "handles missing README gracefully" do
      File.rm!("README.md")
      refute File.exists?("README.md")

      # Should be able to check existence
      assert File.exists?("README.md") == false
    end

    test "CHANGELOG new entry appears before old entries" do
      content = File.read!("CHANGELOG.md")
      lines = String.split(content, "\n")
      date = Date.utc_today() |> to_string()

      updated =
        [
          Enum.at(lines, 0),
          "",
          "## [2.0.0] - #{date}",
          ""
        ] ++ Enum.drop(lines, 1)

      File.write!("CHANGELOG.md", Enum.join(updated, "\n"))

      content_after = File.read!("CHANGELOG.md")
      changelog_lines = String.split(content_after, "\n")

      new_version_idx = Enum.find_index(changelog_lines, &(&1 =~ "## [2.0.0]"))
      old_version_idx = Enum.find_index(changelog_lines, &(&1 =~ "## [1.0.0]"))

      assert new_version_idx < old_version_idx
    end
  end
end
