defmodule Kvern.Backup do
  import ShorterMaps
  # The directory must exist. We check if the file exists. If it's the case, we
  # rename it to a .bak file and then write the new file
  def write_file(dir, key, value, config) do
    ~M(codec) = config
    filename = key_to_filename(key, codec.extension)
    fullpath = Path.join(dir, filename)
    with :ok <- copy_backup_file_if_exists(fullpath),
         {:ok, encoded} <- codec.encode(value),
         :ok <- write_data(fullpath, encoded)
      do
        {:ok, key}
      else
        {:error, err} -> {:error, {err, key}}
    end
  end

  def key_to_filename(key, ext), do: "#{key}.#{ext}" # keys must be binaries !

  def copy_backup_file_if_exists(path) do
    case File.exists?(path) do
      false -> :ok
      true ->
        backup_path = path
          |> String.split(".")
          |> :lists.reverse
          |> List.insert_at(0, "bak")
          |> :lists.reverse
          |> Enum.join(".")
        case File.rename(path, backup_path) do
          :ok -> :ok
          {:error, _} = err ->
            {:error, {:cannot_backup, path, err}}
        end
    end
  end

  def write_data(path, content) do
    case File.write(path, content) do
      :ok ->
        :ok
      {:error, _} = err ->
        {:error, {:could_not_write_file, path, content, err}}
    end
  end

  def recover_dir(dir, config) do
    ~M(codec) = config
    extension = codec.extension
    try do
      {:ok, glob} = Regex.compile(".*\\.#{extension}$")
      data = dir
        |> File.ls!
        |> IO.inspect
        |> Enum.filter(fn f -> Regex.match?(glob, f) end)
        |> IO.inspect
        |> Enum.map(fn f ->
            path = Path.join(dir, f)
            bin = File.read!(path)
            key = remove_extension(f, extension)
            case codec.decode(bin) do
              {:ok, data} -> {key, data}
              _ -> nil
            end
           end)
        |> Enum.into(%{})
      {:ok, data}
    rescue
      e -> {:error, e}
    end
  end

  @todo "Should we fail if extension not found ?"
  def remove_extension(filename, ext) do
    extlen = String.length(ext) + 1 # handle the dot
    case String.split_at(filename, -extlen) do
      {cleaned, "." <> ^ext} -> cleaned
      other -> other
    end
  end

end