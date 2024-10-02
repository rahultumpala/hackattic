defmodule WebSocketChitChat.WebSocketTask do
  alias WebSocketClient
  use GenServer

  def start_link(access_token) do
    GenServer.start_link(__MODULE__, access_token)
  end

  def handle_cast(:run, access_token) do
    token = get_ws_token(access_token)
    ws_url = "wss://hackattic.com/_/ws/" <> token

    {:ok, pid} = WebSocketClient.start_link(ws_url, [self()])

    {:noreply, access_token}
  end

  def handle_call({:submit, secret}, _from_pid, access_token) do
    headers = []
    content_type = ~c"application/json"
    solution = %{secret: secret}
    IO.inspect({"Submitting solution :", solution})
    {:ok, req_body} = Jason.encode(solution)

    url =
      ~s"https://hackattic.com/challenges/websocket_chit_chat/solve?access_token=" <>
        access_token

    {:ok, {{_, 200, _}, _, body}} =
      :httpc.request(:post, {url, headers, content_type, req_body}, [], [])

    IO.inspect(body)
    System.stop(0)
  end

  defp get_ws_token(access_token) do
    url =
      ~s"https://hackattic.com/challenges/websocket_chit_chat/problem?access_token=" <>
        access_token

    {:ok, response} = :httpc.request(url)
    {{_, 200, _}, _, body} = response

    case Jason.decode(body) do
      {:ok, json} ->
        Map.get(json, "token")

      _ ->
        raise "Could not find token in body: " <> body
    end
  end
end
