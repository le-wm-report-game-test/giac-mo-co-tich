#!/usr/bin/env python3
"""
Tarzan Jungle Warrior Sprite Generator v2
Generates high-quality pixel art sprite sheets for a Tarzan-like character
"""
import struct, os, math, random
from PIL import Image

CANVAS_W = 64
CANVAS_H = 64

# Color palette - Tarzan jungle warrior (richer colors)
SKIN = (210, 160, 110)
SKIN_SHADOW = (170, 125, 80)
SKIN_DARK = (140, 100, 60)
SKIN_HIGHLIGHT = (235, 190, 140)
HAIR = (55, 30, 15)
HAIR_LIGHT = (85, 55, 30)
PANTS = (100, 60, 30)
PANTS_DARK = (70, 40, 20)
PANTS_LIGHT = (130, 85, 50)
AXE_HANDLE = (120, 80, 40)
AXE_HANDLE_DARK = (90, 55, 25)
AXE_BLADE = (165, 165, 165)
AXE_BLADE_DARK = (120, 120, 125)
AXE_BLADE_LIGHT = (200, 200, 205)
EYE = (35, 25, 15)
MOUTH = (80, 40, 30)
BAND = (180, 50, 50)  # Red headband
BAND_DARK = (140, 35, 35)

def set_pixel(img, x, y, color):
    if 0 <= x < CANVAS_W and 0 <= y < CANVAS_H:
        img.putpixel((x, y), color)

def draw_rect(img, x1, y1, x2, y2, color):
    for y in range(max(0, y1), min(CANVAS_H, y2+1)):
        for x in range(max(0, x1), min(CANVAS_W, x2+1)):
            set_pixel(img, x, y, color)

def draw_circle(img, cx, cy, r, color):
    for y in range(cy-r, cy+r+1):
        for x in range(cx-r, cx+r+1):
            dx, dy = x-cx, y-cy
            if dx*dx + dy*dy <= r*r:
                set_pixel(img, x, y, color)

def draw_line(img, x1, y1, x2, y2, color):
    dx = abs(x2 - x1)
    dy = abs(y2 - y1)
    sx = 1 if x1 < x2 else -1
    sy = 1 if y1 < y2 else -1
    err = dx - dy
    x, y = x1, y1
    while True:
        set_pixel(img, x, y, color)
        if x == x2 and y == y2:
            break
        e2 = 2 * err
        if e2 > -dy:
            err -= dy
            x += sx
        if e2 < dx:
            err += dx
            y += sy

