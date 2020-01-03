import os
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

    return {'id': image_id, 'data': image_data}

def detect(image):
    nparr = np.fromstring(image, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    boxes, labels, _conf = cv.detect_common_objects(img, model="yolov3")
    return boxes, labels

def write_result(output, image_id, boxes, labels):
    result = json.dumps({'id': image_id, 'boxes': boxes, 'labels': labels}).encode("ascii")
    header = pack("!I", len(result))
    output.write(header)
    output.write(result)
    output.flush()

def run():
    input, output = setup_io()
    
    while True:
        image = read_image(input)
        if image is None: break
        boxes, labels = detect(image["data"])
        write_result(output, image["id"], boxes, labels)

run()
