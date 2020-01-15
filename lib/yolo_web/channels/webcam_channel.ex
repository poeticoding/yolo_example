# defmodule YoloWeb.WebcamChannel do
#   use Phoenix.Channel

#   def join("webcam:detection", _params, socket) do
#     {:ok, socket}
#   end

#   def handle_in("frame", %{"frame" => "data:image/jpeg;base64,"<> base64frame}=_event, socket) do
#     frame = Base.decode64!(base64frame)
#     Yolo.Worker.request_detection(Yolo.Worker, frame)
#     {:noreply, socket}
#   end

#   def handle_info({:detected, _image_id, result}, socket) do
#     push(socket, "detected", result)
#   end
# end

defmodule YoloWeb.WebcamChannel do
  use Phoenix.Channel

  def join("webcam:detection", _params, socket) do
    socket =
      socket
      |> assign(:current_image_id, nil)
      |> assign(:latest_frame, nil)
    {:ok, socket}
  end

  def handle_in("frame", %{"frame" => "data:image/jpeg;base64,"<> base64frame}=_event, %{assigns: %{current_image_id: image_id}}=socket) do
    if image_id == nil do
      {:noreply, detect(socket, base64frame)}
    else
      {:noreply, assign(socket, :latest_frame, base64frame)}
    end
  end

  def handle_info({:detected, image_id, result},  %{assigns: %{current_image_id: image_id}}=socket) do
    handle_detected(result, socket)
  end

  def handle_info({:detected, _, _}, socket) do
    {:noreply, socket}
  end

  def detect(socket, b64frame) do
    frame = Base.decode64!(b64frame)
    image_id = Yolo.Worker.request_detection(Yolo.Worker, frame)
    
    socket
    |> assign(:current_image_id, image_id)
    |> assign(:latest_frame, nil)
  end

  def handle_detected(result, socket) do
    push(socket, "detected", result)

    socket =
      socket
      |> assign(:current_image_id, nil)
      |> detect_if_need()

    {:noreply, socket}
  end


  def detect_if_need(socket) do
    if socket.assigns.latest_frame != nil do
      detect(socket, socket.assigns.latest_frame)
    else
      socket
    end
  end

end
