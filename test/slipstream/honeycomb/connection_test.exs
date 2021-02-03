defmodule Slipstream.Honeycomb.ConnectionTest do
  use ExUnit.Case

  import Mox
  setup :verify_on_exit!
  @sender Application.fetch_env!(:slipstream_honeycomb, :honeycomb_sender)

  test "honeycomb events are emitted on telemetry events" do
    pid = start_supervised!(Slipstream.Honeycomb.Connection)
    test_proc = self()

    expect(@sender, :send_batch, 2, fn [event] ->
      send(test_proc, {:send_event, event})

      {:ok, 1}
    end)
    |> allow(self(), pid)

    # ideally we'd have slipstream do the actual emitting here, but I don't
    # wanna go through all the melarky to set up a phoenix endpoint just for
    # this test
    metadata = %{
      state: %{},
      connection_id: "foo",
      trace_id: "bar",
      start_time: DateTime.utc_now()
    }

    duration = System.monotonic_time() - System.monotonic_time()

    :telemetry.execute(
      [:slipstream, :connection, :connect, :stop],
      %{duration: duration},
      metadata
    )

    assert_receive {:send_event, event}

    assert event.time == metadata.start_time
    assert event.data.state == "%{}"
    assert event.data.traceId == metadata.trace_id
    assert event.data.id == metadata.connection_id

    metadata = %{
      state: %{},
      connection_id: "foo",
      span_id: "baz",
      trace_id: "bar",
      start_time: DateTime.utc_now(),
      raw_message: :connect,
      message: :connect,
      events: [],
      built_events: [],
      return: {:noreply, %{}}
    }

    :telemetry.execute(
      [:slipstream, :connection, :handle, :stop],
      %{duration: duration},
      metadata
    )

    assert_receive {:send_event, event}

    assert event.time == metadata.start_time
    assert event.data.state == "%{}"
    assert event.data.traceId == metadata.trace_id
    assert event.data.parentId == metadata.connection_id
    assert event.data.id == metadata.span_id
    assert event.data.raw_message == ":connect"
  end
end
