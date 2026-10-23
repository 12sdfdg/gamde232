#!/usr/bin/env python3
"""Generates src/StarterGui/HatchUI/{HUD,Popups}.model.json for Rojo.

The UI mirrors the reference video: left Shop/Index buttons, currency stack,
right 2x4 menu, egg hotbar, potions, top-right player strip, and the popups
(Daily Rewards, Index, Spin Wheel, Playtime Rewards, Daily Quests, Settings,
plus placeholder windows for Shop/Pass/Eggs/Pets). Everything is plain Roblox
instances so it can be edited in the Explorer; UIController.client.lua animates.

Reference resolution is 1280x720; the controller scales the root UIScale.
Icons are emoji placeholders - swap for ImageLabels.
"""
import json
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "src", "StarterGui", "HatchUI")

# ---------------------------------------------------------------- helpers
def U2(sx, ox, sy, oy):
    return {"UDim2": [[sx, ox], [sy, oy]]}

def U(s, o):
    return {"UDim": [s, o]}

def rgb(r, g, b):
    return [r / 255, g / 255, b / 255]

def grad(c1, c2, rotation=90):
    return inst("UIGradient", "Gradient", {
        "Rotation": rotation,
        "Color": {"ColorSequence": {"keypoints": [
            {"time": 0, "color": c1}, {"time": 1, "color": c2}]}},
    })

def inst(cls, name, props=None, children=None):
    d = {"name": name, "className": cls, "properties": props or {}}
    if children:
        d["children"] = [c for c in children if c]
    return d

def corner(px=12):
    return inst("UICorner", "Corner", {"CornerRadius": U(0, px)})

def stroke(px=3, color=rgb(25, 25, 40), transparency=0):
    return inst("UIStroke", "Stroke", {"Thickness": px, "Color": color,
                                       "Transparency": transparency,
                                       "ApplyStrokeMode": "Border"})

def scale(name="Scale", s=1):
    return inst("UIScale", name, {"Scale": s})

def frame(name, size, pos, color=rgb(45, 50, 80), anchor=(0, 0), children=None,
          transparency=0, zindex=1, visible=True, extra=None):
    p = {"Size": size, "Position": pos, "AnchorPoint": list(anchor),
         "BackgroundColor3": color, "BackgroundTransparency": transparency,
         "BorderSizePixel": 0, "ZIndex": zindex, "Visible": visible}
    if extra:
        p.update(extra)
    return inst("Frame", name, p, children)

def label(name, text, size, pos, color=rgb(255, 255, 255), font="FredokaOne",
          stroke_t=0, align="Center", anchor=(0, 0), zindex=2, scaled=True,
          text_size=18, extra=None, children=None):
    p = {"Size": size, "Position": pos, "AnchorPoint": list(anchor),
         "BackgroundTransparency": 1, "Text": text, "TextColor3": color,
         "Font": font, "TextScaled": scaled, "TextSize": text_size,
         "TextStrokeTransparency": stroke_t, "TextStrokeColor3": rgb(20, 20, 30),
         "TextXAlignment": align, "ZIndex": zindex, "BorderSizePixel": 0}
    if extra:
        p.update(extra)
    return inst("TextLabel", name, p, children)

def button(name, size, pos, c1, c2, text="", icon=None, anchor=(0, 0),
           children=None, radius=12, zindex=2, font="FredokaOne",
           text_color=rgb(255, 255, 255), caption=None, extra=None):
    kids = [corner(radius), stroke(3), grad(c1, c2), scale("Hover")]
    if icon:
        kids.append(label("Icon", icon, U2(0, 34, 0, 34), U2(0, 8, 0.5, 0),
                          anchor=(0, 0.5), stroke_t=1, zindex=zindex + 1))
    if text:
        kids.append(label("Label", text, U2(1, -(46 if icon else 12), 1, -10),
                          U2(0, 40 if icon else 6, 0.5, 0), anchor=(0, 0.5),
                          color=text_color, align="Left" if icon else "Center",
                          zindex=zindex + 1, font=font))
    if caption:
        kids.append(label("Caption", caption, U2(1, -4, 0, 16), U2(0.5, 0, 1, -4),
                          anchor=(0.5, 1), zindex=zindex + 1, text_size=12))
    if children:
        kids += children
    p = {"Size": size, "Position": pos, "AnchorPoint": list(anchor),
         "BackgroundColor3": rgb(255, 255, 255), "BorderSizePixel": 0,
         "Text": "", "AutoButtonColor": False, "ZIndex": zindex}
    if extra:
        p.update(extra)
    return inst("TextButton", name, p, kids)

