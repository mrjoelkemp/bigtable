defmodule Bigtable.Schema do
  defmacro __using__(_opt) do
    quote do
      import unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :rows, accumulate: true)
      Module.register_attribute(__MODULE__, :families, accumulate: true)
      Module.register_attribute(__MODULE__, :columns, accumulate: true)
    end
  end

  defmacro type(do: block) do
    quote do
      var!(columns) = []
      unquote(block)

      defstruct var!(columns)

      def type() do
        %__MODULE__{}
      end
    end
  end

  defmacro row(name, do: block) do
    quote do
      @prefix "#{String.capitalize(to_string(unquote(name)))}"
      unquote(block)
      defstruct @families

      def get_all() do
        regex = "^#{@prefix}#\\w+"

        Bigtable.ReadRows.build()
        |> Bigtable.RowFilter.row_key_regex(regex)
        |> Bigtable.ReadRows.read()
        |> Enum.map(fn {:ok, rows} -> rows.chunks end)
        |> List.flatten()
        |> Bigtable.Typed.group_by_row_key()
        |> Enum.map(&parse/1)
      end

      def get(ids) when is_list(ids) do
        rows =
          [ids]
          |> List.flatten()
          |> Enum.map(fn id -> "#{@prefix}##{id}" end)
          |> Bigtable.RowSet.row_keys()
          |> Bigtable.ReadRows.read()
          |> Enum.map(fn {:ok, rows} -> rows.chunks end)
          |> List.flatten()
          |> Bigtable.Typed.group_by_row_key()
          |> Enum.map(&parse/1)
      end

      def get(id) when is_binary(id) do
        get([id])
        |> List.first()
      end

      def parse(row) do
        Bigtable.Typed.parse_typed(__MODULE__.type(), row)
      end

      def type() do
        %__MODULE__{}
      end
    end
  end

  defmacro family(name, do: block) do
    quote do
      var!(columns) = []
      unquote(block)
      @families {unquote(name), Map.new(var!(columns))}
    end
  end

  defmacro column(key, value) do
    c = {key, get_value_type(value)} |> Macro.escape()

    quote do
      var!(columns) = [unquote(c) | var!(columns)]
    end
  end

  defp get_value_type(value) when is_atom(value), do: value

  defp get_value_type({:__aliases__, _, modules}) do
    Module.concat([Elixir | modules]).type()
  end
end

defmodule BT.Schema.PositionTest do
  use Bigtable.Schema

  type do
    column(:bearing, :integer)
    column(:latitude, :float)
    column(:longitude, :float)
    column(:timestamp, :string)
  end
end

defmodule BT.Schema.VehicleTest do
  use Bigtable.Schema

  row :vehicle do
    family :vehicle do
      column(:battery, :integer)
      column(:checkedInAt, :string)
      column(:condition, :string)
      column(:driver, :string)
      column(:fleet, :string)
      column(:id, :string)
      column(:numberPlate, :string)
      column(:position, BT.Schema.PositionTest)
      column(:previousPosition, BT.Schema.PositionTest)
      column(:ride, :string)
    end
  end
end
