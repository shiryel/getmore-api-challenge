defmodule Market.RpxFixes.Server do
  @moduledoc false
  use GenServer
  require Logger

  # Server (callbacks)

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init([worker: worker, queue_name: queue_name]) do
    [host: host] = Application.get_env(:rpx, RPX.AMQP.Server)
    config = RPX.AMQP.new(host)
    RPX.AMQP.listen(config, queue_name)

    state = %{
      config: config,
      worker: worker
    }

    {:ok, state}
  end

  def handle_info({:basic_deliver, payload, meta}, state) do
    %{"target" => target, "params" => params} = Jason.decode!(payload)

    Task.async(
      fn ->
        res = apply(state.worker, String.to_atom(target), params)
        Logger.debug(inspect res)
        RPX.AMQP.send(state.config, Map.put(meta, :queue_name, meta.reply_to), res)
      end
    )

    {:noreply, state}
  end

  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    IO.puts("Server listening to calls")
    {:noreply, state}
  end

  def handle_info(_ignore, state) do
    {:noreply, state}
  end
end 
