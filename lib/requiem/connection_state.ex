defmodule Requiem.ConnectionState do
  @type t :: %__MODULE__{
          address: Requiem.Address.t(),
          dcid: binary,
          scid: binary,
          odcid: binary,
          stream_id_pod: non_neg_integer,
          trapping_pids: MapSet.t()
        }

  defstruct address: nil,
            dcid: "",
            scid: "",
            odcid: "",
            stream_id_pod: 0,
            trapping_pids: nil

  def new(address, dcid, scid, odcid) do
    %__MODULE__{
      address: address,
      dcid: dcid,
      scid: scid,
      odcid: odcid,
      stream_id_pod: 0,
      trapping_pids: MapSet.new()
    }
  end

  @spec should_delegate_exit?(t, pid) :: boolean
  def should_delegate_exit?(conn, pid) do
    MapSet.member?(conn.trapping_pids, pid)
  end

  @spec trap_exit(t, pid) :: t
  def trap_exit(%{trapping_pids: pids} = conn, pid) do
    %{conn | trapping_pids: MapSet.put(pids, pid)}
  end

  @spec forget_to_trap_exit(t, pid) :: t
  def forget_to_trap_exit(%{trapping_pids: pids} = conn, pid) do
    %{conn | trapping_pids: MapSet.delete(pids, pid)}
  end

  @spec create_new_stream_id(t, :bidi | :uni) :: {non_neg_integer, t}
  def create_new_stream_id(%{stream_id_pod: id_pod} = conn, :bidi) do
    stream_id = <<id_pod::62, 0x1::2>>
    {:binary.decode_unsigned(stream_id), %{conn | stream_id_pod: id_pod + 1}}
  end

  def create_new_stream_id(%{stream_id_pod: id_pod} = conn, :uni) do
    stream_id = <<id_pod::62, 0x3::2>>
    {:binary.decode_unsigned(stream_id), %{conn | stream_id_pod: id_pod + 1}}
  end
end
