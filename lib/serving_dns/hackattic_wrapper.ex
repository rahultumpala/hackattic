defmodule ServingDns.HackatticWrapper do
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
    # expecting the master json as request body here.
    master_json = conn.body_params
    send_resp(conn, 200, "OK. Updated master json. Started DNS Server.")
    DNS.read_master_json(master_json) |> DNS.start_nameserver()
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