def draw_body_base(img, cx, ground, torso_top, y_off=0, scale=1.0):
    """Draw the basic Tarzan body (legs, torso, head)"""
    s = scale
    # Legs
    draw_rect(img, cx-int(3*s), ground-int(14*s)+y_off, cx-int(1*s), ground+y_off, PANTS)
    draw_rect(img, cx+int(1*s), ground-int(14*s)+y_off, cx+int(3*s), ground+y_off, PANTS_DARK)
    # Knee highlights
    draw_rect(img, cx-int(3*s), ground-int(8*s)+y_off, cx-int(1*s), ground-int(6*s)+y_off, PANTS_LIGHT)
    draw_rect(img, cx+int(1*s), ground-int(8*s)+y_off, cx+int(3*s), ground-int(6*s)+y_off, PANTS_LIGHT)
    # Feet
    draw_rect(img, cx-int(4*s), ground+y_off, cx-int(1*s), ground+int(2*s)+y_off, SKIN_SHADOW)
    draw_rect(img, cx+int(1*s), ground+y_off, cx+int(4*s), ground+int(2*s)+y_off, SKIN_SHADOW)
    # Toes
    set_pixel(img, cx-int(4*s), ground+int(2*s)+y_off, SKIN_DARK)
    set_pixel(img, cx+int(4*s), ground+int(2*s)+y_off, SKIN_DARK)
    
    # Torso - muscular chest
    draw_rect(img, cx-int(5*s), torso_top+y_off, cx+int(5*s), ground-int(14*s)+y_off, SKIN)
    # Pecs
    draw_rect(img, cx-int(5*s), torso_top+int(4*s)+y_off, cx-int(1*s), torso_top+int(8*s)+y_off, SKIN_HIGHLIGHT)
    draw_rect(img, cx+int(1*s), torso_top+int(4*s)+y_off, cx+int(5*s), torso_top+int(8*s)+y_off, SKIN_HIGHLIGHT)
    # Abs
    draw_rect(img, cx-int(3*s), torso_top+int(8*s)+y_off, cx-int(1*s), torso_top+int(11*s)+y_off, SKIN_SHADOW)
    draw_rect(img, cx+int(1*s), torso_top+int(8*s)+y_off, cx+int(3*s), torso_top+int(11*s)+y_off, SKIN_SHADOW)
    # Belly button
    set_pixel(img, cx, torso_top+int(10*s)+y_off, SKIN_DARK)
    # Shoulders
    draw_rect(img, cx-int(7*s), torso_top+y_off, cx-int(5*s), torso_top+int(4*s)+y_off, SKIN_SHADOW)
    draw_rect(img, cx+int(5*s), torso_top+y_off, cx+int(7*s), torso_top+int(4*s)+y_off, SKIN_SHADOW)
    
    # Neck
    draw_rect(img, cx-int(2*s), torso_top-int(2*s)+y_off, cx+int(2*s), torso_top+y_off, SKIN_SHADOW)
    
    # Head
    head_bottom = torso_top - int(2*s) + y_off
    head_top = torso_top - int(8*s) + y_off
    draw_rect(img, cx-int(4*s), head_top, cx+int(4*s), head_bottom, SKIN)
    # Jaw line
    draw_rect(img, cx-int(4*s), head_bottom-int(1*s), cx+int(4*s), head_bottom, SKIN_SHADOW)
    
    # Wild hair
    draw_rect(img, cx-int(5*s), head_top-int(2*s), cx+int(5*s), head_top, HAIR)
    draw_rect(img, cx-int(6*s), head_top-int(1*s), cx-int(4*s), head_top+int(1*s), HAIR)
    draw_rect(img, cx+int(4*s), head_top-int(1*s), cx+int(6*s), head_top+int(1*s), HAIR)
    draw_rect(img, cx-int(3*s), head_top-int(3*s), cx+int(3*s), head_top-int(2*s), HAIR)
    # Hair highlights
    draw_rect(img, cx-int(4*s), head_top-int(2*s), cx-int(2*s), head_top-int(1*s), HAIR_LIGHT)
    draw_rect(img, cx+int(2*s), head_top-int(2*s), cx+int(4*s), head_top-int(1*s), HAIR_LIGHT)
    
    # Red headband
    draw_rect(img, cx-int(5*s), head_top+int(1*s), cx+int(5*s), head_top+int(2*s), BAND)
    # Headband tails
    draw_rect(img, cx-int(6*s), head_top+int(2*s), cx-int(5*s), head_top+int(4*s), BAND)
    draw_rect(img, cx-int(5*s), head_top+int(3*s), cx-int(4*s), head_top+int(5*s), BAND_DARK)
    
    return cx, ground, head_top, head_bottom

def draw_eyes(img, cx, ey, facing_right=True, angry=False):
    if angry:
        # Angry eyebrows
        draw_rect(img, cx-4, ey-2, cx-1, ey-1, HAIR)
        draw_rect(img, cx+1, ey-2, cx+4, ey-1, HAIR)
    if facing_right:
        set_pixel(img, cx+1, ey, EYE)
        set_pixel(img, cx+3, ey, EYE)
        if angry:
            set_pixel(img, cx+2, ey-1, (255,255,255))
            set_pixel(img, cx+4, ey-1, (255,255,255))
    else:
        set_pixel(img, cx-3, ey, EYE)
        set_pixel(img, cx-1, ey, EYE)
        if angry:
            set_pixel(img, cx-4, ey-1, (255,255,255))
            set_pixel(img, cx-2, ey-1, (255,255,255))

def draw_mouth(img, cx, my, open_w=False):
    if open_w:
        draw_rect(img, cx-2, my, cx+2, my+1, MOUTH)
        draw_rect(img, cx-1, my+1, cx+1, my+2, (60, 25, 20))
    else:
        draw_rect(img, cx-1, my, cx+1, my, MOUTH)

