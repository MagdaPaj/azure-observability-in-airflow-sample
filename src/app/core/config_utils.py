import logging
import os
from dotenv import load_dotenv


load_dotenv()

LOGGING_LEVEL = os.getenv('LOGGING_LEVEL', 'INFO').upper()
logging.basicConfig(format='%(levelname)s %(filename)s: %(message)s', level=LOGGING_LEVEL)
logger = logging.getLogger()


def get_env_variable(env_var_name: str) -> str:
    value = os.getenv(env_var_name, '')
    if value == '':
        msg = f"Environment variable '{env_var_name}' is missing!"
        logger.error(msg)
        raise ValueError(msg)

    return value
