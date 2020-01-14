defmodule Yolo.Worker do
  use GenServer

  @timeout 5_000
  @uuid4_size 16

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @default_config [
    python: "python", 
    detect_script: "python_scripts/detect.py",
    model: "yolov3"
  ]
  
def config do
  @default_config
  |> Keyword.merge(Application.get_env(:yolo, __MODULE__, []))
  
  #loads the values from env variables when {:system, env_var_name}
  |> Enum.map(fn 
    
    # it finds the full path when not provided
    {:python, path} -> {:python, System.find_executable(path)}

    # it loads the value from the environment variable
    # when the env variable is not set, it defaults to @default_config[option]
    {option, {:system, env_variable}} -> 
      {option, System.get_env(env_variable, @default_config[option])}
    
    # all the other options
    config -> config
  
  end)
  |> Enum.into(%{})
end

  def init(:ok) do
    config = config()
    
    port = Port.open(
      {:spawn_executable, config.python}, 
      [:binary, :nouse_stdio, {:packet, 4}, 
      args: [config.detect_script, config.model]
    ])

    {:ok, %{port: port, requests: %{}}}
  end


  def request_detection(pid, image) do
    # UUID.uuid4(:hex) is 32 bytes
    image_id = UUID.uuid4() |> UUID.string_to_binary!()
    request_detection(pid, image_id, image)
  end


  def request_detection(pid, image_id, image) when byte_size(image_id) == @uuid4_size do
    GenServer.call(pid, {:detect, image_id, image})
  end

  def await(image_id, timeout \\ @timeout) do
    receive do
      {:detected, ^image_id, result} -> result
    after
      timeout -> {:detection_timeout, image_id}
    end
  end

  def handle_call({:detect, image_id, image_data}, {from_pid, _}, worker) do
    Port.command(worker.port, [image_id, image_data])
    worker = put_in(worker, [:requests, image_id], from_pid)
    {:reply, image_id, worker}
  end


  def handle_info({port, {:data, <<image_id::binary-size(@uuid4_size), json_string::binary()>>}}, %{port: port}=worker) do
    result = get_result!(json_string)
    # getting from pid and removing the request from the map
    {from_pid, worker} = pop_in(worker, [:requests, image_id])
    # sending the result map to from_pid
    send(from_pid, {:detected, image_id, result})
    {:noreply, worker}
  end


  defp get_result!(json_string) do
    result = Jason.decode!(json_string)
    %{
      shape: %{width: result["shape"]["width"], height: result["shape"]["height"]},
      objects: get_objects(result["labels"], result["boxes"])
    }
  end

  def get_objects(labels, boxes) do
    Enum.zip(labels, boxes)
    |> Enum.map(fn {label, [x, y, bottom_right_x, bottom_right_y]}->
      w = bottom_right_x - x
      h = bottom_right_y - y
      %{label: label, x: x, y: y, w: w, h: h}
    end)
  end
end
