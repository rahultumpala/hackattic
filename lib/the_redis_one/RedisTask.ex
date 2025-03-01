defmodule TheRedisOne.RedisTask do
  alias TheRedisOne.Base64
  alias TheRedisOne.RDBFormat

  def run(access_token) do
    url = ~s"https://hackattic.com/challenges/the_redis_one/problem?access_token=" <> access_token

    {:ok, response} = :httpc.request(url)
    {{_, 200, _}, _, body} = response

    solution =
      case Jason.decode(body) do
        {:ok, json} -> solve(json)
      end

    # headers = []
    # content_type = ~c"application/json"
    # {:ok, req_body} = Jason.encode(solution)

    # url = ~s"https://hackattic.com/challenges/the_redis_one/solve?access_token=" <> access_token

    # {:ok, {{_, 200, _}, _, body}} =
    #   :httpc.request(:post, {url, headers, content_type, req_body}, [], [])

    # IO.inspect(body)
  end

  defp solve(json) do
    type_check_key = Map.get(json, "requirements") |> Map.get("check_type_of")

    rdb =
      Map.get(json, "rdb")
      |> String.codepoints()
      |> Base64.decode(<<>>, 0)
    num = :rand.uniform(100) |> Integer.to_string()
    IO.inspect("FILE => rdb#{num}")
    File.write("./rdb/rdb" <> num, rdb)
    IO.inspect(type_check_key)

    RDBFormat.parse(rdb)
  end
end
