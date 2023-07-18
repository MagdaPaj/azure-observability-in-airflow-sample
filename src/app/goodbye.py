import logging
import core.user_config as user_config

logger = logging.getLogger()


def goodbye():
    logger.info(f"Goodbye {user_config.username} from Airflow")


if __name__ == '__main__':
    goodbye()