def draw_axe(img, cx, cy, angle_rad, facing_right=True, length=16):
    """Draw stone axe at given angle"""
    handle_len = length
    hx = int(math.cos(angle_rad) * handle_len)
    hy = int(math.sin(angle_rad) * handle_len)
    
    if facing_right:
        draw_line(img, cx, cy, cx + hx, cy + hy, AXE_HANDLE)
        draw_line(img, cx, cy+1, cx + hx, cy + hy+1, AXE_HANDLE_DARK)
        # Blade at tip
        bx, by = cx + hx, cy + hy
        draw_rect(img, bx-2, by-4, bx+2, by+2, AXE_BLADE)
        draw_rect(img, bx-1, by-5, bx+1, by-4, AXE_BLADE_DARK)
        draw_rect(img, bx-1, by+2, bx+1, by+3, AXE_BLADE_DARK)
        draw_rect(img, bx-3, by-3, bx-2, by+1, AXE_BLADE_DARK)
        draw_rect(img, bx+2, by-3, bx+3, by+1, AXE_BLADE_LIGHT)
    else:
        draw_line(img, cx, cy, cx - hx, cy + hy, AXE_HANDLE)
        draw_line(img, cx, cy+1, cx - hx, cy + hy+1, AXE_HANDLE_DARK)
        bx, by = cx - hx, cy + hy
        draw_rect(img, bx-2, by-4, bx+2, by+2, AXE_BLADE)
        draw_rect(img, bx-1, by-5, bx+1, by-4, AXE_BLADE_DARK)
        draw_rect(img, bx-1, by+2, bx+1, by+3, AXE_BLADE_DARK)
        draw_rect(img, bx-3, by-3, bx-2, by+1, AXE_BLADE_LIGHT)
        draw_rect(img, bx+2, by-3, bx+3, by+1, AXE_BLADE_DARK)

def draw_tarzan_idle(img, frame=0, facing_right=True):
    """Idle animation - breathing with slight body sway"""
    cx = CANVAS_W // 2
    ground = CANVAS_H - 4
    torso_top = ground - 26
    
    sway = int(math.sin(frame * 0.8) * 1)
    breath = int(math.sin(frame * 0.5) * 1)
    
    cx, ground, head_top, head_bottom = draw_body_base(img, cx, ground, torso_top, sway)
    
    # Breathing chest
    if breath > 0:
        draw_rect(img, cx-5, torso_top+4+sway, cx+5, torso_top+5+sway, SKIN_HIGHLIGHT)
    
    # Arms hanging relaxed
    if facing_right:
        draw_rect(img, cx+5, torso_top+sway, cx+8, torso_top+8+sway, SKIN)
        draw_rect(img, cx+7, torso_top+sway, cx+9, torso_top+4+sway, SKIN_SHADOW)
        draw_rect(img, cx-8, torso_top+sway, cx-5, torso_top+8+sway, SKIN)
        draw_rect(img, cx-9, torso_top+sway, cx-7, torso_top+4+sway, SKIN_SHADOW)
    else:
        draw_rect(img, cx-8, torso_top+sway, cx-5, torso_top+8+sway, SKIN)
        draw_rect(img, cx+5, torso_top+sway, cx+8, torso_top+8+sway, SKIN)
    
    # Eyes
    draw_eyes(img, cx, head_top+5+sway, facing_right)
    draw_mouth(img, cx, head_top+7+sway)
    
    # Axe held at rest
    if facing_right:
        draw_axe(img, cx+7, torso_top+8+sway, math.radians(-60), True, 14)
    else:
        draw_axe(img, cx-7, torso_top+8+sway, math.radians(-60), False, 14)

