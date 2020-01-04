const FPS = 30;

import { Socket } from "phoenix"
import msgpack from "msgpack-lite"
let socket = new Socket("/socket", { params: { token: window.userToken } })
window.msgpack = msgpack;
socket.connect()

// Now that you are connected, you can join channels with a topic:
let channel = socket.channel("detection:alvise", {})

channel.join()
    .receive("ok", resp => { console.log(`Joined successfully to "detection:alvise"`, resp) })
    .receive("error", resp => { console.log("Unable to join", resp) })

channel.on("detected", function(result){
    console.log(result)
})


const hdConstraints = {
    video: { width: { min: 640 }, height: { min: 360 } }
};

const video = document.querySelector('video');
const canvas = document.createElement('canvas');
const startButton = document.querySelector('#start_button');
const toggleButton = document.querySelector('#toggle_button');

navigator.mediaDevices.getUserMedia(hdConstraints).
    then((stream) => { video.srcObject = stream });


function capture() {
    // console.log("CAPTURE")
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    canvas.getContext('2d').drawImage(video, 0, 0);
    // Other browsers will fall back to image/png
    let frame = canvas.toDataURL("image/jpeg", 0.9);
    channel.push("frame", {frame: frame});
}

var timer = null;
function startStopDetecting() {
    if(timer == null) {
        timer = setInterval(capture, 1000 / FPS);
    }
    else {
        clearInterval(timer);
        timer = null;
    }
}
toggleButton.onclick = startStopDetecting;


export default socket
