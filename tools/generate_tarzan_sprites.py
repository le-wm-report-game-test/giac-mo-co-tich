
import struct, os, math, random
from PIL import Image

# ============================================================
# TARZAN SPRITE GENERATOR
# Generates pixel art sprite sheets for Tarzan jungle warrior
# ============================================================

CANVAS_W = 64  # width per frame
CANVAS_H = 64  # height per frame

# Color palette - Tarzan jungle warrior
SKIN = (210, 160, 110)       # Tanned skin
SKIN_SHADOW = (170, 125, 80)
SKIN_DARK = (140, 100, 60)
HAIR = (60, 35, 20)          # Dark brown hair
HAIR_LIGHT = (90, 60, 35)
PANTS = (100, 60, 30)        # Brown torn pants
PANTS_DARK = (70, 40, 20)
PANTS_LIGHT = (130, 85, 50)
AXE_HANDLE = (120, 80, 40)   # Wood handle
AXE_BLADE = (160, 160, 160)  # Stone axe blade
AXE_BLADE_DARK = (120, 120, 120)
EYE = (40, 30, 20)
MOUTH = (80, 40, 30)
BG = (0, 0, 0, 0)            # Transparent

def set_pixel(img, x, y, color):
    if 0 <= x < CANVAS_W and 0 <= y < CANVAS_H:
        img.putpixel((x, y), color)

def draw_rect(img, x1, y1, x2, y2, color):
    for y in range(y1, y2+1):
        for x in range(x1, x2+1):
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

def draw_tarzan_standing(img, frame=0, facing_right=True):
    """Draw Tarzan in standing/idle pose"""
    cx = CANVAS_W // 2
    ground = CANVAS_H - 4
    
    # Body sway for idle animation
    sway = int(math.sin(frame * 0.5) * 1) if frame > 0 else 0
    
    # Legs
    draw_rect(img, cx-3+sway, ground-14, cx-1+sway, ground, PANTS)
    draw_rect(img, cx+1+sway, ground-14, cx+3+sway, ground, PANTS_DARK)
    # Feet
    draw_rect(img, cx-4+sway, ground, cx-1+sway, ground+2, SKIN_SHADOW)
    draw_rect(img, cx+1+sway, ground, cx+4+sway, ground+2, SKIN_SHADOW)
    
    # Torso
    draw_rect(img, cx-5+sway, ground-26, cx+5+sway, ground-14, SKIN)
    # Chest shadow
    draw_rect(img, cx-4+sway, ground-22, cx+4+sway, ground-18, SKIN_SHADOW)
    # Abs
    draw_rect(img, cx-3+sway, ground-18, cx-1+sway, ground-15, SKIN_SHADOW)
    draw_rect(img, cx+1+sway, ground-18, cx+3+sway, ground-15, SKIN_SHADOW)
    
    # Arms
    if facing_right:
        # Right arm (holding axe) - down
        draw_rect(img, cx+5+sway, ground-24, cx+8+sway, ground-16, SKIN)
        draw_rect(img, cx+7+sway, ground-24, cx+9+sway, ground-20, SKIN_SHADOW)
        # Left arm - relaxed
        draw_rect(img, cx-8+sway, ground-24, cx-5+sway, ground-16, SKIN)
        draw_rect(img, cx-9+sway, ground-24, cx-7+sway, ground-20, SKIN_SHADOW)
    else:
        draw_rect(img, cx-8+sway, ground-24, cx-5+sway, ground-16, SKIN)
        draw_rect(img, cx+5+sway, ground-24, cx+8+sway, ground-16, SKIN)
    
    # Head
    draw_rect(img, cx-4+sway, ground-32, cx+4+sway, ground-26, SKIN)
    # Hair (wild Tarzan hair)
    draw_rect(img, cx-5+sway, ground-34, cx+5+sway, ground-32, HAIR)
    draw_rect(img, cx-6+sway, ground-33, cx-4+sway, ground-31, HAIR)
    draw_rect(img, cx+4+sway, ground-33, cx+6+sway, ground-31, HAIR)
    # Eyes
    if facing_right:
        set_pixel(img, cx+1+sway, ground-29, EYE)
        set_pixel(img, cx+3+sway, ground-29, EYE)
    else:
        set_pixel(img, cx-3+sway, ground-29, EYE)
        set_pixel(img, cx-1+sway, ground-29, EYE)
    # Mouth
    set_pixel(img, cx+sway, ground-27, MOUTH)
    set_pixel(img, cx+1+sway, ground-27, MOUTH)
    
    # Stone Axe (held in right hand)
    if facing_right:
        # Handle
        draw_line(img, cx+7+sway, ground-16, cx+12+sway, ground-30, AXE_HANDLE)
        # Blade
        draw_rect(img, cx+10+sway, ground-32, cx+14+sway, ground-28, AXE_BLADE)
        draw_rect(img, cx+11+sway, ground-33, cx+13+sway, ground-32, AXE_BLADE_DARK)
        draw_rect(img, cx+11+sway, ground-28, cx+13+sway, ground-27, AXE_BLADE_DARK)
    else:
        draw_line(img, cx-7+sway, ground-16, cx-12+sway, ground-30, AXE_HANDLE)
        draw_rect(img, cx-14+sway, ground-32, cx-10+sway, ground-28, AXE_BLADE)
        draw_rect(img, cx-13+sway, ground-33, cx-11+sway, ground-32, AXE_BLADE_DARK)
        draw_rect(img, cx-13+sway, ground-28, cx-11+sway, ground-27, AXE_BLADE_DARK)

