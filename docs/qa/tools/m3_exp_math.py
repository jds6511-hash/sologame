"""Godot roundi semantics for finite EXP calculations (half away from zero)."""
import math


def roundi(value):
    return math.floor(value + 0.5) if value >= 0 else math.ceil(value - 0.5)


def requirement(curve, level):
    multiplier = (curve.get("pre_transition_req_multiplier", 1.0)
                  if level < curve.get("first_transition_level", 10) else 1.0)
    if curve.get("profile", 0) == 1 and level > curve.get("c1_blend_start_level", 10):
        start = curve.get("c1_blend_start_level", 10)
        end = curve.get("c1_blend_end_level", 20)
        blend = min(1.0, max(0.0, (level - start) / (end - start)))
        multiplier *= curve.get("c1_multiplier", 0.4) ** blend
    return roundi(curve["req_coefficient"] * level ** curve["req_exponent"] * multiplier)