# colour palette (from the video)
GREEN = (rgb(96, 220, 96), rgb(40, 160, 60))
BLUE = (rgb(90, 170, 255), rgb(40, 110, 230))
PINK = (rgb(255, 110, 230), rgb(150, 60, 230))
YELLOW = (rgb(255, 215, 70), rgb(240, 160, 30))
ORANGE = (rgb(255, 165, 60), rgb(230, 110, 30))
RED = (rgb(255, 100, 80), rgb(220, 50, 50))
PURPLE = (rgb(190, 90, 255), rgb(120, 40, 200))
GRAY = (rgb(120, 140, 175), rgb(70, 85, 120))
NAVY = rgb(44, 50, 82)
NAVY_DARK = rgb(32, 36, 60)
BANNER_YELLOW = rgb(255, 205, 50)

# ---------------------------------------------------------------- HUD
def hud():
    left = frame("LeftButtons", U2(0, 120, 0, 110), U2(0, 8, 0.33, 0), transparency=1, children=[
        button("Shop", U2(0, 112, 0, 48), U2(0, 0, 0, 0), *GREEN, text="Shop", icon="🛒"),
        button("Index", U2(0, 112, 0, 48), U2(0, 0, 0, 56), *BLUE, text="Index", icon="📘"),
    ])

    def currency(name, icon, value, color, y):
        return frame(name, U2(0, 160, 0, 34), U2(0, 8, 1, y), transparency=1, anchor=(0, 1), children=[
            label("Icon", icon, U2(0, 30, 0, 30), U2(0, 0, 0.5, 0), anchor=(0, 0.5), stroke_t=1),
            label("Value", value, U2(0, 120, 1, 0), U2(0, 36, 0, 0), color=color, align="Left"),
        ])

    currencies = frame("Currencies", U2(0, 200, 0, 150), U2(0, 0, 1, 0), transparency=1, anchor=(0, 1), children=[
        currency("Gems", "💎", "0", rgb(120, 200, 255), -118),
        currency("Fish", "🐟", "10", rgb(130, 230, 255), -80),
        currency("Cash", "💵", "$62K", rgb(110, 240, 110), -42),
        label("FriendBoost", "Friend Boost: +0% 👤", U2(0, 180, 0, 18), U2(0, 10, 1, -14),
              anchor=(0, 1), color=rgb(220, 220, 240), font="GothamBold", align="Left"),
    ])

    menu_defs = [
        ("Daily", "📅", BLUE, "DAILY"), ("Spin", "🎡", PINK, "SPIN"),
        ("Pass", "🎫", YELLOW, "PASS"), ("Eggs", "🥚", ORANGE, "EGGS"),
        ("Playtime", "⏰", RED, "PLAYTIME"), ("Pets", "🐾", ORANGE, "PETS"),
        ("Quests", "⏳", YELLOW, "QUESTS"), ("Settings", "⚙️", GRAY, "SETTINGS"),
    ]
    menu_buttons = []
    for i, (name, icon, cols, cap) in enumerate(menu_defs):
        badge = frame("Badge", U2(0, 18, 0, 18), U2(1, 4, 0, -4), rgb(230, 50, 50), anchor=(1, 0),
                      zindex=5, visible=False, children=[
                          corner(9), stroke(2),
                          label("Count", "1", U2(1, 0, 1, 0), U2(0, 0, 0, 0), zindex=6, stroke_t=1)])
        menu_buttons.append(button(name, U2(0, 58, 0, 58), U2(0, 0, 0, 0), *cols, radius=12, extra={"LayoutOrder": i}, children=[
            label("Icon", icon, U2(0, 30, 0, 30), U2(0.5, 0, 0, 6), anchor=(0.5, 0), stroke_t=1, zindex=3),
            label("Caption", cap, U2(1, -2, 0, 14), U2(0.5, 0, 1, -4), anchor=(0.5, 1), zindex=3),
            badge,
        ]))
    menu = frame("RightMenu", U2(0, 124, 0, 250), U2(1, -8, 0.3, 0), transparency=1, anchor=(1, 0), children=[
        inst("UIGridLayout", "Grid", {"CellSize": U2(0, 58, 0, 58), "CellPadding": U2(0, 8, 0, 8),
                                     "SortOrder": "LayoutOrder", "HorizontalAlignment": "Right"}),
        *menu_buttons,
    ])

    hotbar = frame("Hotbar", U2(0, 400, 0, 48), U2(0.5, 0, 1, -8), transparency=1, anchor=(0.5, 1), children=[
        inst("UIListLayout", "List", {"FillDirection": "Horizontal", "Padding": U(0, 6),
                                     "HorizontalAlignment": "Center", "VerticalAlignment": "Center",
                                     "SortOrder": "LayoutOrder"}),
        *[frame(f"Slot{i}", U2(0, 44, 0, 44), U2(0, 0, 0, 0), rgb(60, 64, 80), transparency=0.25,
                extra={"LayoutOrder": i}, children=[
                    corner(10), stroke(2, rgb(20, 20, 30), 0.3),
                    label("Egg", "🥚", U2(0, 26, 0, 26), U2(0.5, 0, 0.5, 0), anchor=(0.5, 0.5), stroke_t=1)])
          for i in range(8)],
    ])

    def potion(name, icon, timer, i):
        return frame(name, U2(0, 44, 0, 56), U2(0, 0, 0, 0), transparency=1, extra={"LayoutOrder": i}, children=[
            label("Icon", icon, U2(0, 34, 0, 34), U2(0.5, 0, 0, 0), anchor=(0.5, 0), stroke_t=1),
            label("Timer", timer, U2(1, 0, 0, 16), U2(0.5, 0, 1, 0), anchor=(0.5, 1), font="GothamBold", text_size=12),
        ])
    potions = frame("Potions", U2(0, 160, 0, 56), U2(1, -8, 1, -8), transparency=1, anchor=(1, 1), children=[
        inst("UIListLayout", "List", {"FillDirection": "Horizontal", "Padding": U(0, 4),
                                     "HorizontalAlignment": "Right", "SortOrder": "LayoutOrder"}),
        potion("Lucky", "🧪", "29:09", 0), potion("Cash", "🍯", "29:08", 1),
    ])

    topright = frame("PlayerStrip", U2(0, 230, 0, 26), U2(1, -56, 0, 8), rgb(30, 34, 60), transparency=0.35,
                     anchor=(1, 0), children=[
        corner(8),
        label("Rank", "1", U2(0, 20, 1, 0), U2(0, 6, 0, 0), font="GothamBold", stroke_t=1),
        label("Name", "Player", U2(0, 90, 1, 0), U2(0, 30, 0, 0), font="GothamBold", stroke_t=1, align="Left"),
        label("Cash", "$62K", U2(0, 60, 1, 0), U2(0, 130, 0, 0), font="GothamBold", stroke_t=1, color=rgb(120, 240, 120)),
        label("Pets", "10", U2(0, 30, 1, 0), U2(0, 192, 0, 0), font="GothamBold", stroke_t=1),
    ])
    menu_btn = button("MenuButton", U2(0, 40, 0, 40), U2(1, -8, 0, 4), rgb(255, 255, 255), rgb(230, 230, 240),
                      text="☰", radius=10, text_color=rgb(40, 40, 60), anchor=(1, 0))

    toast = frame("Toast", U2(0, 240, 0, 40), U2(0.5, 0, 1, -70), rgb(30, 34, 50), anchor=(0.5, 1),
                  visible=False, zindex=20, children=[
        corner(10), stroke(2, rgb(20, 20, 30), 0.4),
        label("Text", "✅ Obtenu : Skip All Daily Rewards !", U2(1, -16, 1, -10), U2(0.5, 0, 0.5, 0),
              anchor=(0.5, 0.5), font="GothamBold", stroke_t=1, zindex=21),
    ])

    return frame("HUD", U2(1, 0, 1, 0), U2(0, 0, 0, 0), transparency=1, children=[
        scale(), left, currencies, menu, hotbar, potions, topright, menu_btn, toast])