def draw_tarzan_walk(img, frame, facing_right=True):
    """Draw Tarzan walking - 8 frame cycle"""
    cx = CANVAS_W // 2
    ground = CANVAS_H - 4
    
    phase = (frame % 8) / 8.0
    leg_offset = int(math.sin(phase * 2 * math.pi) * 4)
    arm_offset = int(math.sin(phase * 2 * math.pi + math.pi) * 3)
    body_bounce = int(abs(math.sin(phase * 2 * math.pi)) * 2)
    
    y_off = -body_bounce
    
    # Legs (alternating)
    draw_rect(img, cx-3, ground-14+leg_offset+y_off, cx-1, ground+y_off, PANTS)
    draw_rect(img, cx+1, ground-14-leg_offset+y_off, cx+3, ground+y_off, PANTS_DARK)
    # Feet
    draw_rect(img, cx-4+leg_offset, ground+y_off, cx-1+leg_offset, ground+2+y_off, SKIN_SHADOW)
    draw_rect(img, cx+1-leg_offset, ground+y_off, cx+4-leg_offset, ground+2+y_off, SKIN_SHADOW)
    
    # Torso
    draw_rect(img, cx-5, ground-26+y_off, cx+5, ground-14+y_off, SKIN)
    draw_rect(img, cx-4, ground-22+y_off, cx+4, ground-18+y_off, SKIN_SHADOW)
    
    # Arms (swinging)
    if facing_right:
        draw_rect(img, cx+5, ground-24+arm_offset+y_off, cx+8, ground-16+y_off, SKIN)
        draw_rect(img, cx-8, ground-24-arm_offset+y_off, cx-5, ground-16+y_off, SKIN)
    else:
        draw_rect(img, cx-8, ground-24+arm_offset+y_off, cx-5, ground-16+y_off, SKIN)
        draw_rect(img, cx+5, ground-24-arm_offset+y_off, cx+8, ground-16+y_off, SKIN)
    
    # Head
    draw_rect(img, cx-4, ground-32+y_off, cx+4, ground-26+y_off, SKIN)
    draw_rect(img, cx-5, ground-34+y_off, cx+5, ground-32+y_off, HAIR)
    draw_rect(img, cx-6, ground-33+y_off, cx-4, ground-31+y_off, HAIR)
    draw_rect(img, cx+4, ground-33+y_off, cx+6, ground-31+y_off, HAIR)
    # Eyes
    if facing_right:
        set_pixel(img, cx+1, ground-29+y_off, EYE)
        set_pixel(img, cx+3, ground-29+y_off, EYE)
    else:
        set_pixel(img, cx-3, ground-29+y_off, EYE)
        set_pixel(img, cx-1, ground-29+y_off, EYE)
    
    # Axe
    if facing_right:
        draw_line(img, cx+7, ground-16+arm_offset+y_off, cx+12, ground-30+y_off, AXE_HANDLE)
        draw_rect(img, cx+10, ground-32+y_off, cx+14, ground-28+y_off, AXE_BLADE)
    else:
        draw_line(img, cx-7, ground-16+arm_offset+y_off, cx-12, ground-30+y_off, AXE_HANDLE)
        draw_rect(img, cx-14, ground-32+y_off, cx-10, ground-28+y_off, AXE_BLADE)