def draw_tarzan_walk(img, frame, facing_right=True):
    """Walk animation - 8 frame cycle with arm/leg swing"""
    cx = CANVAS_W // 2
    ground = CANVAS_H - 4
    torso_top = ground - 26
    
    phase = (frame % 8) / 8.0
    leg_swing = int(math.sin(phase * 2 * math.pi) * 4)
    arm_swing = int(math.sin(phase * 2 * math.pi + math.pi) * 3)
    bounce = int(abs(math.sin(phase * 2 * math.pi)) * 2)
    
    y_off = -bounce
    
    # Legs (alternating)
    draw_rect(img, cx-3, ground-14+leg_swing+y_off, cx-1, ground+y_off, PANTS)
    draw_rect(img, cx+1, ground-14-leg_swing+y_off, cx+3, ground+y_off, PANTS_DARK)
    draw_rect(img, cx-3, ground-8+leg_swing+y_off, cx-1, ground-6+leg_swing+y_off, PANTS_LIGHT)
    draw_rect(img, cx+1, ground-8-leg_swing+y_off, cx+3, ground-6-leg_swing+y_off, PANTS_LIGHT)
    
    # Feet
    foot_off = int(math.sin(phase * 2 * math.pi) * 2)
    draw_rect(img, cx-4+foot_off, ground+y_off, cx-1+foot_off, ground+2+y_off, SKIN_SHADOW)
    draw_rect(img, cx+1-foot_off, ground+y_off, cx+4-foot_off, ground+2+y_off, SKIN_SHADOW)
    
    # Torso
    draw_rect(img, cx-5, torso_top+y_off, cx+5, ground-14+y_off, SKIN)
    draw_rect(img, cx-5, torso_top+4+y_off, cx-1, torso_top+8+y_off, SKIN_HIGHLIGHT)
    draw_rect(img, cx+1, torso_top+4+y_off, cx+5, torso_top+8+y_off, SKIN_HIGHLIGHT)
    draw_rect(img, cx-3, torso_top+8+y_off, cx-1, torso_top+11+y_off, SKIN_SHADOW)
    draw_rect(img, cx+1, torso_top+8+y_off, cx+3, torso_top+11+y_off, SKIN_SHADOW)
    draw_rect(img, cx-int(7), torso_top+y_off, cx-int(5), torso_top+4+y_off, SKIN_SHADOW)
    draw_rect(img, cx+int(5), torso_top+y_off, cx+int(7), torso_top+4+y_off, SKIN_SHADOW)
    
    # Neck
    draw_rect(img, cx-2, torso_top-2+y_off, cx+2, torso_top+y_off, SKIN_SHADOW)
    
    # Head
    head_bottom = torso_top - 2 + y_off
    head_top = torso_top - 8 + y_off
    draw_rect(img, cx-4, head_top, cx+4, head_bottom, SKIN)
    draw_rect(img, cx-4, head_bottom-1, cx+4, head_bottom, SKIN_SHADOW)
    # Hair
    draw_rect(img, cx-5, head_top-2, cx+5, head_top, HAIR)
    draw_rect(img, cx-6, head_top-1, cx-4, head_top+1, HAIR)
    draw_rect(img, cx+4, head_top-1, cx+6, head_top+1, HAIR)
    draw_rect(img, cx-3, head_top-3, cx+3, head_top-2, HAIR)
    draw_rect(img, cx-4, head_top-2, cx-2, head_top-1, HAIR_LIGHT)
    draw_rect(img, cx+2, head_top-2, cx+4, head_top-1, HAIR_LIGHT)
    # Headband
    draw_rect(img, cx-5, head_top+1, cx+5, head_top+2, BAND)
    draw_rect(img, cx-6, head_top+2, cx-5, head_top+4, BAND)
    
    # Arms swinging
    if facing_right:
        draw_rect(img, cx+5, torso_top+arm_swing+y_off, cx+8, torso_top+8+y_off, SKIN)
        draw_rect(img, cx-8, torso_top-arm_swing+y_off, cx-5, torso_top+8+y_off, SKIN)
    else:
        draw_rect(img, cx-8, torso_top+arm_swing+y_off, cx-5, torso_top+8+y_off, SKIN)
        draw_rect(img, cx+5, torso_top-arm_swing+y_off, cx+8, torso_top+8+y_off, SKIN)
    
    # Eyes
    draw_eyes(img, cx, head_top+5+y_off, facing_right)
    draw_mouth(img, cx, head_top+7+y_off)
    
    # Axe
    if facing_right:
        draw_axe(img, cx+7, torso_top+8+arm_swing+y_off, math.radians(-50 + math.sin(phase*2*math.pi)*10), True, 14)
    else:
        draw_axe(img, cx-7, torso_top+8+arm_swing+y_off, math.radians(-50 + math.sin(phase*2*math.pi)*10), False, 14)

