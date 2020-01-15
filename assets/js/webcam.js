import Webcam from "webcamjs"

export function setupWebcamAndDetection(socket) {

  let channel = socket.channel("webcam:detection", {})
  channel.join()
    .receive("ok", resp => { console.log(`Joined successfully to "detection:alvise"`, resp); })
    .receive("error", resp => { console.log("Unable to join", resp) })


  Webcam.set({
    width: 1280,
    height: 720,
    image_format: 'jpeg',
    jpeg_quality: 90,
    fps: 30
  });
  Webcam.attach("#camera")


  function capture() {
    Webcam.snap(function (data_uri, canvas, context) {
        channel.push("frame", { "frame": data_uri})
    });
  }

  //listen to "detected" events and calls draw_objects() for each event
  channel.on("detected", draw_objects);

  //our canvas element
  let canvas = document.getElementById('objects');
  let ctx = canvas.getContext('2d');
  const boxColor = "blue";
  //labels font size
  const fontSize = 18;

  function draw_objects(result) {
    
    let objects = result.objects;

    //clear the canvas from previews rendering
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.lineWidth = 4;
    ctx.font = `${fontSize}px Helvetica`;

    //for each detected object render label and box
    objects.forEach(function(obj) {
        let width = ctx.measureText(obj.label).width;
        
        // box
        ctx.strokeStyle = boxColor;
        ctx.strokeRect(obj.x, obj.y, obj.w, obj.h);

        // white label + background
        ctx.fillStyle = boxColor;
        ctx.fillRect(obj.x - 2, obj.y - fontSize, width + 10, fontSize);
        ctx.fillStyle = "white";
        ctx.fillText(obj.label, obj.x, obj.y - 2);
    });
  }

  //toggle button starts and stops an interval
  const FPS = 30; // frames per second
  let intervalID = null;

  document.getElementById("start_stop")
          .addEventListener("click", function(){

    if(intervalID == null) {
        intervalID = setInterval(capture, 1000/FPS)
        this.textContent = "Stop";
    } else {
      clearInterval(intervalID);
      intervalID = null;
      this.textContent = "Start";
    }
  });
}

export function hasCameraElement() {
  return document.querySelector("#camera") != null;
}