def draw_tarzan_attack(img, frame, facing_right=True):
    """Draw Tarzan attacking with axe - 6 frame cycle"""
    cx = CANVAS_W // 2
    ground = CANVAS_H - 4
    
    phase = frame / 6.0
    # Axe swing arc
    axe_angle = phase * math.pi * 1.2  # Swing from behind to front
    axe_x = int(math.cos(axe_angle - math.pi/2) * 10)
    axe_y = int(math.sin(axe_angle - math.pi/2) * 10)
    
    # Forward lunge
    lunge = int(math.sin(phase * math.pi) * 3)
    
    if facing_right:
        cx += lunge
    else:
        cx -= lunge
    
    # Legs (wide stance for attack)
    draw_rect(img, cx-4, ground-14, cx-2, ground, PANTS)
    draw_rect(img, cx+2, ground-14, cx+4, ground, PANTS_DARK)
    draw_rect(img, cx-5, ground, cx-2, ground+2, SKIN_SHADOW)
    draw_rect(img, cx+2, ground, cx+5, ground+2, SKIN_SHADOW)
    
    # Torso (twisted)
    draw_rect(img, cx-5, ground-26, cx+5, ground-14, SKIN)
    # Chest definition
    draw_rect(img, cx-4, ground-22, cx-1, ground-18, SKIN_SHADOW)
    draw_rect(img, cx+1, ground-22, cx+4, ground-18, SKIN)
    
    # Arms (both raised for swing)
    if facing_right:
        draw_rect(img, cx+5, ground-26, cx+8, ground-20, SKIN)
        draw_rect(img, cx-8, ground-26, cx-5, ground-20, SKIN)
    else:
        draw_rect(img, cx-8, ground-26, cx-5, ground-20, SKIN)
        draw_rect(img, cx+5, ground-26, cx+8, ground-20, SKIN)
    
    # Head
    draw_rect(img, cx-4, ground-32, cx+4, ground-26, SKIN)
    draw_rect(img, cx-5, ground-34, cx+5, ground-32, HAIR)
    draw_rect(img, cx-6, ground-33, cx-4, ground-31, HAIR)
    draw_rect(img, cx+4, ground-33, cx+6, ground-31, HAIR)
    # Angry eyes
    set_pixel(img, cx-2, ground-29, EYE)
    set_pixel(img, cx+2, ground-29, EYE)
    # Open mouth (battle cry)
    draw_rect(img, cx-1, ground-27, cx+1, ground-26, MOUTH)
    
    # Axe in swing position
    if facing_right:
        ax = cx + 6 + axe_x
        ay = ground - 22 + axe_y
        draw_line(img, cx+7, ground-20, ax, ay, AXE_HANDLE)
        draw_rect(img, ax-2, ay-3, ax+2, ay+1, AXE_BLADE)
    else:
        ax = cx - 6 - axe_x
        ay = ground - 22 + axe_y
        draw_line(img, cx-7, ground-20, ax, ay, AXE_HANDLE)
        draw_rect(img, ax-2, ay-3, ax+2, ay+1, AXE_BLADE)

def draw_tarzan_hurt(img, frame, facing_right=True):
    """Draw Tarzan taking damage - 3 frame cycle"""
    cx = CANVAS_W // 2
    ground = CANVAS_H - 4
    
    # Recoil
    recoil = frame * 2
    if facing_right:
        cx -= recoil
    else:
        cx += recoil
    
    # Legs (staggering)
    draw_rect(img, cx-3, ground-14, cx-1, ground, PANTS)
    draw_rect(img, cx+1, ground-14, cx+3, ground, PANTS_DARK)
    draw_rect(img, cx-4, ground, cx-1, ground+2, SKIN_SHADOW)
    draw_rect(img, cx+1, ground, cx+4, ground+2, SKIN_SHADOW)
    
    # Torso (leaning back)
    draw_rect(img, cx-5, ground-26, cx+5, ground-14, SKIN)
    
    # Arms (flinching)
    if facing_right:
        draw_rect(img, cx+5, ground-24, cx+7, ground-18, SKIN)
        draw_rect(img, cx-8, ground-24, cx-5, ground-18, SKIN)
    else:
        draw_rect(img, cx-7, ground-24, cx-5, ground-18, SKIN)
        draw_rect(img, cx+5, ground-24, cx+8, ground-18, SKIN)
    
    # Head (tilted back in pain)
    draw_rect(img, cx-4, ground-32, cx+4, ground-26, SKIN)
    draw_rect(img, cx-5, ground-34, cx+5, ground-32, HAIR)
    # Pained eyes (X eyes)
    set_pixel(img, cx-2, ground-29, (255,255,255))
    set_pixel(img, cx+2, ground-29, (255,255,255))
    # Open mouth (pain)
    draw_rect(img, cx-1, ground-27, cx+1, ground-26, MOUTH)

