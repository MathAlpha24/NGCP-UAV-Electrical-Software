
import asyncio
from flight_path_planner import FlightPathPlanner, GridPathPlanner
from mavsdk_flight_controller import MAVSDKFlightController


async def main():
    planner = FlightPathPlanner(
        home_lat=47.3977419,
        home_lon=8.5455743,
        home_alt=400
    )

    planner.add_waypoint(47.3977419, 8.5455743, 500)
    planner.add_waypoint(47.3976900, 8.5456200, 550)
    planner.add_waypoint(47.3976400, 8.5455700, 500)
    planner.add_waypoint(47.3977419, 8.5455743, 400)

    flight_path = planner.generate_path()

    print(f"Flight path generated:")
    print(f"  Total distance: {flight_path.total_distance:.2f}m")
    print(f"  Estimated duration: {flight_path.estimated_duration:.2f}s")
    print(f"  Number of waypoints: {len(flight_path.waypoints)}")

    for i, wp in enumerate(flight_path.waypoints):
        if i > 0:
            distance = planner.calculate_distance(flight_path.waypoints[i-1], wp)
            bearing = planner.calculate_bearing(flight_path.waypoints[i-1], wp)
            print(f"  WP{i}: ({wp.latitude:.6f}, {wp.longitude:.6f}) alt={wp.altitude}m - "
                  f"distance={distance:.2f}m, bearing={bearing:.1f}°")
        else:
            print(f"  WP{i} (HOME): ({wp.latitude:.6f}, {wp.longitude:.6f}) alt={wp.altitude}m")

    fuel_consumption = planner.calculate_fuel_consumption(power_watts=500, voltage=12.0, flight_path=flight_path)
    print(f"\nEstimated battery consumption: {fuel_consumption:.2f}Ah")


if __name__ == "__main__":
    asyncio.run(main())
