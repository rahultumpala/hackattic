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

    headers = []
    content_type = ~c"application/json"
    {:ok, req_body} = Jason.encode(solution)

    url = ~s"https://hackattic.com/challenges/the_redis_one/solve?access_token=" <> access_token

    {:ok, {{_, 200, _}, _, body}} =
      :httpc.request(:post, {url, headers, content_type, req_body}, [], [])

    IO.inspect(body)
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

    fmt = RDBFormat.parse(rdb) |> IO.inspect()

    emoji_value =
      get_value_for_key(
        fmt,
        fn map, key -> Map.get(map, key) |> Map.get("emoji") end
      )
      |> Map.get("value")

    type_check_key_value =
      get_value_for_key(
        fmt,
        fn _map, key -> key == type_check_key end
      )
      |> Map.get("type")

    expiry_map =
      get_value_for_key(
        fmt,
        fn _map, key -> key == "expiry_map" end
      )

    expiry_millis =
      if expiry_map != nil do
        expiry_map
        |> Enum.map(fn {_key, value} -> value end)
        |> Enum.at(0)
      else
        nil
      end

    response_map =
      Map.new()
      |> Map.put("db_count", Map.get(fmt, "db_count"))
      |> Map.put("emoji_key_value", emoji_value)
      |> Map.put("expiry_millis", expiry_millis)
      |> Map.put(type_check_key, type_check_key_value)

    response_map
  end

  defp get_value_for_key(fmt, filter_lambda) do
    ret_values =
      Map.get(fmt, "db")
      |> Enum.map(fn {_db_num, db} -> db end)
      |> Enum.map(fn map ->
        keys =
          Map.keys(map)
          |> Enum.filter(fn key -> key != "db_ht_sz" && key != "exp_ht_sz" end)
          |> Enum.filter(fn key -> filter_lambda.(map, key) end)
          |> Enum.into([])

        cond do
          Enum.count(keys) == 1 ->
            key = Enum.at(keys, 0)
            Map.get(map, key)

          true ->
            nil
        end
      end)
      |> Enum.filter(fn val -> val != nil end)

    case ret_values do
      [] -> nil
      _ -> Enum.at(ret_values, 0)
    end
  end
end
