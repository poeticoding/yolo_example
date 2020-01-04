defmodule YoloWeb.UploadController do
  use YoloWeb, :controller

  def new(conn, _params) do
    render(conn, "new.html")
  end

  def create(conn, %{"upload" => upload}=_params) do
    data = File.read!(upload.path)
    image64 = data |> Base.encode64()
    image_inline = "data:#{upload.content_type};base64, #{image64}"

    detection = Yolo.Worker.request_detection(Yolo.Worker, data) |> Yolo.Worker.await()
    render(conn, "show.html", image: image_inline, detection: detection)
  end
end
