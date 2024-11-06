defmodule PhxTinkoffApi.AlpacaClient do
  def get_symbols() do
    {:ok, response} = make_trading_api_request("/v2/assets?status=active&asset_class=crypto")
    {:ok, response |> Enum.map(fn s -> put_symbol_url(s) end)}
  end

  def get_bars(symbol) do
    {:ok, %{"bars" => %{^symbol => payload}}} =
      make_market_api_request("/v1beta3/crypto/us/bars?symbols=#{symbol}&timeframe=1Min&sort=asc")
    {:ok, payload}
  end

  def get_orderbook(symbol) do
    {:ok, %{"orderbooks" => %{^symbol => payload}}} =
      make_market_api_request("/v1beta3/crypto/us/latest/orderbooks?symbols=#{symbol}")
    {:ok, payload}
  end

  def get_symbol(slug) do
    {:ok, symbols} = get_symbols()

    symbols
    |> Enum.find(fn s -> s["url"] == slug end)
  end

  defp make_trading_api_request(url) do
    host = Application.get_env(:phx_tinkoff_api, :alpaca_trading_api_host)
    full_url = URI.merge(host, url)

    make_request(full_url)
  end

  defp make_market_api_request(url) do
    host = Application.get_env(:phx_tinkoff_api, :alpaca_market_api_host)
    full_url = URI.merge(host, url)

    make_request(full_url)
  end

  defp make_request(url) do
    IO.puts(url)

    headers = [
      {"APCA-API-KEY-ID", Application.get_env(:phx_tinkoff_api, :alpaca_client_id)},
      {"APCA-API-SECRET-KEY", Application.get_env(:phx_tinkoff_api, :alpaca_client_secret)}
    ]

    response =
      Finch.build(:get, url, headers)
      |> Finch.request(PhxTinkoffApi.Finch)
      |> decode_response

    {:ok, response}
  end

  defp decode_response({:ok, %Finch.Response{status: 200, body: body}}) do
    Jason.decode!(body)
  end

  defp decode_response({:ok, response}) do
    IO.puts("HTTP Error: #{inspect(response)}")
    []
  end

  defp decode_response({:error, response}) do
    IO.puts("Error: #{inspect(response)}")
    []
  end

  defp put_symbol_url(symbol) do
    url =
      symbol["symbol"]
      |> String.replace("/", "_")
      |> String.downcase()

    Map.put(symbol, "url", url)
  end
end
