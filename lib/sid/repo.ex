defmodule Sid.Repo do
  use Ecto.Repo,
    otp_app: :sid,
    adapter: Ecto.Adapters.Postgres
end
