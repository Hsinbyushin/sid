defmodule SidWeb.PageController do
  use SidWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