# ---------------------------------------------------------------- popups
def window(name, title, icon, header_cols, size=(430, 290), body=None, body_bg=NAVY):
    w, h = size
    header = frame("Header", U2(1, 0, 0, 46), U2(0, 0, 0, 0), rgb(255, 255, 255), children=[
        corner(14), grad(*header_cols),
        # square off the bottom corners of the header
        frame("Fill", U2(1, 0, 0, 14), U2(0, 0, 1, 0), header_cols[1], anchor=(0, 1), zindex=1),
        label("Title", title, U2(1, -120, 1, -10), U2(0, 70, 0.5, 0), anchor=(0, 0.5), align="Left",
              zindex=3, extra={"FontFace": None} if False else None),
    ])
    icon_badge = frame("IconBadge", U2(0, 64, 0, 64), U2(0, -8, 0, -16), rgb(255, 255, 255), zindex=4, children=[
        corner(16), stroke(3), grad(header_cols[0], header_cols[1], 45),
        label("Icon", icon, U2(0, 40, 0, 40), U2(0.5, 0, 0.5, 0), anchor=(0.5, 0.5), stroke_t=1, zindex=5),
    ])
    close = button("Close", U2(0, 40, 0, 40), U2(1, -6, 0, 4), *RED, text="X", radius=10, anchor=(1, 0), zindex=5)
    kids = [corner(14), stroke(4), scale("Pop", 1), header, icon_badge, close]
    if body:
        kids.append(frame("Body", U2(1, -20, 1, -62), U2(0.5, 0, 0, 54), body_bg, anchor=(0.5, 0), transparency=1,
                          children=body))
    return frame(name, U2(0, w, 0, h), U2(0.5, 0, 0.5, 0), NAVY, anchor=(0.5, 0.5), visible=False,
                 zindex=10, children=kids)

