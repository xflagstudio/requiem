defmodule Requiem.ErrorCode do
  @type error_code ::
          :no_error
          | :internal_error
          | :server_busy
          | :flow_control_error
          | :stream_id_error
          | :stream_state_error
          | :final_offset_error
          | :frame_format_error
          | :transport_parameter_error
          | :version_negotiation_error
          | :protocol_violation
          | :unsolicited_path_response
  # | :frame_error

  @code_map %{
    no_error: 0x0,
    internal_error: 0x1,
    server_busy: 0x2,
    flow_control_error: 0x3,
    stream_id_error: 0x4,
    stream_state_error: 0x5,
    final_offset_error: 0x6,
    frame_format_error: 0x7,
    transport_parameter_error: 0x8,
    version_negotiation_error: 0x9,
    protocol_violation: 0xA,
    unsolicited_path_response: 0xB
  }

  @spec to_integer(error_code) :: non_neg_integer
  def to_integer(code) do
    Map.fetch!(@code_map, code)
  end
end
