import atexit
import sys
import os
import time
import readline
import inspect
import pyperclip

import math
import cmath
from math import *
from cmath import *


def c():
    global _
    try:
        pyperclip.copy(str(_))
    except Exception:
        pass
    return


try:
    histfile = os.environ["PYTHONHISTFILE"]
    readline.read_history_file(histfile)
except Exception:
    pass

atexit.register(readline.write_history_file, histfile)
atexit.register(c)

print("\n====== Real and/or Complex functions: ======", end="")
math_names = [f[0] for f in inspect.getmembers(math) if not f[0].startswith("__")]
math_names += [f[0] for f in inspect.getmembers(cmath) if not f[0].startswith("__")]
math_names = sorted(list(set(math_names)))

max_width = 85
max_name_length = max(len(name) for name in math_names)
num_columns = max_width // max_name_length

sublists = [[] for _ in range(num_columns)]
[sublists[i % num_columns].append(math_names[i]) for i in range(len(math_names))]
max_lengths = [max(len(name) for name in sub) for sub in sublists]

for i, name in enumerate(math_names):
    if i % num_columns == 0:
        print("")
    max_len = max_lengths[i % num_columns]
    print(f"{name:{max_len}}", end=" ")
print("\n")

i = 1j
j = 1j
Pi = PI = pi
E = e
print("i := j := sqrt(-1)")
print("_ := last result")
print("c() to copy last result")

sys.ps1 = ">>> "
sys.ps2 = "··· "
