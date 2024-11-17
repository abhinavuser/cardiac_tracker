from flask import Flask
from flask_socketio import SocketIO
import serial
import threading
import time
import serial.tools.list_ports
import json

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

ser = None

def find_arduino_port():
    ports = list(serial.tools.list_ports.comports())
    print("Available ports:")
    for port in ports:
        print(f"Port: {port.device}, Description: {port.description}")
        if "Arduino" in port.description or "CH340" in port.description:
            return port.device
    return None

def initialize_serial():
    global ser
    try:
        if ser is not None and ser.is_open:
            ser.close()
            
        arduino_port = find_arduino_port()
        port_to_use = arduino_port if arduino_port else "COM3"
            
        print(f"Attempting to connect to {port_to_use}")
        
        ser = serial.Serial(
            port=port_to_use,
            baudrate=115200,
            timeout=1
        )
        
        time.sleep(2)
        
        if ser.is_open:
            print(f"Successfully connected to {port_to_use}")
            return True
            
    except Exception as e:
        print(f"Error connecting to serial port: {e}")
        if ser:
            ser.close()
            ser = None
        return False

def read_serial():
    global ser
    last_emit_time = time.time()
    
    while True:
        try:
            if ser is None or not ser.is_open:
                if initialize_serial():
                    time.sleep(2)
                else:
                    time.sleep(5)
                continue

            if ser.in_waiting > 0:
                data = ser.readline().decode("utf-8").strip()
                
                # Only emit every 5 seconds
                current_time = time.time()
                if current_time - last_emit_time >= 5:
                    try:
                        value = float(data)
                        print(f"Emitting value: {value}")
                        socketio.emit("42ecg_data", {"data": ["ecg_data", {"value": value}]})
                        last_emit_time = current_time
                    except ValueError:
                        print(f"Invalid data received: {data}")
                else:
                    # Clear the buffer
                    ser.reset_input_buffer()
                    
        except Exception as e:
            print(f"Error reading serial data: {e}")
            if ser:
                ser.close()
                ser = None
            time.sleep(5)

@app.route("/")
def index():
    return "ECG WebSocket Server Running"

@socketio.on("connect")
def handle_connect():
    print("Client connected")

@socketio.on("disconnect")
def handle_disconnect():
    print("Client disconnected")

def cleanup():
    global ser
    if ser:
        ser.close()
        ser = None

if __name__ == "__main__":
    try:
        thread = threading.Thread(target=read_serial, daemon=True)
        thread.start()
        socketio.run(app, host="0.0.0.0", port=5000, debug=False)
    finally:
        cleanup()