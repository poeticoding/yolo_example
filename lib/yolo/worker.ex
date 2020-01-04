defmodule Yolo.Worker do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    python = Application.get_env(:yolo, :python) |> System.find_executable()
    detect_script = Application.get_env(:yolo, :detect_script)
    model = Application.get_env(:yolo, :model, "yolov3")

    port = Port.open({:spawn_executable, python}, [:binary, :nouse_stdio, {:packet, 4}, args: [detect_script, model]])
    {:ok, %{port: port, requests: %{}}}
  end


  def request_detection(pid, image) do
    # UUID.uuid4(:hex) is 32 bytes
    request_detection(pid, UUID.uuid4(:hex), image)
  end

  def request_detection(pid, image_id, image) do
    GenServer.call(pid, {:detect, image_id, image})
  end

  def await(image_id) do
    receive do
      {:detected, ^image_id, result} -> result
    end
  end

  def handle_call({:detect, image_id, image_data}, {from_pid, _}, worker) do
    Port.command(worker.port, [image_id, image_data])
    worker = put_in(worker, [:requests, image_id], from_pid)
    {:reply, image_id, worker}
  end


  def handle_info({port, {:data, data}}, %{port: port}=worker) do
    result = Jason.decode!(data) |> get_result()
    image_id = Map.fetch!(result, :id)
    # getting from pid and removing the request from the map
    {from_pid, worker} = pop_in(worker, [:requests, image_id])
    # sending the result map to from_pid
    send(from_pid, {:detected, image_id, result})
    {:noreply, worker}
  end

  defp get_result(result) do
    %{
      id: result["id"],
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