def banner(text, y=0, color=BANNER_YELLOW, text_color=rgb(60, 40, 10), h=34):
    return frame("Banner", U2(1, 0, 0, h), U2(0, 0, 0, y), color, children=[
        corner(8), stroke(2),
        label("Text", text, U2(1, -12, 1, -8), U2(0.5, 0, 0.5, 0), anchor=(0.5, 0.5), color=text_color, stroke_t=1),
    ])

def action_buttons(y, claim="Claim All", skip="Skip All"):
    return [
        button("ClaimAll", U2(0, 110, 0, 36), U2(1, -124, 0, y), *GREEN, text=claim, radius=10, anchor=(1, 0)),
        button("SkipAll", U2(0, 110, 0, 36), U2(1, -4, 0, y), *PURPLE, text=skip, radius=10, anchor=(1, 0)),
    ]

def reward_card(name, title, sub, cols, i, claimed=True, w=92, h=78):
    return frame(name, U2(0, w, 0, h), U2(0, 0, 0, 0), rgb(255, 255, 255), extra={"LayoutOrder": i}, children=[
        corner(10), stroke(2), grad(*cols),
        label("Title", title, U2(1, -6, 0, 16), U2(0.5, 0, 0, 2), anchor=(0.5, 0), zindex=3),
        label("Icon", "✅" if claimed else "🎁", U2(0, 32, 0, 32), U2(0.5, 0, 0.5, 2), anchor=(0.5, 0.5), stroke_t=1, zindex=3),
        label("Sub", sub, U2(1, -6, 0, 14), U2(0.5, 0, 1, -3), anchor=(0.5, 1), zindex=3, text_size=11),
    ])

