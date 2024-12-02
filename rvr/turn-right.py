import os

import sys

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), './sphero-sdk-raspberrypi-python')))



import asyncio

from sphero_sdk import SpheroRvrAsync

from sphero_sdk import SerialAsyncDal

from sphero_sdk import RawMotorModesEnum





loop = asyncio.get_event_loop()



rvr = SpheroRvrAsync(

    dal=SerialAsyncDal(

        loop

    )

)




async def main(speed: int = 128):

    """ This program has RVR drive around in different directions.

    """

    speed = max(0, min(255, int(speed)))
    print(f"Speed: {speed}")


    await rvr.wake()





    await rvr.reset_yaw()







    try:
        while True:  # Boucle principale
            await rvr.raw_motors(
                left_mode=RawMotorModesEnum.forward.value,
                left_duty_cycle=speed,  # Valid speed values are 0-255
                right_mode=RawMotorModesEnum.reverse.value,
                right_duty_cycle=speed  # Valid speed values are 0-255
            )
            await asyncio.sleep(0.1)  # Délai pour éviter une surcharge inutile
    except asyncio.CancelledError:
        print("Boucle principale annulée.")
    except KeyboardInterrupt:
        print("\nProgramme interrompu par l'utilisateur.")
    finally:
        await rvr.raw_motors(
            left_mode=RawMotorModesEnum.off.value,
            left_duty_cycle=0,
            right_mode=RawMotorModesEnum.off.value,
            right_duty_cycle=0
        )
        await rvr.close()





    # await rvr.close()




if __name__ == '__main__':
    try:
        if len(sys.argv) < 2:
            print("Usage: python3 turn-right.py <vitesse (0-255)>")
            sys.exit(1)

        vitesse = sys.argv[1]
        stop_requested = False

        loop.run_until_complete(main(vitesse))


    except KeyboardInterrupt:

        print("\nProgramme interrompu par l'utilisateur.")

    finally:

        if loop.is_running():
            loop.close()