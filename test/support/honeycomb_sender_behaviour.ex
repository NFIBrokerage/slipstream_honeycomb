defmodule Slipstream.Honeycomb.SenderBehaviour do
  @moduledoc """
  A behaviour for `Opencensus.Honeycomb.Sender` that defines the `send_batch/1`
  function

  Used by mox to allow us to test emitting these events without side effects
  """

  @callback send_batch([Opencensus.Honeycomb.Event.t()]) ::
              {:ok, integer()} | {:error, Exception.t()}
end
