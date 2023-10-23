import subprocess
import sys
import socket
from PIL import Image
from io import BytesIO

print("Starting render server")
SERVER_IP = sys.argv[1]
SERVER_PORT = int(sys.argv[2])

print("Waiting for client to connect")
server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)  # Create a TCP/IP socket
server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)  # To get over local TIME_WAIT state
server_socket.bind((SERVER_IP, SERVER_PORT))  # Bind the socket to the IP address and port
server_socket.listen(1)  # Listen for incoming connections
client_socket, client_address = server_socket.accept()  # Wait for a client to connect

command = [
  'ffmpeg', '-y',  # Overwrite output file if it already exists
  '-f', 'image2pipe',  # Input format: image sequence
  '-r', str(25),  # Frame rate
  '-i', '-',  # Read input from pipe
  '-c:v', 'libvpx-vp9',  # VP9 video codec
  '-b:v', '1M',  # Video bitrate
  '-pix_fmt', 'yuv444p',  # Pixel format - default: yuv420p
  '-f', 'webm',  # Output format: WebM
  'output_video.webm'  # Output file path
]

print("Starting FFMPEG")
process = subprocess.Popen(command, stdin=subprocess.PIPE)

image_data = b""  # Buffer to store the received image data
is_receiving_image = False  # Flag to indicate whether currently receiving an image


while True:
  # Receive data from the client
  print("Waiting for data")
  data = client_socket.recv(4096)

  if not data:  # Client disconnected
    break


  # TODO: There is still a problem with multiple packets arriving together and blocking the end_image message
  # Because of this some frames are getting lost, maybe look for end_image inside of the data and split the data?
  # Possibly just splitting the data the moment there is an end_image, check afterwards how many entries there are
  # and divide the data by data[0], data[1], ... to load all images separately without too much trouble
  if is_receiving_image:
    image_data += data  # Append received data to the image buffer
    stop_received = False
    if image_data.endswith(b"end_imagestop"):
      print("Stop received")
      image_data = image_data[:-len(b"stop")]
      stop_received = True
    if image_data.endswith(b"end_image"):
      try:
        # Remove the marker from the image data
        image_data = image_data[:-len(b"end_image")]
        
        ## Create an image from the received data
        ## More debugging stuff which I prefer to have here for now hahah
        #image = Image.open(BytesIO(image_data))
        #image.save("received_image.png", "PNG")
        #print("Image saved as 'received_image.png'")
        
        process.stdin.write(image_data)
        process.stdin.flush()  # Flush the input buffer after writing each image

        is_receiving_image = False
        image_data = b""
      except Exception as e:
        print("Received data is not a valid image.")
    if stop_received:
      break
  else:
    try:
      data_string = data.decode('utf-8')
      print("Received string:", data_string)
      if data_string == "stop":
        print("Stop received")
        break
    except UnicodeDecodeError:
      # Assume it's the start of an image
      print("Receiving image")
      image_data = data  # Initialize the image buffer with the received data
      is_receiving_image = True

  # Some debug stuff that I'm leaving here for now
  #print(data)
  #client_socket.sendall("Received data\n".encode())


# Close FFmpeg process
process.stdin.close()
process.wait()

# Close the connection
client_socket.close()
print('Connection closed')