def draw_tarzan_death(img, frame, facing_right=True):
    """Draw Tarzan dying - 4 frame cycle"""
    cx = CANVAS_W // 2
    ground = CANVAS_H - 4
    
    if frame == 0:
        # Staggering
        draw_tarzan_hurt(img, 2, facing_right)
    elif frame == 1:
        # Falling to knees
        draw_rect(img, cx-4, ground-8, cx-2, ground, PANTS)
        draw_rect(img, cx+2, ground-8, cx+4, ground, PANTS_DARK)
        draw_rect(img, cx-5, ground-8, cx+5, ground-4, SKIN)
        draw_rect(img, cx-5, ground-16, cx+5, ground-8, SKIN)
        draw_rect(img, cx-4, ground-22, cx+4, ground-18, SKIN)
        # Head drooping
        draw_rect(img, cx-4, ground-22, cx+4, ground-16, SKIN)
        draw_rect(img, cx-5, ground-24, cx+5, ground-22, HAIR)
        # Closed eyes
        draw_rect(img, cx-3, ground-19, cx-1, ground-18, (255,255,255))
        draw_rect(img, cx+1, ground-19, cx+3, ground-18, (255,255,255))
        # Axe dropped
        draw_line(img, cx+8, ground-2, cx+12, ground-12, AXE_HANDLE)
    elif frame == 2:
        # On ground
        draw_rect(img, cx-6, ground-4, cx+6, ground, SKIN)
        draw_rect(img, cx-6, ground-8, cx+6, ground-4, PANTS)
        draw_rect(img, cx-4, ground-12, cx+4, ground-8, SKIN)
        draw_rect(img, cx-5, ground-14, cx+5, ground-12, HAIR)
        # X eyes
        set_pixel(img, cx-2, ground-11, (255,255,255))
        set_pixel(img, cx+2, ground-11, (255,255,255))
        # Axe on ground
        draw_line(img, cx+6, ground-2, cx+10, ground-10, AXE_HANDLE)
    else:
        # Same as frame 2 but fading (handled by Godot alpha)
        draw_rect(img, cx-6, ground-4, cx+6, ground, SKIN)
        draw_rect(img, cx-6, ground-8, cx+6, ground-4, PANTS)
        draw_rect(img, cx-4, ground-12, cx+4, ground-8, SKIN)
        draw_rect(img, cx-5, ground-14, cx+5, ground-12, HAIR)
        set_pixel(img, cx-2, ground-11, (255,255,255))
        set_pixel(img, cx+2, ground-11, (255,255,255))

# ============================================================
# Generate Sprite Sheets
# ============================================================

def create_sprite_sheet(name, draw_func, num_frames, output_dir, facing_right=True):
    """Create a horizontal sprite sheet"""
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

print("=== Generating Tarzan Sprite Sheets ===\n")

# Idle: 6 frames
create_sprite_sheet("tarzan_idle", lambda img, f, _: draw_tarzan_standing(img, f, True), 6, output_dir)

# Walk: 8 frames
create_sprite_sheet("tarzan_walk", lambda img, f, _: draw_tarzan_walk(img, f, True), 8, output_dir)

# Attack: 6 frames
create_sprite_sheet("tarzan_attack", lambda img, f, _: draw_tarzan_attack(img, f, True), 6, output_dir)

# Hurt: 3 frames
create_sprite_sheet("tarzan_hurt", lambda img, f, _: draw_tarzan_hurt(img, f, True), 3, output_dir)

# Death: 4 frames
create_sprite_sheet("tarzan_death", lambda img, f, _: draw_tarzan_death(img, f, True), 4, output_dir)

print("\n=== All Tarzan sprite sheets generated! ===")
