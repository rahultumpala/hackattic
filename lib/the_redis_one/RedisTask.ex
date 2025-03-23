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

    # rdb =
    #   Map.get(json, "rdb")
    #   |> String.codepoints()
    #   |> Base64.decode(<<>>, 0)

    # num = :rand.uniform(100) |> Integer.to_string()
    # IO.inspect("FILE => rdb#{num}")
    # File.write("./rdb/rdb" <> num, rdb)
    # IO.inspect(type_check_key)

    {:ok, rdb} = File.read("./rdb/rdb93")

    fmt = RDBFormat.parse(rdb)

    get_emoji_value(fmt)

    # response_map = Map.new()
    #             |> Map.put("db_count", Map.get(fmt, "db_count"))
    #             |> Map.put("emoji_key_value", )
  end

  defp get_emoji_value(fmt) do
    Map.get(fmt, "db")
    |> IO.inspect()
    |> Enum.map(fn {db_num, db} -> db end)
    |> IO.inspect()
    |> Enum.each(fn map ->
      emoji_keys =
        Map.keys(map)
        |> Enum.filter(fn key -> key != "db_ht_sz" && key != "exp_ht_sz" end)
        |> Enum.filter(fn key -> Map.get(map, key) |> Map.get("emoji", true) end)
        |> Enum.into([])

      cond do
        Enum.count(emoji_keys) == 1 ->
          key = Enum.at(emoji_keys, 0)
          value = Map.get(map, key) |> Map.get("value")
      end

      emoji_keys
    end)
    |> Enum.filter(fn {key, value} -> key != "db_ht_sz" && key != "exp_ht_sz" end)
    |> IO.inspect()
    |> Enum.filter(fn {key, value_map} -> Map.get(value_map, "emoji") end)
    |> IO.inspect()
  end
end
