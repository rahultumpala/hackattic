defmodule TheRedisOne.RDBFormat do
  alias TheRedisOne.RedisDecoder

  defmacro int32, do: quote(do: integer - signed)
  defmacro int16, do: quote(do: integer - signed)

  def parse(<<bits::binary>>) do
    <<first_five::bitstring-size(40), version::bitstring-32, rest::bitstring>> = bits

    fmt = %{
      "magic" => RedisDecoder.bitstring_to_string(first_five),
      "rdb-version" => RedisDecoder.bitstring_to_string(version)
    }

    {fmt, _bits} = read({fmt, rest})

    fmt
  end

  defp read({fmt, bits}) do
    <<op_code::bitstring-size(8), rest::bitstring>> = bits

    {fmt, bits} =
      case op_code do
        <<0xFE>> ->
          read_db({fmt, rest})
          |> read()

        <<0xFA>> ->
          read_aux({fmt, rest})
          |> read()

        <<0xFF>> ->
          read_crc_chksum({fmt, rest})

        _ ->
          {fmt, bits}
      end

    {fmt, bits}
  end

  defp read_crc_chksum({fmt, rest}) do
    <<chksum::bitstring-size(64)>> = rest

    fmt = fmt |> Map.put("crc-checksum", chksum)

    {fmt, <<>>}
  end

  defp read_aux({fmt, bits}) do
    {key, rest} = RedisDecoder.read_len_encoded_bits(bits)
    key = RedisDecoder.bitstring_to_string(key)

    {val, rest} =
      case key do
        "redis-ver" ->
          RedisDecoder.read_len_encoded_bits(rest)

        "redis-bits" ->
          RedisDecoder.read_len_encoded_bits(rest)

        "ctime" ->
          RedisDecoder.read_len_encoded_bits(rest)

        "used-mem" ->
          RedisDecoder.read_len_encoded_bits(rest)

        "aof-preamble" ->
          RedisDecoder.read_len_encoded_bits(rest)

        _ ->
          RedisDecoder.read_len_encoded_bits(rest)
      end

    aux =
      Map.get(fmt, "aux", %{})
      |> Map.put(key, val)

    fmt = Map.put(fmt, "aux", aux)

    {fmt, rest}
  end

  defp read_db({fmt, bits}) do
    fmt = Map.put(fmt, "db_count", Map.get(fmt, "db_count", 0) + 1)
    <<db_num::integer-big-size(8), key::bitstring-size(8), rest::bitstring>> = bits

    {cur_db_map, bits} =
      case key do
        <<0xFB>> ->
          read_resize_db(%{}, rest)
          # _ -> {fmt, bits}
      end

    db =
      Map.get(fmt, "db", %{})
      |> Map.put(db_num, cur_db_map)

    fmt = Map.put(fmt, "db", db)

    {fmt, bits}
  end

  defp read_kv_pairs(cur_db_map, bits, 0), do: {cur_db_map, bits}

  defp read_kv_pairs(cur_db_map, bits, total) do
    <<next::bitstring-8, rest::bitstring>> = bits

    ts_bits_len =
      case next do
        <<0xFC>> -> 64
        <<0xFD>> -> 32
        _ -> 0
      end

    cond do
      ts_bits_len > 0 ->
        <<expiry_ts::signed-little-size(ts_bits_len), value_flag::integer-big-8, rest::bitstring>> =
          rest

        {key, rest} = RedisDecoder.read_len_encoded_bits(rest)

        {type, value, rest} = RedisDecoder.read_value_encoding(value_flag, rest)

        expiry_map =
          Map.get(cur_db_map, "expiry_map", %{})
          |> Map.put(key, expiry_ts)

        cur_db_map =
          cur_db_map
          |> Map.put(key, %{
            "type" => type,
            "value" => value
          })
          |> Map.put("expiry_map", expiry_map)

        read_kv_pairs(cur_db_map, rest, total - 1)

      ts_bits_len == 0 ->
        <<value_flag::integer-big-8, rest::bitstring>> = bits

        {key, rest} = RedisDecoder.read_len_encoded_bits(rest)

        {type, value, rest} = RedisDecoder.read_value_encoding(value_flag, rest)

        cur_db_map =
          cur_db_map
          |> Map.put(key, %{
            "type" => type,
            "value" => value,
            "emoji" => is_key_emoji?(key)
          })

        read_kv_pairs(cur_db_map, rest, total - 1)
    end
  end

  defp read_resize_db(cur_db_map, <<bits::bitstring>>) do
    {db_ht_sz, bits} = RedisDecoder.read_length(bits)
    {exp_ht_sz, bits} = RedisDecoder.read_length(bits)

    {cur_db_map, bits} =
      Map.put(cur_db_map, "exp_ht_sz", exp_ht_sz)
      |> Map.put("db_ht_sz", db_ht_sz)
      |> read_kv_pairs(bits, db_ht_sz)

    {cur_db_map, bits}
  end

  defp is_key_emoji?(key) do
    (byte_size(key) == 4 && String.length(key) == 1) ||
      (byte_size(key) == 2 && String.length(key) == 1)
  end
end
