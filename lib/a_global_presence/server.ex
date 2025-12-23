defmodule AGlobalPresence.Server do
  use Plug.Router

  plug(Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["*/*"],
    json_decoder: Jason
  )

  plug(:match)
  plug(:dispatch)

  get "/" do
    send_resp(conn, 200, "I'm alive!")
  end

  post "/" do
    presence_token = conn.params["presence_token"]
    access_token = conn.params["access_token"]

    IO.inspect({"recvd token: ", presence_token})

    response = invoke_hackattic_presence_endpoint(presence_token, access_token)
    send_resp(conn, 200, response)
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  defp invoke_hackattic_presence_endpoint(presence_token, access_token) do
    presence_url = ~s"https://hackattic.com/_/presence/" <> presence_token

    {:ok, response} = :httpc.request(presence_url)
    {{_, 200, _}, _, presence_body} = response

    IO.inspect(presence_body)

    countries = presence_body |> to_string() |> String.split(",") |> length()

    if countries >= 1 do
      headers = []
      content_type = ~c"application/json"

      url =
        ~s"https://hackattic.com/challenges/a_global_presence/solve?access_token=" <> access_token

      {:ok, {{_, 200, _}, _, solution_body}} =
        :httpc.request(:post, {url, headers, content_type, "{}"}, [], [])

      presence_body
      |> to_string()
      |> Kernel.<>("\n")
      |> Kernel.<>(solution_body |> to_string())
    else
      presence_body
    end
  end
end
