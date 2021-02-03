use Mix.Config

config :phoenix, json_library: Jason

config :slipstream_honeycomb,
  honeycomb_sender: HoneycombSenderMock
