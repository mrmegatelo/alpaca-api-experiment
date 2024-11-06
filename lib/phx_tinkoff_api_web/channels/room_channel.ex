defmodule PhxTinkoffApiWeb.RoomChannel do
  use PhxTinkoffApiWeb, :channel

  @impl true
  def join("room:lobby", _payload, socket) do
    {:ok, socket}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (room:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_in("quotes", _payload, socket) do
    IO.puts("Handling the incoming quotes")
    {:noreply, socket}
  end

  @impl true
  def handle_in("bars", _payload, socket) do
    IO.puts("Handling the incoming bars")
    {:noreply, socket}
  end


  @impl true
  def handle_in("orderbook", _payload, socket) do
    IO.puts("Handling the incoming orderbook")
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
