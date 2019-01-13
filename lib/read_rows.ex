defmodule Bigtable.ReadRows do
  alias Google.Bigtable.V2
  alias Bigtable.RowFilter
  alias Bigtable.Connection

  @doc """
  Builds a ReadRows request with a provided table name
  """
  @spec build(binary()) :: V2.ReadRowsRequest.t()
  def build(table_name) when is_binary(table_name) do
    V2.ReadRowsRequest.new(table_name: table_name)
    |> RowFilter.default_chain()
  end

  @doc """
  Builds a ReadRows request with default table name if none provided
  """
  @spec build() :: V2.ReadRowsRequest.t()
  def build() do
    build(Bigtable.Utils.configured_table_name())
  end

  def read(%V2.ReadRowsRequest{} = request) do
    {:ok, rows} =
      Connection.get_connection()
      |> Bigtable.Stub.read_rows(request)

    rows
    |> Enum.filter(fn {status, row} ->
      status == :ok and !Enum.empty?(row.chunks)
    end)
  end

  def read(table_name) when is_binary(table_name) do
    build(table_name)
    |> read()
  end

  def read() do
    build()
    |> read
  end
end
