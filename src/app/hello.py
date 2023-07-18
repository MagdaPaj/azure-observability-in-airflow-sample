import logging
import core.user_config as user_config

logger = logging.getLogger()


def hello():
    logger.info(f"Hello {user_config.username} from Airflow")


if __name__ == '__main__':
    hello()
