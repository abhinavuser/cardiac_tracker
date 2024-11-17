from flask import Flask
from flask_socketio import SocketIO
import serial
import threading
import time
import serial.tools.list_ports
import json
import numpy as np
import os

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

ser = None
SAMPLE_RATE = 200

def find_and_release_port():
    """Find the Arduino port and attempt to release it if busy"""
    for port in serial.tools.list_ports.comports():
        if "CH340" in port.description:
            try:
                # Try to open and close the port to release it
                temp_ser = serial.Serial(port.device)
                temp_ser.close()
                print(f"Successfully released {port.device}")
            except Exception as e:
                print(f"Error releasing {port.device}: {e}")
            return port.device
    return "COM3"

def initialize_serial():
    global ser
    max_attempts = 3
    current_attempt = 0
    
    while current_attempt < max_attempts:
        try:
            # Close existing connection if any
            if ser is not None and ser.is_open:
                ser.close()
                time.sleep(1)
            
            port = find_and_release_port()
            print(f"Attempt {current_attempt + 1}: Connecting to {port}")
            
            # Try to open the port with different settings
            ser = serial.Serial(
                port=port,
                baudrate=115200,
                timeout=1,
                write_timeout=1,
                exclusive=True
            )
            
            if ser.is_open:
                print(f"Successfully connected to {port}")
                time.sleep(2)  # Wait for connection to stabilize
                return True
                
        except serial.SerialException as e:
            print(f"Serial Exception: {e}")
            current_attempt += 1
            time.sleep(2)
            
        except Exception as e:
            print(f"Unexpected error: {e}")
            current_attempt += 1
            time.sleep(2)
    
    print("Failed to connect after maximum attempts")
    return False

def read_serial():
    global ser
    last_heart_rate = 60.0
    
    while True:
        try:
            if ser is None or not ser.is_open:
                if not initialize_serial():
                    print("Waiting before retry...")
                    time.sleep(5)
                    continue

            if ser.in_waiting > 0:
                try:
                    line = ser.readline().decode('utf-8').strip()
                    print(f"Raw data received: {line}")
                    
                    # Parse comma-separated values
                    raw_value, bpm = map(float, line.split(','))
                    
                    # Normalize the raw value between -1 and 1
                    normalized_value = (raw_value - 2048) / 2048.0  # Assuming 12-bit ADC
                    
                    # Update heart rate if valid
                    if 40 <= bpm <= 200:
                        last_heart_rate = bpm
                    
                    # Create and emit message
                    message = ["ecg_data", {
                        "value": normalized_value,
                        "heart_rate": last_heart_rate
                    }]
                    formatted_message = f"42{json.dumps(message)}"
                    print(f"Emitting: {formatted_message}")
                    socketio.emit("message", formatted_message)
                    
                except ValueError as e:
                    print(f"Invalid data received: {line}, Error: {e}")
                except Exception as e:
                    print(f"Error processing data: {e}")
            
        except Exception as e:
            print(f"Serial read error: {e}")
            if ser:
                try:
                    ser.close()
                except:
                    pass
                ser = None
            time.sleep(5)

@socketio.on("connect")
def handle_connect():
    print("Client connected")
    socketio.emit("message", "40")

@socketio.on("disconnect")
def handle_disconnect():
    print("Client disconnected")

def cleanup():
    global ser
    if ser:
        ser.close()

if __name__ == "__main__":
    # Try to run with elevated privileges on Windows
    if os.name == 'nt':  # Windows
        try:
            import ctypes
            if not ctypes.windll.shell32.IsUserAnAdmin():
                print("Try running as administrator for better port access")
        except:
            pass
    
    try:
        thread = threading.Thread(target=read_serial, daemon=True)
        thread.start()
        print("Starting server...")
        socketio.run(app, host="0.0.0.0", port=5000, debug=True)
    finally:
        cleanup()