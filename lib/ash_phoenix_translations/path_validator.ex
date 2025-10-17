defmodule AshPhoenixTranslations.PathValidator do
  @moduledoc """
  Validates file paths to prevent path traversal attacks.

  This module provides secure file path validation for import/export operations,
  ensuring that files can only be accessed within allowed directories and meet
  security requirements.

  ## Security Features

  - Path traversal prevention (blocks ../ and similar patterns)
  - File size limits to prevent DOS attacks
  - File extension validation (whitelist approach)
  - CSV formula injection prevention
  - Directory containment verification

  ## Configuration

      config :ash_phoenix_translations,
        import_directory: "./imports",
        max_file_size: 100_000_000  # 100MB
  """

  require Logger

  # 100MB
  @max_file_size 100_000_000
  @allowed_extensions [".csv", ".json"]

  @doc """
  Validates an import file path for security.

  Performs comprehensive validation:
  - Expands to absolute path
  - Checks file is within allowed directory
  - Verifies file exists and is readable
  - Validates file size is within limits
  - Checks file extension is allowed

  ## Examples

      iex> validate_import_path("./imports/products.csv")
      {:ok, "/full/path/to/imports/products.csv"}
      
      iex> validate_import_path("../../etc/passwd")
      {:error, :path_traversal_detected}
      
      iex> validate_import_path("./imports/large_file.csv")
      {:error, :file_too_large}
  """
  def validate_import_path(file_path) do
    with {:ok, absolute_path} <- expand_path(file_path),
         {:ok, _} <- check_within_allowed_dir(absolute_path),
         {:ok, _} <- check_file_exists(absolute_path),
         {:ok, _} <- check_file_size(absolute_path),
         {:ok, _} <- check_file_extension(absolute_path) do
      {:ok, absolute_path}
    end
  end

  @doc """
  Validates an export file path for security.

  Similar to validate_import_path but for export operations.
  Ensures the export destination is within allowed directories.
  """
  def validate_export_path(file_path) do
    with {:ok, absolute_path} <- expand_path(file_path),
         {:ok, _} <- check_within_allowed_dir(absolute_path),
         {:ok, _} <- check_file_extension(absolute_path) do
      {:ok, absolute_path}
    end
  end

  @doc """
  Sanitizes a CSV value to prevent formula injection attacks.

  CSV formula injection occurs when values starting with =, +, -, or @
  are interpreted as formulas by spreadsheet applications.

  ## Examples

      iex> sanitize_csv_value("=cmd|'/c calc'")
      "'=cmd|'/c calc'"
      
      iex> sanitize_csv_value("Normal text")
      "Normal text"
      
      iex> sanitize_csv_value("+1234567890")
      "'+1234567890"
  """
  def sanitize_csv_value(value) when is_binary(value) do
    value
    |> String.trim()
    |> escape_formula_injection()
    # Limit length to prevent DOS
    |> String.slice(0, 10_000)
  end

  def sanitize_csv_value(value), do: value

  # Private functions

  defp expand_path(path) do
    {:ok, Path.expand(path)}
  rescue
    _ -> {:error, :invalid_path}
  end

  defp check_within_allowed_dir(absolute_path) do
    allowed_dir = Path.expand(get_import_directory())

    if String.starts_with?(absolute_path, allowed_dir) do
      {:ok, absolute_path}
    else
      Logger.warning("Path traversal attempt detected",
        path: absolute_path,
        allowed_dir: allowed_dir
      )

      {:error, :path_traversal_detected}
    end
  end

  defp check_file_exists(path) do
    if File.exists?(path) do
      {:ok, path}
    else
      {:error, :file_not_found}
    end
  end

  defp check_file_size(path) do
    max_size = get_max_file_size()

    case File.stat(path) do
      {:ok, %{size: size}} when size <= max_size ->
        {:ok, size}

      {:ok, %{size: size}} ->
        Logger.warning("File too large",
          path: path,
          size: size,
          max_size: max_size
        )

        {:error, :file_too_large}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp check_file_extension(path) do
    ext = Path.extname(path) |> String.downcase()

    if ext in @allowed_extensions do
      {:ok, ext}
    else
      Logger.warning("Invalid file extension",
        path: path,
        extension: ext,
        allowed: @allowed_extensions
      )

      {:error, :invalid_file_type}
    end
  end

  defp escape_formula_injection(value) do
    # Check if value starts with formula injection characters
    if String.match?(value, ~r/^[=+\-@]/) do
      # Prefix with single quote to prevent formula interpretation
      "'" <> value
    else
      value
    end
  end

  defp get_import_directory do
    Application.get_env(:ash_phoenix_translations, :import_directory, "./imports")
  end

  defp get_max_file_size do
    Application.get_env(:ash_phoenix_translations, :max_file_size, @max_file_size)
  end
end
