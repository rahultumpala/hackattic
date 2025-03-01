defmodule TheRedisOne.RDBFormat do
  defmacro int32, do: quote(do: integer - signed)
  defmacro int16, do: quote(do: integer - signed)

  def parse(<<bits::binary>>) do
    <<first_five::bitstring-size(40), rest::bitstring>> = bits

    fmt = %{
      "magic" => Enum.join(for <<c::utf8 <- first_five>>, do: <<c::utf8>>)
    }

    IO.inspect(fmt)

    {fmt, _bits} = skip_till_db({fmt, rest})

    IO.inspect(fmt)
  end

  defp skip_till_db({fmt, bits}) do
    <<db_key::bitstring-size(8), rest::bitstring>> = bits

    {fmt, bits} =
      case db_key do
        <<0xFE>> -> read_db({fmt, rest})
        _ -> skip_till_db({fmt, rest})
      end

    {fmt, bits}
  end

  defp read_db({fmt, bits}) do
    IO.inspect(bits)
    fmt = Map.put(fmt, "db_count", Map.get(fmt, "db_count", 0) + 1)
    <<db_num::integer-big-size(8), key::bitstring-size(8), rest::bitstring>> = bits

    {fmt, bits} =
      case key do
        <<0xFB>> ->
          read_resize_db(db_num, fmt, rest)
          # _ -> {fmt, bits}
      end

    {fmt, bits}
  end

  defp read_resize_db(db_num, fmt, <<bits::bitstring>>) do
    {db_ht_sz, bits} = read_len_encoded_value(bits)
    {exp_ht_sz, bits} = read_len_encoded_value(bits)

    fmt =
      Map.put(fmt, db_num, %{
        "exp_ht_sz" => exp_ht_sz,
        "db_ht_sz" => db_ht_sz
      })

    {fmt, bits}
  end

  defp read_len_encoded_value(bits) do
    <<first_2::bitstring-size(2), last_6::integer-size(6), rest::bitstring>> = bits

    case first_2 do
      <<0::2>> ->
        {last_6, rest}

      <<0::1, 1::1>> ->
        <<extra_byte::integer-big-8, rest::bitstring>> = bits
        <<len::integer-big-14>> = <<last_6::integer-6, extra_byte>>
        {len, rest}

      <<1::1, 0::1>> ->
        <<len::integer-big-32, rest::bitstring>> = bits
        {len, rest}

      <<1::2>> ->
        nil
    end
  end
end
