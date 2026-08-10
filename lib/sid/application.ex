defmodule Sid.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SidWeb.Telemetry,
      Sid.Repo,
      {DNSCluster, query: Application.get_env(:sid, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Sid.PubSub},
      # Start a worker by calling: Sid.Worker.start_link(arg)
      # {Sid.Worker, arg},
      # Start to serve requests, typically the last entry
      SidWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Sid.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SidWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