def draw_tarzan_attack(img, frame, facing_right=True):
    """Attack animation - 6 frame overhead axe swing"""
    cx = CANVAS_W // 2
    ground = CANVAS_H - 4
    torso_top = ground - 26
    
    phase = frame / 6.0
    
    # Forward lunge
    lunge = int(math.sin(phase * math.pi) * 4)
    if facing_right:
        cx += lunge
    else:
        cx -= lunge
    
    # Axe swing arc: starts behind (140deg), swings overhead to front (-40deg)
    swing_angle = math.radians(140 - phase * 180)
    
    # Body twist
    twist = int(math.sin(phase * math.pi) * 2)
    
    # Wide stance legs
    draw_rect(img, cx-4, ground-14, cx-2, ground, PANTS)
    draw_rect(img, cx+2, ground-14, cx+4, ground, PANTS_DARK)
    draw_rect(img, cx-5, ground, cx-2, ground+2, SKIN_SHADOW)
    draw_rect(img, cx+2, ground, cx+5, ground+2, SKIN_SHADOW)
    
    # Torso (twisted)
    draw_rect(img, cx-5, torso_top, cx+5, ground-14, SKIN)
    draw_rect(img, cx-5, torso_top+4, cx-1, torso_top+8, SKIN_HIGHLIGHT)
    draw_rect(img, cx+1, torso_top+4, cx+5, torso_top+8, SKIN_HIGHLIGHT)
    draw_rect(img, cx-3, torso_top+8, cx-1, torso_top+11, SKIN_SHADOW)
    draw_rect(img, cx+1, torso_top+8, cx+3, torso_top+11, SKIN_SHADOW)
    draw_rect(img, cx-7, torso_top, cx-5, torso_top+4, SKIN_SHADOW)
    draw_rect(img, cx+5, torso_top, cx+7, torso_top+4, SKIN_SHADOW)
    
    # Neck
    draw_rect(img, cx-2, torso_top-2, cx+2, torso_top, SKIN_SHADOW)
    
    # Head
    head_bottom = torso_top - 2
    head_top = torso_top - 8
    draw_rect(img, cx-4, head_top, cx+4, head_bottom, SKIN)
    draw_rect(img, cx-4, head_bottom-1, cx+4, head_bottom, SKIN_SHADOW)
    draw_rect(img, cx-5, head_top-2, cx+5, head_top, HAIR)
    draw_rect(img, cx-6, head_top-1, cx-4, head_top+1, HAIR)
    draw_rect(img, cx+4, head_top-1, cx+6, head_top+1, HAIR)
    draw_rect(img, cx-5, head_top+1, cx+5, head_top+2, BAND)
    draw_rect(img, cx-6, head_top+2, cx-5, head_top+4, BAND)
    
    # Angry eyes
    draw_eyes(img, cx, head_top+5, facing_right, angry=True)
    # Battle cry mouth
    draw_mouth(img, cx, head_top+7, open_w=True)
    
    # Arms raised for swing
    if facing_right:
        draw_rect(img, cx+5, torso_top-2, cx+8, torso_top+6, SKIN)
        draw_rect(img, cx-8, torso_top-2, cx-5, torso_top+6, SKIN)
    else:
        draw_rect(img, cx-8, torso_top-2, cx-5, torso_top+6, SKIN)
        draw_rect(img, cx+5, torso_top-2, cx+8, torso_top+6, SKIN)
    
    # Axe in swing
    if facing_right:
        draw_axe(img, cx+6, torso_top+2, swing_angle, True, 16)
    else:
        draw_axe(img, cx-6, torso_top+2, swing_angle, False, 16)

