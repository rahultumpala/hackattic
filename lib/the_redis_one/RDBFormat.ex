defmodule TheRedisOne.RDBFormat do
  defmacro int32, do: quote(do: integer - signed)
  defmacro int16, do: quote(do: integer - signed)

  defp bitstring_to_string(bits) do
    Enum.join(for <<c::utf8 <- bits>>, do: <<c::utf8>>)
  end

  def parse(<<bits::binary>>) do
    <<first_five::bitstring-size(40), version::bitstring-32, rest::bitstring>> = bits

    fmt = %{
      "magic" => bitstring_to_string(first_five),
      "rdb-version" => bitstring_to_string(version)
    }

    {fmt, _bits} = read({fmt, rest})

    IO.inspect(fmt)
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
    {key, rest} = read_len_encoded_bits(bits)
    key = bitstring_to_string(key)

    {val, rest} =
      case key do
        "redis-ver" ->
          read_len_encoded_bits(rest)

        "redis-bits" ->
          read_len_encoded_bits(rest)

        "ctime" ->
          read_len_encoded_bits(rest)

        "used-mem" ->
          read_len_encoded_bits(rest)

        "aof-preamble" ->
          read_len_encoded_bits(rest)

        _ ->
          read_len_encoded_bits(rest)
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
        <<expiry_ts::integer-big-size(ts_bits_len), value_flag::integer-big-8, rest::bitstring>> =
          rest

        {key, rest} = read_len_encoded_bits(rest)

        {value, rest} = read_value_encoding(value_flag, rest)

        expiry_map =
          Map.get(cur_db_map, "expiry_map", %{})
          |> Map.put(key, expiry_ts)

        cur_db_map =
          cur_db_map
          |> Map.put(key, value)
          |> Map.put("expiry_map", expiry_map)

        read_kv_pairs(cur_db_map, rest, total - 1)

      ts_bits_len == 0 ->
        <<value_flag::integer-big-8, rest::bitstring>> = bits

        {key, rest} = read_len_encoded_bits(rest)

        {value, rest} = read_value_encoding(value_flag, rest)

        cur_db_map = cur_db_map |> Map.put(key, value)

        read_kv_pairs(cur_db_map, rest, total - 1)
    end
  end

  defp read_resize_db(cur_db_map, <<bits::bitstring>>) do
    {db_ht_sz, bits} = read_length(bits)
    {exp_ht_sz, bits} = read_length(bits)

    {cur_db_map, bits} =
      Map.put(cur_db_map, "exp_ht_sz", exp_ht_sz)
      |> Map.put("db_ht_sz", db_ht_sz)
      |> read_kv_pairs(bits, db_ht_sz)

    {cur_db_map, bits}
  end

  defp read_length(bits) do
    <<first_2::bitstring-size(2), last_6::integer-size(6), rest::bitstring>> = bits

    case first_2 do
      <<0::2>> ->
        {last_6, rest}

      <<0::1, 1::1>> ->
        <<extra_byte::integer-big-8, rest::bitstring>> = rest
        <<len::integer-big-14>> = <<last_6::integer-6, extra_byte>>
        {len, rest}

      <<1::1, 0::1>> ->
        <<len::integer-big-32, rest::bitstring>> = rest
        {len, rest}

      <<1::1, 1::1>> ->
        {-1, bits}
    end
  end

  defp read_len_encoded_bits(bits) do
    {len, bits} = read_length(bits)

    {read, rest} =
      case len do
        -1 ->
          <<_first_2::bitstring-size(2), last_6::integer-size(6), rest::bitstring>> = bits

          case last_6 do
            0 ->
              <<read::integer-big-size(8), rest::bitstring>> = rest
              {read, rest}

            1 ->
              <<read::integer-big-size(16), rest::bitstring>> = rest
              {read, rest}

            2 ->
              <<read::integer-big-size(32), rest::bitstring>> = rest
              {read, rest}

            3 ->
              {compressed_len, rest} = read_length(rest)
              {_un_compressed_len, rest} = read_length(rest)
              <<_compressed_stream::bitstring-size(compressed_len * 8), rest::bitstring>> = rest
              # TODO: LZF Decompress
              {"todo_decompress_lzf", rest}
          end

        _ ->
          <<read::bitstring-size(len * 8), rest::bitstring>> = bits
          {bitstring_to_string(read), rest}
      end

    {read, rest}
  end

  defp read_value_encoding(value_flag, bits) do
    case value_flag do
      0 ->
        {value, rest} = read_len_encoded_bits(bits)
        {value, rest}

      _ ->
        raise("Value decoding not implemented for value type " <> Integer.to_string(value_flag))
    end
  end
end
