defmodule PhxTinkoffApi.Repo do
  use Ecto.Repo,
    otp_app: :phx_tinkoff_api,
    adapter: Ecto.Adapters.SQLite3
end
