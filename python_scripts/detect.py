import os, sys
from struct import unpack, pack
import numpy as np
import cv2
import cvlib as cv
import json

UUID4_SIZE = 16
MODEL_SIZE = 1

# setup of FD 3 for input (instead of stdin)
# FD 4 for output (instead of stdout)
def setup_io():
    return os.fdopen(3,"rb"), os.fdopen(4,"wb")


def read_message(input_f):
    # reading the first 4 bytes with the length of the data
    # the first 1 byte is for the model
    # the other 32 bytes are the UUID string, 
    # the rest is the image

    header = input_f.read(4)
    if len(header) != 4: 
        return None # EOF
    
    (total_msg_size,) = unpack("!I", header)


    # read requested model
    model_byte = input_f.read(MODEL_SIZE)
    model = "yolov3" if model_byte == b'\x00' else "yolov3-tiny"


    # image id
    image_id = input_f.read(UUID4_SIZE)
    
    
    # read image data
    image_data = input_f.read(total_msg_size - UUID4_SIZE - MODEL_SIZE)

    # converting the binary to a opencv image
    nparr = np.fromstring(image_data, np.uint8)
    image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    return {'id': image_id, 'model': model, 'image': image}

def detect(image, model):
    boxes, labels, _conf = cv.detect_common_objects(image, model=model)
    return boxes, labels

def write_result(output, image_id, image_shape, boxes, labels):
    result = json.dumps({
        'shape': image_shape,
        'boxes': boxes, 
        'labels': labels
    }).encode("ascii")

    header = pack("!I", len(result) + UUID4_SIZE)
    output.write(header)
    output.write(image_id)
    output.write(result)
    output.flush()

def run():
    input_f, output_f = setup_io()
    
    while True:
        msg = read_message(input_f)
        if msg is None: break
        
        #image shape
        height, width, _ = msg["image"].shape
        shape = {'width': width, 'height': height}

        #detect object
        boxes, labels = detect(msg["image"], msg["model"])

        #send result back to elixir
        write_result(output_f, msg["id"], shape, boxes, labels)

run()