"""Godot roundi semantics for finite EXP calculations (half away from zero)."""
import math


def roundi(value):
    return math.floor(value + 0.5) if value >= 0 else math.ceil(value - 0.5)
