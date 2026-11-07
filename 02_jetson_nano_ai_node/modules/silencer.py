import os
import sys
from contextlib import contextmanager

@contextmanager
def suppress_stderr():
    """徹底封鎖 ALSA lib 的廢話輸出"""
    with open(os.devnull, 'w') as devnull:
        old_stderr = sys.stderr
        sys.stderr = devnull
        try:
            yield
        finally:
            sys.stderr = old_stderr
