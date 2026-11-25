-- qqfeiche3d qn. Source units and radians are retained inside the simulation.
return {
    dt = 1 / 120, snapshotHz = 20, inputHz = 30, maxFrame = 0.05,
    inputChannel = "RacingClone.Input.v1",
    vmax = 55, vmaxNitro = 76, accel = 24, nitroAccel = 40,
    brake = 45, reverseMax = 12, roll = 2.2, turnRate = 1.9, grip = 12,
    driftMinSpeed = 13, driftYaw = 1.5, driftYawAlign = 0.85,
    driftGrip = 2, driftGripRelease = 5.2, maxDriftAngle = 1.15,
    smallWindow = 0.5, gaugeRate = 0.36, nitroTime = 2.8, gravity = 30,
    cameraModes = {
        {dist = 8.2, height = 3, look = 5, lookHeight = 1.3},
        {dist = 12.5, height = 4.6, look = 6, lookHeight = 1.5},
        {dist = 5.2, height = 1.9, look = 8, lookHeight = 1.1}
    }
}
