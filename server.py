import json
import time
from datetime import datetime
from collections import deque
import os
from flask import Flask, jsonify
from flask_cors import CORS
import serial
import threading
import serial.tools.list_ports

app = Flask(__name__)
CORS(app)

# Configuration
DATA_FILE = "ecg_data.json"
MAX_READINGS = 1000  # Maximum number of readings to store
readings_buffer = deque(maxlen=MAX_READINGS)

def save_to_json():
    """Save the buffer to JSON file periodically"""
    while True:
        try:
            with open(DATA_FILE, 'w') as f:
                json.dump({
                    'last_updated': datetime.now().isoformat(),
                    'readings': list(readings_buffer)
                }, f)
        except Exception as e:
            print(f"Error saving to JSON: {e}")
        time.sleep(1)  # Save every second

def find_and_release_port():
    """Find the Arduino port and attempt to release it if busy"""
    for port in serial.tools.list_ports.comports():
        if "CH340" in port.description:
            try:
                temp_ser = serial.Serial(port.device)
                temp_ser.close()
                print(f"Successfully released {port.device}")
            except Exception as e:
                print(f"Error releasing {port.device}: {e}")
            return port.device
    return "COM3"

def read_serial():
    """Read from serial port and store in buffer"""
    ser = None
    last_heart_rate = 60.0
    
    while True:
        try:
            if ser is None or not ser.is_open:
                port = find_and_release_port()
                ser = serial.Serial(port=port, baudrate=115200, timeout=1)
                time.sleep(2)
                continue

            if ser.in_waiting > 0:
                line = ser.readline().decode('utf-8').strip()
                try:
                    raw_value, bpm = map(float, line.split(','))
                    normalized_value = (raw_value - 2048) / 2048.0
                    
                    if 40 <= bpm <= 200:
                        last_heart_rate = bpm
                    
                    reading = {
                        'timestamp': datetime.now().isoformat(),
                        'value': normalized_value,
                        'heart_rate': last_heart_rate
                    }
                    readings_buffer.append(reading)
                    
                except ValueError as e:
                    print(f"Invalid data received: {line}, Error: {e}")
                    
        except Exception as e:
            print(f"Serial read error: {e}")
            if ser:
                ser.close()
            ser = None
            time.sleep(5)

@app.route('/ecg-data', methods=['GET'])
def get_ecg_data():
    try:
        with open(DATA_FILE, 'r') as f:
            return jsonify(json.load(f))
    except FileNotFoundError:
        return jsonify({'error': 'No data available yet'}), 404

if __name__ == "__main__":
    # Start the serial reading thread
    serial_thread = threading.Thread(target=read_serial, daemon=True)
    serial_thread.start()
    
    # Start the JSON saving thread
    save_thread = threading.Thread(target=save_to_json, daemon=True)
    save_thread.start()
    
    # Run the Flask app
    app.run(host='0.0.0.0', port=5000, debug=True, use_reloader=False)