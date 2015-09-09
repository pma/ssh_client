defmodule SSHClient do
  use Connection
  require Logger

  def start_link(host, port, opts, timeout \\ 5000) do
    Connection.start_link(__MODULE__, {host, port, opts, timeout})
  end

  def run(conn, cmd), do: Connection.call(conn, {:run, cmd})

  def init({host, port, opts, timeout}) do
    s = %{host: host, port: port, opts: opts, timeout: timeout, conn_ref: nil}
    {:connect, :init, s}
  end

  def connect(_, %{conn_ref: nil, host: host, port: port, opts: opts,
                   timeout: timeout} = s) do

    pid = self()
    case :ssh.connect(host, port, [disconnectfun: &send(pid, {:disconnect, &1})] ++ opts, timeout) do
      {:ok, conn_ref} ->
        Logger.info "Connected."
        {:ok, %{s | conn_ref: conn_ref}}
      {:error, _} ->
        Logger.warn "Connection failed."
        {:backoff, 1000, s}
    end
  end

  def disconnect(info, %{conn_ref: conn_ref} = s) do
    :ok = :ssh.close(conn_ref)
    {:connect, :reconnect, %{s | conn_ref: nil}}
  end

  def handle_call(_, _, %{conn_ref: nil} = s) do
    {:reply, {:error, :closed}, s}
  end
  def handle_call({:run, cmd}, from, %{conn_ref: conn_ref} = s) do
    spawn_link fn ->
      {:ok, channel_id} = :ssh_connection.session_channel(conn_ref, s.timeout)
      _status = :ssh_connection.exec(conn_ref, channel_id, cmd, 60_000)
      reply = wait_for_reply(conn_ref)
      GenServer.reply(from, {:ok, reply})
    end

    {:noreply, s}
  end
  def handle_info({:disconnect, reason}, s) do
    Logger.debug "Server disconnected"
    {:disconnect, reason, s}
  end

  defp wait_for_reply(conn_ref) do
    do_wait_for_reply(conn_ref, "")
  end

  defp do_wait_for_reply(conn_ref, buff) do
    receive do
      {:ssh_cm, ^conn_ref, msg} ->
        case msg do
          {:closed, _channel_id} ->
            buff
          {:data, _channel_id, 0, data} ->
            do_wait_for_reply(conn_ref, buff <> data)
          _ ->
            do_wait_for_reply(conn_ref, buff)
        end
    end
  end
end
