defmodule Hackattic do
  use Application
  alias WebSocketChitChat.WebSocketTask

  def start(_type, _args) do
    access_token = System.get_env("hackattic_access_token")

    # HelpMeUnpack.UnpackTask.run(access_token)
    # TouchToneDialing.TouchToneTask.run(access_token)
    {:ok, pid} = WebSocketTask.start_link(access_token)
    IO.inspect({"WebSocket Server PID", pid})
    GenServer.cast(pid, :run)

    children = []
    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end
end
