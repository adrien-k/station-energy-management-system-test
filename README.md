# EV Charging Station Power Management System

This is a Ruby-based power management system for electric vehicle charging stations. It intelligently allocates power across multiple charging sessions while respecting hardware constraints and optimizing for fair distribution.

## Requirements

- Ruby 3.2 or Docker

## Features

- **Intelligent Power Allocation**: Automatically distributes available power across active charging sessions
- **Battery Integration**: Supports battery storage systems for peak shaving and grid optimization
- **Multi-Charger Support**: Manages multiple chargers with different power capacities
- **Real-time Monitoring**: Provides live status updates on power allocation and session management
- **RESTful API**: Clean HTTP API for integration with charging station management systems

## Power Allocation Algorithm

The power allocation system uses a sophisticated two-phase algorithm to ensure optimal and fair power distribution:

**Phase 1 - Constraint Analysis**: The system first analyzes the power tree structure, calculating the maximum power each charging session can receive while respecting hardware constraints. For chargers with multiple connectors, power is distributed evenly among active sessions, with each session's allocation capped by both the charger's maximum power and the vehicle's maximum charging capability.

**Phase 2 - Iterative Power Distribution**: Once constraints are established, the system iteratively distributes available power in equal shares to all sessions that haven't reached their maximum capacity. The algorithm continues this process until all available power is allocated or all sessions reach their limits. Power is allocated in full kW increments to ensure practical implementation.

**Battery Integration**: The system intelligently manages battery storage to optimize power distribution. As long as the battery has sufficient capacity, its power can be distributed alongside grid power to meet charging demands. Conversely, when grid capacity is not fully utilized, the battery will charge back to its initial capacity, effectively storing excess energy for future use.

This approach ensures that:
- No hardware limits are exceeded
- Power is distributed fairly among all active sessions
- Available power is maximally utilized (including battery storage)
- The system can dynamically adapt as sessions start, stop, or change their power requirements
- Battery storage is optimally utilized for both power distribution and energy storage

## API Endpoints

### GET /station/status
Returns the current status of the charging station including active sessions, power allocation, and battery status.

Open http://localhost:4567/station/status to explore it.

### POST /sessions
Start a new charging session.
```json
{
  "chargerId": "CP001",
  "connectorId": 0,
  "vehicleMaxPower": 150
}
```

### POST /sessions/:session_id/stop
Stop an active charging session.
```json
{
  "consumedEnergy": 25.5
}
```

### POST /sessions/:session_id/power-update
Update power consumption for an active session.
```json
{
  "consumedPower": 120.0,
  "vehicleMaxPower": 150
}
```

## Configuration

The system is configured via `config.json`:

```json
{
  "stationId": "EV_STATION_PARIS_15",
  "gridCapacity": 400,
  "chargers": [
    {"id": "CP001", "maxPower": 200, "connectors": 2}, 
    {"id": "CP002", "maxPower": 200, "connectors": 2},
    {"id": "CP003", "maxPower": 300, "connectors": 2}
  ],
  "battery": {
    "initialCapacity": 200,
    "power": 100
  }
}
```

## Running with Docker

```bash
# Build the image
docker build -t ev-charging-system .

# Run the container
docker run -p 4567:4567 ev-charging-system

# Run the tests
docker run --rm ev-charging-system bundle exec rspec
```

## Local development

```bash
# Install dependencies
bundle install

# Run the application
./api.rb

# Run tests
bundle exec rspec
```
