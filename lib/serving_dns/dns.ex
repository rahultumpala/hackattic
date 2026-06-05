# ============================================================================
# DNS Protocol Implementation
#
# Author: Rahul T
#
# This is my code and my implementation of the Domain Name System (DNS)
# protocol. It includes the logic required to create, parse, and process
# DNS messages and related protocol structures.
# ============================================================================

defmodule DNS do
  defmacro int16BE, do: quote(do: integer - signed - 16 - big)
  defmacro int8BE, do: quote(do: integer - signed - 8 - big)

  @local_udp_port 9002
  @udp_recv_timeout_ms 10_000

  @q_type %{
    "A" => 1,
    "NS" => 2,
    "MD" => 3,
    "MF" => 4,
    "CNAME" => 5,
    "SOA" => 6,
    "MB" => 7,
    "MG" => 8,
    "MR" => 9,
    "NULL" => 10,
    "WKS" => 11,
    "PTR" => 12,
    "HINFO" => 13,
    "MINFO" => 14,
    "MX" => 15,
    "TXT" => 16,
    "RP" => 17,
    "AAAA" => 28,
    "AXFR" => 252,
    "MAILB" => 253,
    "MAILA" => 254,
    "*" => 255
  }
  @q_class %{
    "IN" => 1,
    "CS" => 2,
    "CH" => 3,
    "HS" => 4,
    "*" => 255
  }
  # reverse mapping
  @q_type_reversed Enum.reduce(@q_type, %{}, fn {k, v}, acc -> Map.put(acc, v, k) end)
  @q_class_reversed Enum.reduce(@q_class, %{}, fn {k, v}, acc -> Map.put(acc, v, k) end)

  @doc """
  Expects a list of website names.
  returns the ip address.
  """
  def query(names, type, class) when is_list(names) do
    IO.puts("Querying #{type} records for names")
    dbg(names)
    socket = connect_to_local_dns()

    count = Enum.count(names)
    {id, header} = build_query_header(count)

    questions =
      Enum.reduce(names, <<>>, fn cur, acc ->
        acc <> build_question_section(cur, type, class)
      end)

    packet = header <> questions

    case :gen_udp.send(socket, packet) do
      :ok ->
        IO.inspect({"Sent query packet with id #{id}. packet:", packet})

      error ->
        IO.inspect({"Error sending packet", error})
        System.halt(1)
    end

    case :gen_udp.recv(socket, 0, @udp_recv_timeout_ms) do
      {:ok, resp} ->
        dbg(resp)
        {_ip, _port, data} = resp
        file_path = "./out.log"
        file_path |> File.touch!()
        file_path |> File.write!(data, [:binary])
        parse_response(id, data)

      error ->
        IO.inspect({"recv error", error})
    end
  end

  def query(name, type, class) do
    query([name], type, class)
  end

  def connect_to_local_dns() do
    # Open a UDP socket on an ephemeral local port
    case :gen_udp.open(9129, [:binary, active: false]) do
      {:ok, socket} ->
        # {10, 107, 96, 69} #53
        # {192, 168, 1, 1} #53
        case socket |> :gen_udp.connect({127, 0, 0, 1}, 9002) do
          :ok -> dbg("Talking to localhost at port 53")
          error -> IO.inspect({"Error talking to localhost", error})
        end

        socket

      {:error, err} ->
        IO.inspect("Could not open a socket to port #{@local_udp_port} due to error.", err)
        System.halt(1)
    end
  end

  # Header section - each line is 2 octets long
  #                                  1  1  1  1  1  1
  #    0  1  2  3  4  5  6  7  8  9  0  1  2  3  4  5
  #  +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
  #  |                      ID                       |
  #  +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
  #  |QR|   Opcode  |AA|TC|RD|RA|   Z    |   RCODE   |
  #  +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
  #  |                    QDCOUNT                    |
  #  +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
  #  |                    ANCOUNT                    |
  #  +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
  #  |                    NSCOUNT                    |
  #  +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
  #  |                    ARCOUNT                    |
  #  +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+

  def build_query_header(num_queries) do
    id = :rand.uniform(65_536) - 1

    {id,
     <<
       id::16,
       0::1,
       0::4,
       0::1,
       0::1,
       1::1,
       0::1,
       0::3,
       0::4,
       num_queries::16,
       0::16,
       0::16,
       0::16
     >>}
  end

  def parse_response(id, data) do
    {header, rest} = parse_response_header(id, data)
    dbg(header)

    {questions, rest} = Map.get(header, "qd_count") |> parse_question_section(rest)
    dbg(questions)

    {resource_records, rest} = Map.get(header, "an_count") |> parse_resource_records(rest)
    resource_records = replace_offsets_with_labels(resource_records, data)
    dbg(resource_records)

    {ns_records, rest} = Map.get(header, "ns_count") |> parse_resource_records(rest)
    ns_records = replace_offsets_with_labels(ns_records, data)
    dbg(ns_records)

    {additional_records, _rest} = Map.get(header, "ar_count") |> parse_resource_records(rest)
    additional_records = replace_offsets_with_labels(additional_records, data)
    dbg(additional_records)
  end

  def replace_offsets_with_labels(resource_records, <<total_response::binary>>) do
    resource_records
    |> Enum.map(fn rec ->
      labels =
        Map.get(rec, "labels") |> parse_labels_from_offset(total_response) |> Enum.join(".")

      r_data = Map.get(rec, "r_data")
      type = Map.get(rec, "type")

      r_data =
        cond do
          type == "NS" || type == "SOA" ->
            r_data |> parse_labels_from_offset(total_response) |> Enum.join(".")

          true ->
            r_data
        end

      %{rec | "labels" => labels, "r_data" => r_data}
    end)
  end

  def parse_labels_from_offset(labels, <<total_response::binary>>) do
    labels
    |> Enum.map(fn label ->
      cond do
        is_number(label) ->
          # parse labels from offset
          <<_offset::size(8 * label), start::binary>> = total_response
          {parsed_labels, _rest} = parse_labels(start)
          # recursively evaluate all label pointers
          parsed_labels |> parse_labels_from_offset(total_response)

        true ->
          label
      end
    end)
    |> List.flatten()
  end

  defp parse_response_header(id, data) do
    {header, rest} = parse_header(data)
    ^id = Map.get(header, "id")
    {header, rest}
  end

  defp parse_header(<<data::binary>>) do
    <<
      id::16,
      qr::1,
      opcode::4,
      aa::1,
      tc::1,
      rd::1,
      ra::1,
      z::3,
      rcode::4,
      qd_count::16,
      an_count::16,
      ns_count::16,
      ar_count::16,
      rest::binary
    >> = data

    {%{
       "id" => id,
       "opcode" => opcode,
       "aa" => aa,
       "tc" => tc,
       "rd" => rd,
       "ra" => ra,
       "z" => z,
       "rcode" => rcode,
       "qd_count" => qd_count,
       "an_count" => an_count,
       "ns_count" => ns_count,
       "ar_count" => ar_count,
       "qr" => qr
     }, rest}
  end

  def write_header(header = %{}) do
    <<
      Map.get(header, "id")::16,
      Map.get(header, "qr")::1,
      Map.get(header, "opcode")::4,
      Map.get(header, "aa")::1,
      Map.get(header, "tc")::1,
      Map.get(header, "rd")::1,
      Map.get(header, "ra")::1,
      Map.get(header, "z")::3,
      Map.get(header, "rcode")::4,
      Map.get(header, "qd_count")::16,
      Map.get(header, "an_count")::16,
      Map.get(header, "ns_count")::16,
      Map.get(header, "ar_count")::16
    >>
  end

  # Question section - each line is 2 octets long
  #                                  1  1  1  1  1  1
  #    0  1  2  3  4  5  6  7  8  9  0  1  2  3  4  5
  #  +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
  #  |                                               |
  #  /                     QNAME                     /
  #  /                                               /
  #  +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
  #  |                     QTYPE                     |
  #  +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
  #  |                     QCLASS                    |
  #  +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
  def build_question_section(name, q_type, q_class) do
    qt = Map.get(@q_type, q_type, 0)
    qc = Map.get(@q_class, q_class, 0)

    qname =
      String.split(name, ".")
      |> Enum.reduce(<<>>, fn label, acc ->
        acc <> <<String.length(label)::8, label::binary>>
      end)
      |> Kernel.<>(<<0>>)

    <<qname::binary, qt::16, qc::16>>
  end

  def parse_question_section(qd_count, <<data::binary>>) when is_number(qd_count) do
    {questions, rest} =
      Enum.reduce(1..qd_count, {[], data}, fn _cur_q, {questions, rest} ->
        {parsed, rest} = parse_question_section(%{}, rest)
        {questions ++ [parsed], rest}
      end)

    {questions, rest}
  end

  def parse_question_section(q_section, <<data::binary>>) when is_map(q_section) do
    {labels, rest} = parse_labels(data, [])
    q_section = Map.put(q_section, "labels", labels)

    <<length::integer-size(8), rest::binary>> = rest

    # expecting the map to return with contents listed as
    # %{"labels" => ["list oflabels"], "qtype" => valid_qtype, "qclass" => valid_qclass}
    {q_section, rest} =
      case length do
        0 ->
          # read qtype and qclass
          <<qtype::16, qclass::16, rest::binary>> = rest

          q_section =
            q_section
            |> Map.put("q_type", Map.get(@q_type_reversed, qtype))
            |> Map.put("q_class", Map.get(@q_class_reversed, qclass))

          {q_section, rest}

        _ ->
          # error.
          IO.puts("Error state. Labels not read properly.")
      end

    {q_section, rest}
  end

  def write_question_section(question) do
    labels = Map.get(question, "labels")
    q_type = Map.get(@q_type, Map.get(question, "q_type"))
    q_class = Map.get(@q_class, Map.get(question, "q_class"))

    write_name(labels) <> <<q_type::int16BE(), q_class::int16BE()>>
  end

  def write_name(labels) do
    labels
    |> Enum.reduce(<<>>, fn label, acc ->
      acc <> <<String.length(label)::int8BE(), label::binary>>
    end)
    |> Kernel.<>(<<0::8>>)
  end

  def parse_labels(data, labels \\ [])

  def parse_labels(<<>>, labels), do: {labels, <<>>}

  def parse_labels(<<0::8, _rest::binary>> = data, labels) do
    # Return [data] and not [rest] so that the caller of this func and use the first byte.
    {labels, data}
  end

  def parse_labels(<<data::binary>>, labels) do
    <<first_2_bits::bitstring-size(2), _rest::bitstring>> = data
    <<length::8, rest::binary>> = data

    {labels, rest} =
      cond do
        first_2_bits == <<1::1, 1::1>> ->
          # If first 2 bits are 11 then it is a pointer that reads an offset
          # not used in question section but used in RRs (resource records).
          {label, rest} = parse_label_pointer(data)
          # don't read recursively here since we're not resolving pointers yet
          # and hence we won't reach a null byte.
          {labels ++ [label], rest}

        length > 0 ->
          # the size is in length bytes. multiply by 8 to get bytes.
          <<label::bitstring-size(length * 8), rest::binary>> = rest
          label = label |> to_string()
          # recursively read until a null byte is found.
          parse_labels(rest, labels ++ [label])
      end

    {labels, rest}
  end

  def parse_label_pointer(<<1::1, 1::1, offset::integer-size(14), rest::binary>> = _data) do
    {offset, rest}
  end

  def parse_resource_records(an_count, data) when an_count > 0 do
    {records, rest} =
      Enum.reduce(1..an_count, {[], data}, fn _, {records, bin_data} ->
        {rec, rest} = parse_resource_record(bin_data)
        rec = parse_r_data(rec)
        {records ++ [rec], rest}
      end)

    {records, rest}
  end

  def parse_resource_records(an_count, data) when an_count == 0, do: {[], data}

  def parse_resource_record(<<data::binary>>) do
    {labels, rest} = parse_labels(data, [])

    <<type::16, class::16, ttl::32, rdlength::16, rdata::binary-size(rdlength), rest::binary>> =
      rest

    {%{
       "labels" => labels,
       "type" => Map.get(@q_type_reversed, type),
       "class" => Map.get(@q_class_reversed, class),
       "ttl_seconds" => ttl,
       "r_length" => rdlength,
       "r_data" => rdata
     }, rest}
  end

  def write_resource_record(
        %{
          "ans" => data,
          "q_type" => q_type,
          "q_class" => class,
          "labels" => labels
        } = answer
      ) do
    answer |> dbg

    name = write_name(labels)
    type = Map.get(@q_type, q_type)
    class = Map.get(@q_class, class)
    # some value - set to 1 hr.
    ttl = 0
    r_data = write_r_data(q_type, data)
    rd_length = byte_size(r_data)

    rr =
      <<name::binary, type::int16BE(), class::int16BE(), ttl::32, rd_length::int16BE(),
        r_data::binary-size(rd_length)>>

    rr
  end

  def parse_r_data(record) do
    type = Map.get(record, "type")
    data = Map.get(record, "r_data")

    parsed =
      case type do
        "A" -> parse_A_data(data)
        "NS" -> parse_NS_data(data)
        "SOA" -> parse_SOA_data(data)
        "AAAA" -> parse_AAAA_data(data)
        "TXT" -> parse_TXT_data(data)
        _ -> data
      end

    %{record | "r_data" => parsed}
  end

  def write_r_data(type, data) do
    case type do
      "A" -> write_A_data(data)
      "AAAA" -> write_AAAA_data(data)
      "RP" -> write_RP_data(data)
      "TXT" -> <<byte_size(data)::8>> <> <<data::binary>>
      _ -> <<data::binary>>
    end
  end

  def parse_NS_data(<<data::binary>>) do
    {labels, _empty} = parse_labels(data)
    labels
  end

  def parse_A_data(<<data::binary>>) do
    <<ip1::8, ip2::8, ip3::8, ip4::8>> = data
    "#{ip1}.#{ip2}.#{ip3}.#{ip4}"
  end

  def write_A_data(data) do
    String.split(data, ".")
    |> Enum.reduce(<<>>, fn ip_val, acc ->
      {int, ""} = Integer.parse(ip_val)
      acc <> <<int::int8BE()>>
    end)
  end

  def parse_SOA_data(<<data::binary>>) do
    # Don't read labels recursively. read only at max 3 labels per MNAME and RNAME.
    {labels, _rest} = parse_labels(data)
    labels
  end

  def parse_AAAA_data(<<data::binary>>) do
    # 128 bit IPv6 data. read 4 bits in sequence and join them.
    parse_ipv6(data) |> String.replace_trailing(":", "")
  end

  def write_AAAA_data(ipv6_addr) do
    binary =
      with {:ok, tuple} <- ipv6_addr |> String.to_charlist() |> :inet.parse_address() do
        tuple
        |> Tuple.to_list()
        |> Enum.reduce(<<>>, fn segment, acc ->
          <<acc::binary, segment::int16BE()>>
        end)
      end

    binary
  end

  def write_RP_data(data) do
    (data
     |> String.split(".")
     |> write_name()) <>
      <<1::int8BE(), "."::binary, 0::8>>
  end

  def parse_TXT_data(<<_skip_first_char::8, data::binary>>), do: data

  def parse_ipv6(<<>>), do: ""

  def parse_ipv6(<<data::binary>>) do
    <<a::4, b::4, c::4, d::4, rest::binary>> = data
    "#{a}#{b}#{c}#{d}:" <> parse_ipv6(rest)
  end

  def parse_query(<<data::binary>>) do
    {header, rest} = parse_header(data)
    {questions, _rest} = parse_question_section(Map.get(header, "qd_count"), rest)
    {header, questions}
  end

  # modified from the original impl to support receiving master json as a decoded map struct.
  def read_master_json(json = %{}) do
    master_data =
      json
      |> Map.get("records")
      |> Enum.reduce(%{}, fn record, acc ->
        # convert a.b.c to ["c", "b", "a"] and store records against this key.
        name = Map.get(record, "name") |> String.split(".") |> Enum.reverse()
        record = Map.delete(record, "name")

        Map.update(
          acc,
          name,
          [record],
          fn value -> value ++ [record] end
        )
      end)
      |> Enum.reduce(%{}, fn {k, records}, acc ->
        # merge records based on type and store only data
        merged =
          records
          |> Enum.reduce(%{}, fn record, acc ->
            type = Map.get(record, "type")
            data = Map.get(record, "data")
            Map.update(acc, type, [data], fn val -> val ++ [data] end)
          end)

        Map.put(acc, k, merged)
      end)
      |> create_tree(%{})

    dbg(master_data)
  end

  # create a tree with TLD at the root and domain and subdomain as child nodes.
  # records data is stored as a map with record type as key and data as values at the leaves.
  # example: consider the master data records
  # a.b.c AAAA ipv6:addr, a.b.c A ipv4, *.b.c TXT some-text
  # it is stored as
  # %{
  #   "c" => %{
  #     "b" => %{
  #       "*" => %{"_dns_records" => %{"TXT" => ["some-text"]}},
  #       "a" => %{"_dns_records" => %{"A" => ["ipv4"], "AAAA" => ["ipv6:addr"]}}
  #     }
  #   }
  # }
  # "_dns_records" is the key that contains the records data.
  def create_tree(map, tree) do
    tree =
      map
      |> Enum.reduce(tree, fn {k, v}, acc ->
        case k do
          [t] ->
            Map.update(acc, t, %{"_dns_records" => v}, fn val ->
              Map.merge(val, v)
            end)

          [h | t] ->
            acc = Map.update(acc, h, %{t => v}, fn value -> Map.put(value, t, v) end)
            subtree = create_tree(Map.get(acc, h), %{})
            acc = Map.put(acc, h, subtree)
            acc

          _ ->
            Map.update(acc, k, v, fn val -> Map.merge(val, v) end)
        end
      end)

    tree
  end

  # query is a list of values [ "c", "b" ]. Traverse the tree and return the value stored against "b".
  def get_from_tree(query, tree) do
    # returns either an empty map or the value stored against the query.
    Enum.reduce(query, tree, fn q, acc ->
      case Map.has_key?(acc, q) do
        # check for any wildcard records if exact match not found.
        false -> Map.get(acc, "*", %{})
        true -> Map.get(acc, q, %{})
      end
    end)
  end

  def write_udp_response(header, questions, answers) do
    header =
      header
      |> Map.put("qr", 1)
      |> Map.put("ns_count", 0)
      |> Map.put("an_count", Enum.count(answers))
      # set to 0. dig by default sends an EDNS(0) OPT pseudo-record in the additional section.
      |> Map.put("ar_count", 0)

    header = write_header(header)

    questions_binary =
      questions
      |> Enum.reduce(<<>>, fn ques, acc -> acc <> write_question_section(ques) end)

    answers =
      Enum.reduce(answers, <<>>, fn ans, acc -> acc <> write_resource_record(ans) end)

    header <> questions_binary <> answers
  end

  def answer_dns_questions(<<msg::binary>>, tree) do
    {header, questions} = parse_query(msg)
    IO.inspect({header, questions})

    answers =
      questions
      |> Enum.map(fn q ->
        # reverse to keep TLD at the start and subdomain at the last.
        labels = Map.get(q, "labels") |> Enum.reverse()

        # suffix this to get the exact values.
        labels = labels ++ ["_dns_records", Map.get(q, "q_type")]

        ans =
          case get_from_tree(labels, tree) do
            %{} -> nil
            [] -> nil
            [val] -> val
          end

        Map.put(q, "ans", ans)
      end)
      |> Enum.filter(fn ans -> Map.get(ans, "ans") != nil end)

    write_udp_response(header, questions, answers)
  end

  def start_nameserver(master_tree \\ %{}) do
    case :gen_udp.open(@local_udp_port, [:binary, active: false]) do
      {:ok, socket} ->
        dbg("Listening to UDP messages on port #{@local_udp_port}")
        listen_to_incoming_udp_msgs(socket, master_tree)

      {:error, err} ->
        IO.inspect("Could not open a socket to port #{@local_udp_port} due to error.", err)
        System.halt(1)
    end
  end

  def listen_to_incoming_udp_msgs(socket, master_tree) do
    {:ok, {sender_ip, sender_port, msg}} = :gen_udp.recv(socket, 0, :infinity)
    response = answer_dns_questions(msg, master_tree)
    "out.log" |> File.write!(response, [:binary])
    :gen_udp.send(socket, sender_ip, sender_port, response)

    listen_to_incoming_udp_msgs(socket, master_tree)
  end
end

# DNS.query("hackattic.com", "SOA", "IN")
# DNS.read_master_json() |> DNS.start_nameserver()
