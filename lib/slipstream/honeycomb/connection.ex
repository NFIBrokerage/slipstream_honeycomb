defmodule Slipstream.Honeycomb.Connection do
  @moduledoc """
  A GenServer that collects telemetry events from Slipstream connections and
  emits them to Honeycomb
  """

  @sender Application.get_env(
            :slipstream_honeycomb,
            :honeycomb_sender,
            Opencensus.Honeycomb.Sender
          )

  alias Opencensus.Honeycomb.Event

  @event_names [
    ~w[slipstream connection connect stop]a,
    ~w[slipstream connection handle stop]a
  ]

  use GenServer

  @doc false
  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc false
  @impl GenServer
  def init(state) do
    {:ok, state, {:continue, :telemetry_attach}}
  end

  @doc false
  @impl GenServer
  def handle_continue(:telemetry_attach, state) do
    :telemetry.attach_many(
      "slipstream-honeycomb-connection-exporter",
      @event_names,
      &handle_event/4,
      state
    )

    {:noreply, state}
  end

  def handle_event(event, measurements, metadata, _state) do
    GenServer.cast(__MODULE__, {event, measurements, metadata})
  end

  @impl GenServer
  def handle_cast({event, measurements, metadata}, state) do
    {event, measurements, metadata}
    |> map_to_event()
    |> send_event()

    {:noreply, state}
  end

  defp map_to_event(
         {~w[slipstream connection connect stop]a, %{duration: duration},
          metadata}
       ) do
    %Event{
      time: metadata.start_time,
      data: %{
        state: inspect(metadata.state),
        traceId: metadata.trace_id,
        id: metadata.connection_id,
        durationMs: convert_time(duration)
      }
    }
  end

  defp map_to_event(
         {~w[slipstream connection handle stop]a, %{duration: duration},
          metadata}
       ) do
    %Event{
      time: metadata.start_time,
      data: %{
        start_state: inspect(metadata.start_state),
        end_state: inspect(metadata.end_state),
        traceId: metadata.trace_id,
        parentId: metadata.connection_id,
        id: metadata.span_id,
        durationMs: convert_time(duration),
        raw_message: inspect(metadata.raw_message),
        message: inspect(metadata.message),
        events: inspect(metadata.events),
        built_events: inspect(metadata.built_events),
        return: metadata.return
      }
    }
  end

  defp send_event(event) do
    @sender.send_batch([event])
  end

  defp convert_time(time) do
    # nanoseconds but with decimals!
    # if we were to convert directly to msec, it'd be an integer :(
    System.convert_time_unit(time, :native, :microsecond) / 1_000
  end
end
