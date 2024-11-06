defmodule PhxTinkoffApi.AlpacaSocket do
  use WebSockex
  require Logger

  @topic "livedata"
  @name :alpaca_socket_server

  def start_link(_) do
    Process.flag(:trap_exit, true)
    host = Application.get_env(:phx_tinkoff_api, :alpaca_wss_host)
    url = "#{host}/v1beta3/crypto/us"
    IO.puts("URL: #{url}.")

    WebSockex.start_link(url, __MODULE__, %{subs: []}, name: @name)
  end

  def subscribe(symbol) do
    WebSockex.cast(@name, {:subscribe_symbol, symbol})
    IO.puts("#{@topic}:#{symbol}")
    Phoenix.PubSub.subscribe(PhxTinkoffApi.PubSub, "#{@topic}:#{symbol}")
  end

  def unsubscribe(client) do
    IO.inspect("Self pid: #{inspect(self())}")
    IO.inspect("Client pid: #{inspect(client)}")
  end

  # {"action": "auth", "key": "PKL8AX9QOIPNQDXWJMEI", "secret": "tfmichJhJwLLaDJ1ASy6CjNPSfuRq9wev9cltlbY"}
  # {"action": "subscribe", "trades": ["FAKEPACA"], "quotes": ["FAKEPACA"], "bars": ["*"]}
  # {"action": "subscribe", "quotes": ["BTC/USDT"], "bars": ["BTC/USDT"]}

  def handle_frame({type, msg}, state) do
    parsed_message = Jason.decode(msg)
    IO.puts("Received Message - Type: #{inspect(type)} -- Message: #{inspect(msg)}")
    response = handle_parsed_message(parsed_message, state)
    IO.puts("Sending the response: #{inspect(response)}")
    response
  end

  def handle_parsed_message({:ok, [%{"T" => "success", "msg" => "connected"}]}, state) do
    IO.puts("Handling successful connection message")

    auth_message =
      %{
        action: "auth",
        key: Application.get_env(:phx_tinkoff_api, :alpaca_client_id),
        secret: Application.get_env(:phx_tinkoff_api, :alpaca_client_secret)
      }
      |> Jason.encode!()

    {:reply, {:text, auth_message}, state}
  end

  def handle_parsed_message({:ok, [%{"T" => "success", "msg" => "authenticated"}]}, state) do
    IO.puts("Successfully authenticated! Subscribing to the stream. #{inspect(state)}")
    {:ok, state}
  end

  def handle_parsed_message({:ok, [payload]}, state) do
    for sub <- state.subs do
      Phoenix.PubSub.broadcast(PhxTinkoffApi.PubSub, "#{@topic}:#{sub}", payload)
    end
    {:ok, state}
  end

  def handle_parsed_message(msg, state) do
    IO.puts("Some strange message: #{inspect(msg)}")
    {:ok, state}
  end

  def handle_cast({:subscribe_symbol, symbol}, %{subs: [symbol|_]} = state) do
    IO.puts("Already subscribed to #{symbol}")
    {:ok, state}
  end

  def handle_cast({:subscribe_symbol, symbol}, %{subs: subs} = state) do
    IO.puts("Subscribing to the symbol: #{inspect(state)}}")
    subscriptions_message =
      %{
        action: "subscribe",
        quotes: [symbol],
        orderbooks: [symbol],
        bars: [symbol],
        trades: [symbol]
      }
      |> Jason.encode!()

    state =
      state
      |> Map.put(:subs, [symbol | subs])

    IO.puts("Subscribed to the symbol: #{inspect(state)}}")
    {:reply, {:text, subscriptions_message}, state}
  end

  def handle_cast(msg, state) do
    IO.puts("Handle cast: #{inspect(msg)}, #{inspect(state)}")
  end

  def terminate(reason, state) do
    IO.puts("\nSocket Terminating:\n#{inspect(reason)}\n\n#{inspect(state)}\n")
    exit(:normal)
  end
end
