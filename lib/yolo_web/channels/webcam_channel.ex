defmodule YoloWeb.WebcamChannel do
  use Phoenix.Channel

  def join("webcam:detection", _params, socket) do
    socket =
      socket
      |> assign(:current_request, nil)
      |> assign(:last_frame, nil)
    {:ok, socket}
  end

  def handle_in("frame", %{"frame" => "data:image/jpeg;base64,"<> base64frame}=_event, %{assigns: %{current_request: image_id}}=socket) do
    if image_id == nil do
      {:noreply, detect(socket, base64frame)}
    else
      {:noreply, assign(socket, :last_frame, base64frame)}
    end
  end

  def handle_info({:detected, _image_id, result}, socket) do
    handle_detected(result, socket)
  end

  def detect(socket, b64frame) do
    frame = Base.decode64!(b64frame)
    image_id = Yolo.Worker.request_detection(Yolo.Worker, frame)
    socket
    |> assign(:current_request, image_id)
    |> assign(:last_frame, nil)
  end

  def handle_detected(result, socket) do
    push(socket, "detected", result)

    socket =
      socket
      |> assign(:current_request, nil)
      |> detect_if_need()

    {:noreply, socket}
  end


  def detect_if_need(socket) do
    if socket.assigns.last_frame != nil do
      detect(socket, socket.assigns.last_frame)
    else
      socket
    end
  end

end