def daily_popup():
    days = [("Day 1", "$500", BLUE), ("Day 2", "Speed 5m", BLUE), ("Day 3", "$1K", BLUE),
            ("Day 4", "Pumpkin Egg", GREEN), ("Day 5", "Treadmill 15m", GREEN),
            ("Day 6", "$25K", GREEN), ("Day 7", "Cursed Egg", PURPLE)]
    scroll = inst("ScrollingFrame", "Days", {
        "Size": U2(1, -40, 0, 86), "Position": U2(0.5, 0, 0, 46), "AnchorPoint": [0.5, 0],
        "BackgroundTransparency": 1, "BorderSizePixel": 0, "ScrollBarThickness": 0,
        "CanvasSize": U2(0, 7 * 98, 0, 0), "ScrollingDirection": "X", "ZIndex": 11,
    }, [
        inst("UIListLayout", "List", {"FillDirection": "Horizontal", "Padding": U(0, 6), "SortOrder": "LayoutOrder",
                                     "VerticalAlignment": "Center"}),
        *[reward_card(f"Day{i+1}", d, s, c, i) for i, (d, s, c) in enumerate(days)],
    ])
    body = [
        banner("Log In Every Day To Unlock Your Daily Reward!"),
        button("Prev", U2(0, 22, 0, 40), U2(0, -8, 0, 68), rgb(255, 255, 255), rgb(200, 200, 220), text="◀", radius=6, text_color=rgb(40, 40, 60)),
        button("Next", U2(0, 22, 0, 40), U2(1, 8, 0, 68), rgb(255, 255, 255), rgb(200, 200, 220), text="▶", radius=6, text_color=rgb(40, 40, 60), anchor=(1, 0)),
        scroll,
        label("Streak", "Must Login Every Day To\nKeep Your Streak!", U2(0, 150, 0, 36), U2(0, 6, 0, 146),
              color=rgb(255, 80, 80), text_size=12, align="Left"),
        *action_buttons(148),
    ]
    return window("DailyRewards", "DAILY REWARDS", "📅", BLUE, size=(430, 250), body=body)

def playtime_popup():
    rewards = [("5 min", "$500", GREEN), ("10 min", "Speed 5m", GREEN), ("15 min", "$1K", GREEN), ("20 min", "x2 Cash 10m", GREEN),
               ("30 min", "Fast Hatch", PURPLE), ("45 min", "$5K", PURPLE), ("1h", "Treadmill 15m", PURPLE), ("1h30", "Pumpkin Egg", PURPLE)]
    grid = frame("Grid", U2(1, 0, 0, 164), U2(0, 0, 0, 44), transparency=1, children=[
        inst("UIGridLayout", "Grid", {"CellSize": U2(0, 94, 0, 76), "CellPadding": U2(0, 6, 0, 6),
                                     "SortOrder": "LayoutOrder", "HorizontalAlignment": "Center"}),
        *[reward_card(f"R{i}", t, s, c, i, w=94, h=76) for i, (t, s, c) in enumerate(rewards)],
    ])
    body = [
        banner("Keep Playing To Unlock Free Gifts!"),
        grid,
        label("Played", "Played today: 1h 30m", U2(0, 160, 0, 18), U2(0, 6, 0, 214), font="GothamBold", align="Left", text_size=13),
        label("Next", "New gifts in 21h 33m", U2(0, 160, 0, 14), U2(0, 6, 0, 232), font="GothamBold", align="Left",
              color=rgb(200, 200, 220), text_size=11),
        *action_buttons(214),
    ]
    return window("PlaytimeRewards", "PLAYTIME REWARDS", "⏰", ORANGE, size=(430, 320), body=body)

def quests_popup():
    quests = [("Play 15 Minutes", 1.0), ("Spin The Wheel", 1.0), ("Hit Eggs 1 000 Times", 1.0)]
    rows = []
    for i, (title, prog) in enumerate(quests):
        golden = i == 2
        rows.append(frame(f"Quest{i}", U2(1, 0, 0, 60), U2(0, 0, 0, 0), rgb(255, 255, 255), extra={"LayoutOrder": i}, children=[
            corner(10), stroke(2), grad(*(YELLOW if golden else (rgb(80, 100, 150), rgb(55, 70, 110)))),
            label("Title", ("⭐ " if golden else "") + title, U2(0, 220, 0, 18), U2(0, 8, 0, 4), align="Left", zindex=12),
            label("Status", "Completed!", U2(0, 120, 0, 14), U2(0, 8, 0, 22), align="Left", zindex=12,
                  color=rgb(120, 255, 120), text_size=11),
            frame("Bar", U2(0, 240, 0, 12), U2(0, 8, 1, -8), rgb(30, 34, 50), anchor=(0, 1), zindex=12, children=[
                corner(6), frame("Fill", U2(prog, 0, 1, 0), U2(0, 0, 0, 0), rgb(90, 230, 90), zindex=13, children=[corner(6)])]),
            label("Rewards", "💵 🧪 ⏱", U2(0, 70, 0, 22), U2(0, 258, 0, 4), zindex=12, stroke_t=1),
            button("Claim", U2(0, 48, 0, 20), U2(0, 258, 0, 32), *GREEN, text="Claim!", radius=6, zindex=12),
            button("Skip", U2(0, 48, 0, 20), U2(0, 312, 0, 32), *GRAY, text="Skip!", radius=6, zindex=12),
        ]))
    body = [
        frame("List", U2(1, 0, 0, 196), U2(0, 0, 0, 0), transparency=1, children=[
            inst("UIListLayout", "List", {"Padding": U(0, 6), "SortOrder": "LayoutOrder"}), *rows]),
        label("Next", "⏳ New quests in 21h 33m", U2(0, 180, 0, 18), U2(0, 6, 0, 208), font="GothamBold", align="Left", text_size=13),
        *action_buttons(202),
    ]
    return window("DailyQuests", "DAILY QUESTS", "⏳", YELLOW, size=(410, 306), body=body)

