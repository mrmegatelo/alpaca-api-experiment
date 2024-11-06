defmodule PhxTinkoffApiWeb.SymbolsLive do
  alias PhxTinkoffApi.AlpacaClient
  alias PhxTinkoffApi.AlpacaSocket
  use PhxTinkoffApiWeb, :live_view

  def mount(%{"symbol" => symbol_slug}, _session, socket) do
    IO.puts("Component is mounted #{inspect socket.id}")
    Process.flag(:trap_exit, true)
    symbol = AlpacaClient.get_symbol(symbol_slug)
    {:ok, bars} = AlpacaClient.get_bars(symbol["symbol"])
    {:ok, %{"a" => ask, "b" => bid}} = AlpacaClient.get_orderbook(symbol["symbol"])

    if connected?(socket), do: AlpacaSocket.subscribe(symbol["symbol"])

    socket =
      socket
      |> assign(
        symbol: symbol["symbol"],
        last_quote: nil,
        last_trade: nil,
        orderbook_depth: 10,
        orderbook_ask: aggregate_orderbook_map(ask),
        orderbook_bid: aggregate_orderbook_map(bid)
      )
      |> push_event("bars:init", %{bars: bars})

    {:ok, socket}
  end

  def handle_info(%{"T" => "q"} = msg, socket) do
    IO.puts("Checking the quote message: #{inspect socket.assigns}")
    socket =
      socket |> assign(last_quote: msg)

    {:noreply, socket}
  end

  def handle_info(%{"T" => "o", "a" => asks, "b" => bids, "r" => true}, socket) do
    IO.puts("Checking the orderbook")
    socket =
      socket
      |> assign(
        orderbook_bid: aggregate_orderbook_map(bids),
        orderbook_ask: aggregate_orderbook_map(asks)
      )

    {:noreply, socket}
  end

  def handle_info(%{"T" => "o", "a" => asks, "b" => bids}, socket) do
    %{orderbook_bid: orderbook_bid, orderbook_ask: orderbook_ask} = socket.assigns()

    socket =
      socket
      |> assign(
        orderbook_bid: update_orderbook(bids, orderbook_bid),
        orderbook_ask: update_orderbook(asks, orderbook_ask)
      )

    {:noreply, socket}
  end

  def handle_info(
        %{"T" => "b", "o" => open, "h" => high, "l" => low, "c" => close, "t" => timestamp},
        socket
      ) do
    socket =
      socket
      |> push_event("bars:update", %{
        open: open,
        high: high,
        low: low,
        close: close,
        time: timestamp
      })

    {:noreply, socket}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  def terminate(reason, socket) do
    IO.puts("Terminateing the view... #{inspect reason} #{inspect socket.id}")
    # AlpacaSocket.unsubscribe()
  end

  def unmount(%{id: id}, _reason) do
    IO.puts("view #{id} unmounted")
    :ok
  end

  def render(assigns) do

    ~H"""
    <div>
      <strong><%= @symbol %></strong>:
      <p>Last trade: <%= @last_trade["price"] %> </p>
      <p>Bid price: <%= @last_quote["bp"] %></p>
      <p>Ask price: <%= @last_quote["ap"] %></p>
      <div class="grid gap-8  lg:grid-cols-3">
        <div class="order-2 lg:order-1 lg:col-span-1">
          <div class="p-4 border border-solid border-gray-200 overflow-hidden rounded">
            <.order_book
              symbol={@symbol}
              bids={@orderbook_bid}
              asks={@orderbook_ask}
              depth={@orderbook_depth}
            />
          </div>
        </div>
        <div class="lg:col-span-2 order-1 lg:order-2">
          <div class="p-4 border border-solid border-gray-200 overflow-hidden rounded">
            <.chart />
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp aggregate_orderbook_map(orders) do
    Enum.reduce(orders, %{}, fn b, acc -> Map.put(acc, b["p"], b["s"]) end)
  end

  defp update_orderbook([%{"s" => 0, "p" => price} | tail], orders_map) do
    orders_map_new = orders_map |> Map.delete(price)
    update_orderbook(tail, orders_map_new)
  end

  defp update_orderbook([%{"s" => size, "p" => price} | tail], orders_map) do
    orders_map_new = orders_map |> Map.put(price, size)
    update_orderbook(tail, orders_map_new)
  end

  defp update_orderbook([], orders_map), do: orders_map

  defp format_currency(value, precision) when is_integer(value) do
    format_currency(value / 1, precision)
  end

  defp format_currency(value, precision) when is_float(value) do
    :io_lib.format("~.#{precision}f", [value]) |> IO.iodata_to_binary()
  end

  defp format_currency(value, _), do: value

  defp calculate_percentage(a, b) when map_size(a) == 0 and map_size(b) == 0, do: "0"
  defp calculate_percentage(_, b) when map_size(b) == 0, do: "100"

  defp calculate_percentage(map_left, map_right) do
    compare = map_size(map_left)
    against = map_size(map_right)
    total = compare + against
    (compare / total * 100) |> Float.to_string()
  end

  def chart(assigns) do
    ~H"""
    <div id="chart" phx-hook="ChartHook"></div>
    """
  end

  def order_book(assigns) do
    ~H"""
    <table class="table-auto border-separate text-xs w-full overflow-hidden rounded border bodrer-solid border-gray-50">
      <thead>
        <tr class="bg-gray-50">
          <th class="py-1 px-2 text-left">
            Price (<%= @symbol |> String.split("/") |> Enum.at(1) %>)
          </th>
          <th class="py-1 px-2 text-right">
            Amount (<%= @symbol |> String.split("/") |> Enum.at(0) %>)
          </th>
          <th class="py-1 px-2 text-right">
            Total (<%= @symbol |> String.split("/") |> Enum.at(1) %>)
          </th>
        </tr>
      </thead>
      <tbody class="font-bold">
        <%= for ask <- Map.keys(@asks) |> Enum.sort |>  Enum.reverse |> Enum.take(-@depth) do %>
          <tr class="bg-rose-50 text-rose-700">
            <td class="py-1 px-2"><%= format_currency(ask, 2) %></td>
            <td class="py-1 px-2 text-right"><%= @asks[ask] |> format_currency(4) %></td>
            <td class="py-1 px-2 text-right"><%= (ask * @asks[ask]) |> format_currency(2) %></td>
          </tr>
        <% end %>
        <tr>
          <td class="py-1 px-2" colspan="3">
            <div class="flex items-center gap-1">
              <div class="text-teal-700 grow-0">
                <span class="">B</span>
              </div>
              <div class="grow flex overflow-hidden rounded-sm">
                <span
                  class="h-2 bg-teal-700"
                  style={ "width:" <> calculate_percentage(@asks, @bids) <> "%" }
                >
                </span>
                <span
                  class="h-2 bg-rose-700"
                  style={ "width:" <> calculate_percentage(@bids, @asks) <> "%" }
                >
                </span>
              </div>
              <div class="text-rose-700 text-right grow-0">
                <span>A</span>
              </div>
            </div>
          </td>
        </tr>
        <%= for bid <- Map.keys(@bids) |> Enum.sort |> Enum.reverse |> Enum.take(@depth) do %>
          <tr class="bg-teal-50 text-teal-700">
            <td class="py-1 px-2"><%= format_currency(bid, 2) %></td>
            <td class="py-1 px-2 text-right"><%= @bids[bid] |> format_currency(4) %></td>
            <td class="py-1 px-2 text-right"><%= (bid * @bids[bid]) |> format_currency(2) %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end
end
