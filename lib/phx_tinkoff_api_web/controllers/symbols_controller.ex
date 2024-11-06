defmodule PhxTinkoffApiWeb.SymbolsController do
  use PhxTinkoffApiWeb, :controller

  def index(conn, _params) do
    api_host = System.get_env("ALPACA_API_HOST")
    IO.puts(api_host)
    {:ok, symbols} = PhxTinkoffApi.AlpacaClient.get_symbols()
    render(conn, :index, symbols: symbols)
  end

  def show(conn, %{ "symbol" => symbol }) do
    conn
      |> assign(:js_view, "symbol")
      |> render(:show, symbol: symbol)
  end

end