def settings_popup():
    def row(name, title, sub, y, control):
        return frame(name, U2(1, 0, 0, 56), U2(0, 0, 0, y), rgb(60, 66, 100), children=[
            corner(10),
            label("Title", title, U2(0, 200, 0, 20), U2(0, 12, 0, 8), align="Left", zindex=12),
            label("Sub", sub, U2(0, 220, 0, 14), U2(0, 12, 0, 30), align="Left", zindex=12, color=rgb(200, 200, 220), text_size=11),
            control,
        ])
    slider = frame("Slider", U2(0, 160, 0, 22), U2(1, -12, 0.5, 0), rgb(35, 38, 60), anchor=(1, 0.5), zindex=12, children=[
        corner(11),
        frame("Fill", U2(0.4, 0, 1, 0), U2(0, 0, 0, 0), rgb(255, 200, 60), zindex=13, children=[corner(11)]),
        frame("Knob", U2(0, 22, 0, 22), U2(0.4, 0, 0.5, 0), rgb(255, 255, 255), anchor=(0.5, 0.5), zindex=14, children=[corner(11), stroke(2)]),
    ])
    toggle = frame("Toggle", U2(0, 54, 0, 26), U2(1, -12, 0.5, 0), rgb(70, 200, 80), anchor=(1, 0.5), zindex=12, children=[
        corner(13),
        frame("Knob", U2(0, 22, 0, 22), U2(1, -2, 0.5, 0), rgb(255, 255, 255), anchor=(1, 0.5), zindex=13, children=[corner(11)]),
        label("State", "ON", U2(0, 30, 1, 0), U2(0, -34, 0, 0), font="GothamBold", zindex=13, text_size=12),
    ])
    body = [
        row("Music", "Music", "Background music volume", 0, slider),
        row("Sound", "Sound effects", "Hits, steals, hatching, buttons", 64, toggle),
    ]
    return window("Settings", "SETTINGS", "⚙️", (rgb(120, 170, 255), rgb(70, 110, 220)), size=(400, 200), body=body)

