defmodule TheRedisOne.RedisDecoder do
  def bitstring_to_string(bits) do
    Enum.join(for <<c::utf8 <- bits>>, do: <<c::utf8>>)
  end

  def read_value_encoding(value_flag, bits) do
    case value_flag do
      0 ->
        {value, rest} = read_len_encoded_bits(bits)
        {"string", value, rest}

      13 ->
        {value, rest} = read_hashmap_ziplist_encoding(bits)
        {"hashmap", value, rest}

      11 ->
        {value, rest} = read_intset_encoding(bits)
        {"intset", value, rest}

      _ ->
        raise("Value decoding not implemented for value type " <> Integer.to_string(value_flag))
    end
  end

  def read_length(bits) do
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

  def read_len_encoded_bits(bits) do
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

  defp read_hashmap_ziplist_encoding(bits) do
    <<lenBytes::integer-unsigned-little-32, rest::bitstring>> = bits
    <<valueBits::bitstring-size(lenBytes * 8 - 32), rest::bitstring>> = rest
    {valueBits, rest}
  end

  defp read_intset_encoding(bits) do
    <<_encoding::integer-unsigned-big-32, length::integer-big-unsigned-32, rest::bitstring>> =
      bits

    <<contents::bitstring-size(length * 8), rest::bitstring>> = rest
    {contents, rest}
  end
end
