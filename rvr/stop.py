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






async def main():
    """
    Fonction pour arrêter le RVR.
    """
    global stop_requested
    stop_requested = True
    await rvr.raw_motors(
        left_mode=RawMotorModesEnum.forward.value,
        left_duty_cycle=0,
        right_mode=RawMotorModesEnum.reverse.value,
        right_duty_cycle=0
    )
    await asyncio.sleep(0.1)  # Petite pause pour terminer les tâches en cours
    await rvr.close()




if __name__ == '__main__':
    try:
        loop.run_until_complete(main())
    except KeyboardInterrupt:
        print("\nProgramme interrompu par l'utilisateur.")
    finally:
        if loop.is_running():
            loop.close()