def index_popup():
    cats = [("Océan", rgb(230, 200, 140)), ("Volcan", rgb(230, 90, 50)), ("Forêt", rgb(70, 170, 70))]
    cat_frames = [frame(f"Cat{i}", U2(0, 110, 0, 60), U2(0, 0, 0, 0), c, extra={"LayoutOrder": i}, children=[
        corner(10), stroke(2), label("Name", n, U2(1, 0, 0, 20), U2(0.5, 0, 0, 4), anchor=(0.5, 0), zindex=12)])
        for i, (n, c) in enumerate(cats)]
    pets = [frame(f"Pet{i}", U2(0, 70, 0, 66), U2(0, 0, 0, 0), rgb(35, 38, 60), extra={"LayoutOrder": i}, children=[
        corner(8), stroke(2, rgb(20, 20, 30), 0.5),
        label("Q", "???", U2(1, 0, 0, 14), U2(0.5, 0, 0, 2), anchor=(0.5, 0), zindex=12, text_size=11),
        label("Silhouette", "🐾", U2(0, 32, 0, 32), U2(0.5, 0, 0.5, 4), anchor=(0.5, 0.5), zindex=12, color=rgb(15, 15, 25), stroke_t=1)])
        for i in range(8)]
    detail = frame("Detail", U2(0, 150, 1, 0), U2(1, 0, 0, 0), rgb(220, 50, 60), anchor=(1, 0), children=[
        corner(12), stroke(3),
        frame("Preview", U2(1, -16, 0, 90), U2(0.5, 0, 0, 8), rgb(60, 20, 30), anchor=(0.5, 0), zindex=12, children=[
            corner(10), label("S", "🐾", U2(0, 50, 0, 50), U2(0.5, 0, 0.5, 0), anchor=(0.5, 0.5), color=rgb(15, 15, 25), stroke_t=1, zindex=13)]),
        label("Name", "???", U2(1, 0, 0, 18), U2(0.5, 0, 0, 102), anchor=(0.5, 0), zindex=12),
        label("Rarity", "MYTHIC", U2(1, 0, 0, 16), U2(0.5, 0, 0, 120), anchor=(0.5, 0), zindex=12, color=rgb(255, 230, 80), text_size=12),
        label("Rewards", "Rewards: 💵 +72K  🐟 +24K", U2(1, -8, 0, 16), U2(0.5, 0, 0, 142), anchor=(0.5, 0), zindex=12, text_size=11),
        button("Claim", U2(1, -16, 0, 30), U2(0.5, 0, 1, -8), *GRAY, text="Claim!", radius=8, anchor=(0.5, 1), zindex=12),
    ])
    body = [
        frame("Cats", U2(0, 110, 1, -40), U2(0, 0, 0, 0), transparency=1, children=[
            inst("UIListLayout", "List", {"Padding": U(0, 6), "SortOrder": "LayoutOrder"}), *cat_frames]),
        frame("Pets", U2(0, 300, 0, 140), U2(0, 120, 0, 0), transparency=1, children=[
            inst("UIGridLayout", "Grid", {"CellSize": U2(0, 70, 0, 66), "CellPadding": U2(0, 4, 0, 4), "SortOrder": "LayoutOrder"}), *pets]),
        frame("Progress", U2(0, 300, 0, 22), U2(0, 120, 0, 146), rgb(35, 38, 60), children=[
            corner(11), label("T", "0/8", U2(1, 0, 1, 0), U2(0, 0, 0, 0), zindex=12, text_size=12)]),
        detail,
        label("Discovered", "📘 Discovered  0 /184", U2(0, 200, 0, 20), U2(0, 0, 1, -8), anchor=(0, 1), align="Left", font="GothamBold", text_size=13),
        button("ClaimAll", U2(0, 110, 0, 32), U2(0, 310, 1, -4), *GRAY, text="Claim All", radius=8, anchor=(0, 1)),
    ]
    return window("Index", "Index", "📘", PINK, size=(620, 340), body=body)

