from flask import Flask, request, jsonify

app = Flask(__name__)

# store bus locations
bus_locations = {
    "bus1": {"lat": 0, "lng": 0},
    "bus2": {"lat": 0, "lng": 0}
}

# receive GPS from phones
@app.route('/update', methods=['POST'])
def update_location():
    data = request.json
    bus = data.get("bus")
    lat = data.get("lat")
    lng = data.get("lng")

    if bus in bus_locations:
        bus_locations[bus]["lat"] = lat
        bus_locations[bus]["lng"] = lng
        print(f"{bus} updated: {lat}, {lng}")

    return jsonify({"status": "ok"})

# send data to laptop viewer
@app.route('/locations', methods=['GET'])
def get_locations():
    return jsonify(bus_locations)

app.run(host="0.0.0.0", port=5000)
