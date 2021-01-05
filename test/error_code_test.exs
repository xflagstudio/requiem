defmodule RequiemTest.ErrorCodeTest do
  use ExUnit.Case, async: true

  alias Requiem.ErrorCode

  test "error_code" do
    assert ErrorCode.to_integer(:no_error) == 0
    assert ErrorCode.to_integer(:internal_error) == 1
    assert ErrorCode.to_integer(:server_busy) == 2
    assert ErrorCode.to_integer(:flow_control_error) == 3
    assert ErrorCode.to_integer(:stream_id_error) == 4
    assert ErrorCode.to_integer(:stream_state_error) == 5
    assert ErrorCode.to_integer(:final_offset_error) == 6
    assert ErrorCode.to_integer(:frame_format_error) == 7
    assert ErrorCode.to_integer(:transport_parameter_error) == 8
    assert ErrorCode.to_integer(:version_negotiation_error) == 9
    assert ErrorCode.to_integer(:protocol_violation) == 10
    assert ErrorCode.to_integer(:unsolicited_path_response) == 11
  end
end
