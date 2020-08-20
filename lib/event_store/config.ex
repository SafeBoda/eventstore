defmodule EventStore.Config do
  @moduledoc """
  Provides access to the EventStore configuration.
  """

  @doc """
  Get the event store configuration for the environment.
  """
  def get(event_store, otp_app) do
    Application.get_env(otp_app, event_store, [])
  end

  @doc """
  Get the connection pool module for postgrex.
  """
  def get_pool do
    case Code.ensure_loaded?(DBConnection.ConnectionPool) do
      true -> DBConnection.ConnectionPool
      false -> DBConnection.Poolboy
    end
  end

  @doc """
  Get the event store configuration for the environment.
  """
  def parsed(event_store, otp_app) do
    get(event_store, otp_app) |> parse()
  end

  @doc """
  Normalizes the event store configuration.
  """
  defdelegate parse(config), to: EventStore.Config.Parser

  @doc false
  defdelegate associate(event_store, pid, config), to: EventStore.Config.Store

  @doc false
  defdelegate lookup(event_store), to: EventStore.Config.Store, as: :get

  @doc false
  defdelegate lookup(event_store, setting), to: EventStore.Config.Store, as: :get

  @doc """
  Get the data type used to store event data and metadata.

  Supported data types are:

    - "bytea" - Allows storage of binary strings.
    - "jsonb" - Native JSON type, data is stored in a decomposed binary format
      that makes it slightly slower to input due to added conversion overhead,
      but significantly faster to process, since no reparsing is needed.
  """
  def column_data_type(event_store, config) do
    case Keyword.get(config, :column_data_type, "bytea") do
      valid when valid in ["bytea", "jsonb"] ->
        valid

      invalid ->
        raise ArgumentError,
              inspect(event_store) <>
                " `:column_data_type` expects either \"bytea\" or \"jsonb\" but got: " <>
                inspect(invalid)
    end
  end

  @postgrex_connection_opts [
    :username,
    :password,
    :database,
    :hostname,
    :port,
    :types,
    :socket,
    :socket_dir,
    :ssl,
    :ssl_opts,
    :timeout,
    :pool,
    :pool_size,
    :queue_target,
    :queue_interval
  ]

  def default_postgrex_opts(config) do
    Keyword.take(config, @postgrex_connection_opts)
  end

  def postgrex_opts(config, name) do
    [
      pool_size: 10,
      queue_target: 50,
      queue_interval: 1_000
    ]
    |> Keyword.merge(config)
    |> Keyword.take(@postgrex_connection_opts)
    |> Keyword.put(:backoff_type, :exp)
    |> Keyword.put(:name, name)
  end

  def sync_connect_postgrex_opts(config) do
    config
    |> default_postgrex_opts()
    |> Keyword.put(:backoff_type, :stop)
    |> Keyword.put(:sync_connect, true)
    |> Keyword.put(:pool_size, 1)
  end
end
