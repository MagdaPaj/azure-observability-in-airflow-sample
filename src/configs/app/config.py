import os


def to_dict() -> dict:
    return {
        'USER': os.environ['USER'].strip('"')
    }