def spin_popup():
    prizes = ["Cursed Egg", "Gold Lion", "x2 Cash 30m", "Speed 15m", "$10K", "Fast Hatch", "Pumpkin Egg", "Treadmill 30m"]
    seg_cols = [rgb(150, 70, 230), rgb(255, 200, 60), rgb(80, 200, 120), rgb(70, 160, 255),
                rgb(255, 120, 60), rgb(240, 80, 160), rgb(255, 160, 50), rgb(90, 220, 220)]
    segs = []
    for i, (p, c) in enumerate(zip(prizes, seg_cols)):
        # a label pinned at the rim, rotated so it reads toward the hub
        segs.append(frame(f"Seg{i}", U2(0, 110, 0, 40), U2(0.5, 0, 0.5, 0), c, anchor=(1, 0.5), zindex=13,
                          extra={"Rotation": i * 45 - 90}, children=[
                              corner(20),
                              label("Name", p, U2(1, -10, 1, -8), U2(0.5, 0, 0.5, 0), anchor=(0.5, 0.5), zindex=14, text_size=12)]))
    wheel = frame("Wheel", U2(0, 260, 0, 260), U2(0.5, 0, 0.5, -10), rgb(255, 255, 255), anchor=(0.5, 0.5), zindex=12, children=[
        inst("UICorner", "Round", {"CornerRadius": U(1, 0)}),
        stroke(6, rgb(255, 255, 255)),
        inst("UIGradient", "Rainbow", {"Rotation": 0, "Color": {"ColorSequence": {"keypoints": [
            {"time": 0, "color": rgb(255, 80, 80)}, {"time": 0.25, "color": rgb(255, 220, 60)},
            {"time": 0.5, "color": rgb(80, 220, 120)}, {"time": 0.75, "color": rgb(80, 140, 255)},
            {"time": 1, "color": rgb(220, 80, 255)}]}}}),
        *segs,
        frame("Hub", U2(0, 36, 0, 36), U2(0.5, 0, 0.5, 0), rgb(255, 170, 40), anchor=(0.5, 0.5), zindex=15, children=[
            inst("UICorner", "Round", {"CornerRadius": U(1, 0)}), stroke(3)]),
    ])
    pointer = label("Pointer", "▼", U2(0, 36, 0, 36), U2(0.5, 0, 0.5, -150), anchor=(0.5, 0.5), color=rgb(255, 190, 40), zindex=16)
    spin_btn = button("SpinButton", U2(0, 110, 0, 40), U2(0.5, 0, 0.5, 140), rgb(110, 115, 140), rgb(70, 75, 100),
                      text="Spin (1)", radius=10, anchor=(0.5, 0.5), zindex=13)
    fast = frame("FastSpin", U2(0, 100, 0, 20), U2(0.5, 110, 0.5, 100), transparency=1, anchor=(0.5, 0.5), zindex=13, children=[
        frame("Box", U2(0, 16, 0, 16), U2(0, 0, 0.5, 0), rgb(40, 45, 70), anchor=(0, 0.5), zindex=13, children=[corner(4), stroke(2)]),
        label("T", "Fast Spin", U2(0, 76, 1, 0), U2(0, 22, 0, 0), zindex=13, text_size=13, align="Left"),
    ])
    title = label("Title", "Quest Wheel!", U2(0, 240, 0, 30), U2(0.5, 0, 0.5, -170), anchor=(0.5, 0.5),
                  color=rgb(120, 255, 120), zindex=13)
    close = button("Close", U2(0, 40, 0, 40), U2(0.5, 180, 0.5, -130), *PINK, text="X", radius=10, anchor=(0.5, 0.5), zindex=16)
    return frame("SpinWheel", U2(0, 420, 0, 400), U2(0.5, 0, 0.5, 0), NAVY, anchor=(0.5, 0.5), transparency=1,
                 visible=False, zindex=10, children=[scale("Pop", 1), title, wheel, pointer, spin_btn, fast, close])

def placeholder(name, title, icon, cols):
    body = [label("Soon", "Coming soon", U2(1, 0, 1, 0), U2(0, 0, 0, 0), color=rgb(200, 200, 220))]
    return window(name, title, icon, cols, size=(380, 200), body=body)

def rays():
    kids = [frame(f"Ray{i}", U2(0, 1600, 0, 40), U2(0.5, 0, 0.5, 0), rgb(255, 255, 200), anchor=(0.5, 0.5),
                  transparency=0.82, zindex=9, extra={"Rotation": i * 30}) for i in range(6)]
    return frame("Rays", U2(1, 0, 1, 0), U2(0, 0, 0, 0), transparency=1, visible=False, zindex=9,
                 extra={"ClipsDescendants": True}, children=kids)

def popups():
    return frame("Popups", U2(1, 0, 1, 0), U2(0, 0, 0, 0), transparency=1, zindex=9, children=[
        scale(), rays(),
        daily_popup(), playtime_popup(), quests_popup(), settings_popup(), index_popup(), spin_popup(),
        placeholder("Shop", "SHOP", "🛒", GREEN), placeholder("Pass", "SEASON PASS", "🎫", YELLOW),
        placeholder("Eggs", "EGGS", "🥚", ORANGE), placeholder("Pets", "PETS", "🐾", ORANGE),
    ])

# ---------------------------------------------------------------- write
def strip_none(d):
    if isinstance(d, dict):
        return {k: strip_none(v) for k, v in d.items() if v is not None}
    if isinstance(d, list):
        return [strip_none(v) for v in d]
    return d

os.makedirs(OUT, exist_ok=True)
for fname, tree in (("HUD.model.json", hud()), ("Popups.model.json", popups())):
    with open(os.path.join(OUT, fname), "w", encoding="utf-8") as f:
        json.dump(strip_none(tree), f, ensure_ascii=False, indent=1)
    print("wrote", fname)