def draw_tarzan_hurt(img, frame, facing_right=True):
    """Hurt animation - recoiling from damage"""
    cx = CANVAS_W // 2
    ground = CANVAS_H - 4
    torso_top = ground - 26
    
    # Recoil
    recoil = frame * 2
    if facing_right:
        cx -= recoil
    else:
        cx += recoil
    
    # Staggering legs
    stagger = frame
    draw_rect(img, cx-3, ground-14+stagger, cx-1, ground, PANTS)
    draw_rect(img, cx+1, ground-14-stagger, cx+3, ground, PANTS_DARK)
    draw_rect(img, cx-4, ground, cx-1, ground+2, SKIN_SHADOW)
    draw_rect(img, cx+1, ground, cx+4, ground+2, SKIN_SHADOW)
    
    # Torso
    draw_rect(img, cx-5, torso_top, cx+5, ground-14, SKIN)
    draw_rect(img, cx-5, torso_top+4, cx-1, torso_top+8, SKIN_HIGHLIGHT)
    draw_rect(img, cx+1, torso_top+4, cx+5, torso_top+8, SKIN_HIGHLIGHT)
    
    # Arms flinching
    if facing_right:
        draw_rect(img, cx+5, torso_top, cx+7, torso_top+6, SKIN)
        draw_rect(img, cx-8, torso_top, cx-5, torso_top+6, SKIN)
    else:
        draw_rect(img, cx-7, torso_top, cx-5, torso_top+6, SKIN)
        draw_rect(img, cx+5, torso_top, cx+8, torso_top+6, SKIN)
    
    # Neck
    draw_rect(img, cx-2, torso_top-2, cx+2, torso_top, SKIN_SHADOW)
    
    # Head (tilted back)
    head_bottom = torso_top - 2
    head_top = torso_top - 8
    draw_rect(img, cx-4, head_top, cx+4, head_bottom, SKIN)
    draw_rect(img, cx-5, head_top-2, cx+5, head_top, HAIR)
    draw_rect(img, cx-6, head_top-1, cx-4, head_top+1, HAIR)
    draw_rect(img, cx+4, head_top-1, cx+6, head_top+1, HAIR)
    draw_rect(img, cx-5, head_top+1, cx+5, head_top+2, BAND)
    
    # Pained eyes (X eyes)
    set_pixel(img, cx-2, head_top+5, (255,255,255))
    set_pixel(img, cx, head_top+5, (255,255,255))
    set_pixel(img, cx+2, head_top+5, (255,255,255))
    # Pain mouth
    draw_mouth(img, cx, head_top+7, open_w=True)
    
    # Dropping axe
    if facing_right:
        draw_axe(img, cx+6, torso_top+6, math.radians(-80), True, 12)
    else:
        draw_axe(img, cx-6, torso_top+6, math.radians(-80), False, 12)

