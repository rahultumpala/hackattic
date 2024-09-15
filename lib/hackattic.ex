defmodule Hackattic do
  use Application

  def start(_type, _args) do
    access_token = System.get_env("hackattic_access_token")

    # HelpMeUnpack.UnpackTask.run(access_token)

    children = []
    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end
end
