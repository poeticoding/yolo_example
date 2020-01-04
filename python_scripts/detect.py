import os, sys
from struct import unpack, pack
import numpy as np
import cv2
import cvlib as cv
import json

UUID4_SIZE = 32

# setup of FD 3 for input (instead of stdin)
# FD 4 for output (instead of stdout)
def setup_io():
    return os.fdopen(3,"rb"), os.fdopen(4,"wb")

def read_image(input):
    # reading the first 4 bytes with the length of the data
    # the first 32 bytes are the UUID string, the rest is the image
    # 
    header = input.read(4)
    if len(header) != 4: 
        return None # EOF
    
    (length,) = unpack("!I", header)

    image_id = input.read(UUID4_SIZE).decode("ascii")
    image_data = input.read(length - UUID4_SIZE)

    # converting the binary to a opencv image
    nparr = np.fromstring(image_data, np.uint8)
    image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    return {'id': image_id, 'image': image}

def detect(image, model):
    boxes, labels, _conf = cv.detect_common_objects(image, model=model)
    return boxes, labels

def write_result(output, image_id, image_shape, boxes, labels):
    result = json.dumps({
        'id': image_id, 'shape': image_shape,
        'boxes': boxes, 'labels': labels
    }).encode("ascii")

    header = pack("!I", len(result))
    output.write(header)
    output.write(result)
    output.flush()

def run(model):
    input, output = setup_io()
    
    while True:
        image = read_image(input)
        if image is None: break
        
        #image shape
        height, width, _ = image["image"].shape
        shape = {'width': width, 'height': height}

        #detect object
        boxes, labels = detect(image["image"], model)

        #send result back to elixir
        write_result(output, image["id"], shape, boxes, labels)

if __name__ == "__main__":
    model = "yolov3"
    if sys.argc > 1: 
        model = sys.argv[1]
        
    run(model)