def draw_tarzan_death(img, frame, facing_right=True):
    """Death animation - 4 frames: stagger → kneel → fall → still"""
    cx = CANVAS_W // 2
    ground = CANVAS_H - 4
    torso_top = ground - 26
    
    if frame == 0:
        # Stagger back hard
        if facing_right:
            cx -= 4
        else:
            cx += 4
        draw_rect(img, cx-3, ground-14, cx-1, ground, PANTS)
        draw_rect(img, cx+1, ground-14, cx+3, ground, PANTS_DARK)
        draw_rect(img, cx-4, ground, cx-1, ground+2, SKIN_SHADOW)
        draw_rect(img, cx+1, ground, cx+4, ground+2, SKIN_SHADOW)
        draw_rect(img, cx-5, torso_top, cx+5, ground-14, SKIN)
        draw_rect(img, cx-5, torso_top+4, cx-1, torso_top+8, SKIN_HIGHLIGHT)
        draw_rect(img, cx+1, torso_top+4, cx+5, torso_top+8, SKIN_HIGHLIGHT)
        draw_rect(img, cx-2, torso_top-2, cx+2, torso_top, SKIN_SHADOW)
        head_bottom = torso_top - 2
        head_top = torso_top - 8
        draw_rect(img, cx-4, head_top, cx+4, head_bottom, SKIN)
        draw_rect(img, cx-5, head_top-2, cx+5, head_top, HAIR)
        draw_rect(img, cx-6, head_top-1, cx-4, head_top+1, HAIR)
        draw_rect(img, cx+4, head_top-1, cx+6, head_top+1, HAIR)
        set_pixel(img, cx-2, head_top+5, (255,255,255))
        set_pixel(img, cx+2, head_top+5, (255,255,255))
        draw_mouth(img, cx, head_top+7, open_w=True)
        if facing_right:
            draw_rect(img, cx+5, torso_top, cx+7, torso_top+6, SKIN)
            draw_rect(img, cx-8, torso_top, cx-5, torso_top+6, SKIN)
        else:
            draw_rect(img, cx-7, torso_top, cx-5, torso_top+6, SKIN)
            draw_rect(img, cx+5, torso_top, cx+8, torso_top+6, SKIN)
        
    elif frame == 1:
        # Falling to knees
        draw_rect(img, cx-4, ground-8, cx-2, ground, PANTS)
        draw_rect(img, cx+2, ground-8, cx+4, ground, PANTS_DARK)
        draw_rect(img, cx-5, ground-8, cx+5, ground-4, SKIN)
        draw_rect(img, cx-5, ground-16, cx+5, ground-8, SKIN)
        draw_rect(img, cx-5, ground-16+4, cx-1, ground-16+8, SKIN_HIGHLIGHT)
        draw_rect(img, cx+1, ground-16+4, cx+5, ground-16+8, SKIN_HIGHLIGHT)
        # Head drooping
        draw_rect(img, cx-4, ground-22, cx+4, ground-16, SKIN)
        draw_rect(img, cx-5, ground-24, cx+5, ground-22, HAIR)
        draw_rect(img, cx-6, ground-23, cx-4, ground-21, HAIR)
        draw_rect(img, cx+4, ground-23, cx+6, ground-21, HAIR)
        draw_rect(img, cx-5, ground-22, cx+5, ground-21, BAND)
        # Closed eyes
        draw_rect(img, cx-3, ground-19, cx-1, ground-18, (255,255,255))
        draw_rect(img, cx+1, ground-19, cx+3, ground-18, (255,255,255))
        # Arms limp
        draw_rect(img, cx-8, ground-14, cx-5, ground-8, SKIN)
        draw_rect(img, cx+5, ground-14, cx+8, ground-8, SKIN)
        # Axe dropped on ground
        draw_line(img, cx+8, ground-2, cx+12, ground-12, AXE_HANDLE)
        draw_rect(img, cx+10, ground-14, cx+14, ground-10, AXE_BLADE)
        
    elif frame == 2:
        # On ground (fallen)
        draw_rect(img, cx-6, ground-4, cx+6, ground, SKIN)
        draw_rect(img, cx-6, ground-8, cx+6, ground-4, PANTS)
        draw_rect(img, cx-4, ground-12, cx+4, ground-8, SKIN)
        draw_rect(img, cx-5, ground-14, cx+5, ground-12, HAIR)
        draw_rect(img, cx-5, ground-13, cx+5, ground-12, BAND)
        # X eyes (dead)
        set_pixel(img, cx-2, ground-11, (255,255,255))
        set_pixel(img, cx+2, ground-11, (255,255,255))
        # Axe on ground beside body
        draw_line(img, cx+6, ground-2, cx+10, ground-10, AXE_HANDLE)
        draw_rect(img, cx+8, ground-12, cx+12, ground-8, AXE_BLADE)
        
    else:
        # Same as frame 2 (final death pose)
        draw_rect(img, cx-6, ground-4, cx+6, ground, SKIN)
        draw_rect(img, cx-6, ground-8, cx+6, ground-4, PANTS)
        draw_rect(img, cx-4, ground-12, cx+4, ground-8, SKIN)
        draw_rect(img, cx-5, ground-14, cx+5, ground-12, HAIR)
        draw_rect(img, cx-5, ground-13, cx+5, ground-12, BAND)
        set_pixel(img, cx-2, ground-11, (255,255,255))
        set_pixel(img, cx+2, ground-11, (255,255,255))
        draw_line(img, cx+6, ground-2, cx+10, ground-10, AXE_HANDLE)
        draw_rect(img, cx+8, ground-12, cx+12, ground-8, AXE_BLADE)

def create_sprite_sheet(name, draw_func, num_frames, output_dir, facing_right=True):
    sheet = Image.new("RGBA", (CANVAS_W * num_frames, CANVAS_H), (0, 0, 0, 0))
    for f in range(num_frames):
        frame = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
        draw_func(frame, f, facing_right)
        sheet.paste(frame, (f * CANVAS_W, 0))
    path = os.path.join(output_dir, f"{name}.png")
    sheet.save(path)
    print(f"Created: {path} ({sheet.size[0]}x{sheet.size[1]}, {num_frames} frames)")
    return path

output_dir = r"D:\openclaw\giac-mo-co-tich\assets\player\tarzan"

print("=== Generating Tarzan Sprite Sheets v2 ===\n")

create_sprite_sheet("tarzan_idle", draw_tarzan_idle, 6, output_dir)
create_sprite_sheet("tarzan_walk", draw_tarzan_walk, 8, output_dir)
create_sprite_sheet("tarzan_attack", draw_tarzan_attack, 6, output_dir)
create_sprite_sheet("tarzan_hurt", draw_tarzan_hurt, 3, output_dir)
create_sprite_sheet("tarzan_death", draw_tarzan_death, 4, output_dir)

print("\n=== All Tarzan sprite sheets generated! ===")
