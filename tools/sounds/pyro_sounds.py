"""The Pyromaniac's layered sounds: ONE source for three generated files.

Each sound of the kit (a "cue") is up to five layers (transient, mechanism,
body, sub, tail). The ids are free Pro Sound Effects sounds from the Creator
Store (STOCK), picked and levelled by measurement (tools/sounds/ears.py):
each file's leading blank is cut, its level matched to its variants, and
each layer set to a target loudness. This script writes:
  * the Sounds.luau block (one entry per layer), pasted at the end of
    src/shared/Sounds.luau;
  * src/shared/SoundCues.luau (which layers make a cue, when each starts);
  * docs/SONS_PYROMANE_FR.md (the sounds and their measurements, the
    five-layer designs and generation prompts for later).

Run from the repo root (needs numpy and ffmpeg for --measure):
  python3 tools/sounds/pyro_sounds.py --measure --cache /some/dir   (download + measure)
  python3 tools/sounds/pyro_sounds.py --verify                      (store details API)
  python3 tools/sounds/pyro_sounds.py --write && stylua src
"""

import gzip
import json
import math
import os
import re
import subprocess
import sys

BRIEF = (
    "Design a layered sound effect for {thing}. Break it into transient, "
    "mechanism, body, sub, and tail layers, and for each give the source, "
    "pitch range, texture, and timing. Then write one ready-to-paste audio "
    "generation prompt per layer, plus suggested mix levels."
)

LAYERS = ["Transient", "Mechanism", "Body", "Sub", "Tail"]
LAYERS_FR = {
    "Transient": "Transitoire (l'attaque)",
    "Mechanism": "Mécanique",
    "Body": "Corps",
    "Sub": "Grave (sub)",
    "Tail": "Queue (la fin)",
}

# Each layer: (source FR, pitch range, texture FR, start ms, length ms, dB, prompt EN)
CUES = [
    {
        "name": "ZippoOpen",
        "thing": "a brass Zippo-style lighter lid being flicked open with the thumb",
        "fr": "Le couvercle du Zippo qui s'ouvre d'un coup de pouce (le « clink »).",
        "when": "IMMOLATION (1,85 s), quand il sort le briquet pour rallumer la veilleuse.",
        "gain": -4,
        "layers": [
            ("Le bord du couvercle en laiton qui claque contre le boîtier", "2-9 kHz", "clic métallique sec, très court", 0, 25, 0,
             "Single sharp metallic click of a brass lighter lid snapping open, close-miked, extremely short, dry, no reverb, no other sounds, isolated one-shot, 0.1 seconds."),
            ("La came à ressort de la charnière qui bascule", "1-5 kHz", "« clink » aigu qui sonne une fraction de seconde", 10, 120, -3,
             "The distinctive spring-loaded hinge clink of a Zippo lighter opening, bright metallic ping with a tiny spring twang, close-miked, dry, isolated, 0.3 seconds."),
            ("La résonance du boîtier creux en laiton", "600 Hz-3 kHz", "petit tintement creux, boisé par la main", 15, 200, -8,
             "Short hollow resonance of a small brass box held in a hand, soft metallic ring, muted by fingers, no click at the start, isolated, 0.3 seconds."),
            ("Le pouce qui pousse le couvercle", "80-250 Hz", "petit « tok » sourd de chair sur métal", 0, 60, -16,
             "Very soft low thump of a thumb pushing against a small metal object, muffled, subtle, no ring, isolated, 0.1 seconds."),
            ("Le tintement qui s'éteint dans une petite pièce", "1-6 kHz", "réverbération très courte, métallique", 50, 350, -14,
             "Tiny metallic ring decaying in a small room, very short natural reverb tail only, no initial click, isolated, 0.5 seconds."),
        ],
    },
    {
        "name": "ZippoStrike",
        "thing": "a Zippo lighter's flint wheel being struck and the wick catching fire",
        "fr": "La molette frottée sur la pierre, les étincelles, la mèche qui prend feu.",
        "when": "IMMOLATION (2,15 s), juste après ZippoOpen.",
        "gain": -4,
        "layers": [
            ("La molette d'acier qui accroche la pierre", "2-10 kHz", "« tchk » granuleux, très bref", 0, 30, 0,
             "Sharp gritty click of a steel flint wheel being struck by a thumb on a lighter, close-miked, dry, extremely short, isolated one-shot, 0.1 seconds."),
            ("La molette crantée qui tourne et râpe la pierre, les étincelles", "3-12 kHz", "râpe rapide et grésillement d'étincelles", 10, 120, -4,
             "Fast rasp of a knurled steel wheel scraping a ferrocerium flint, with a tiny crackle of sparks, close-miked, dry, isolated, 0.15 seconds."),
            ("La mèche imbibée d'essence qui s'allume", "200 Hz-2 kHz", "« fff » doux et aéré", 60, 300, -2,
             "Soft airy whoof of a lighter wick catching fire, gentle puff of a small naphtha flame igniting, close-miked, no click, isolated, 0.4 seconds."),
            ("La flamme qui gonfle", "50-150 Hz", "souffle grave très léger", 70, 250, -14,
             "Very subtle low airy bloom of a small flame igniting, soft low-frequency puff, no high frequencies, isolated, 0.3 seconds."),
            ("La petite flamme qui flotte", "300 Hz-3 kHz", "flottement doux et régulier, léger crépitement", 150, 800, -12,
             "Small steady lighter flame fluttering gently in still air, soft breathy flicker with faint crackle, close-miked, isolated, 1 second."),
        ],
    },
    {
        "name": "ZippoClose",
        "thing": "a Zippo lighter lid snapping shut and smothering the flame",
        "fr": "Le couvercle refermé d'un coup sec : la flamme étouffée.",
        "when": "IMMOLATION (2,62 s) : le briquet refermé et rangé.",
        "gain": -5,
        "layers": [
            ("Le couvercle qui claque sur le boîtier", "1-8 kHz", "« clac » métallique plein", 0, 30, 0,
             "Solid metallic snap of a brass lighter lid closing hard, close-miked, dry, very short, isolated one-shot, 0.1 seconds."),
            ("La came de la charnière qui se rabat", "1-5 kHz", "petit cliquetis à ressort", 5, 90, -5,
             "Small spring hinge clack of a Zippo lid closing, tight mechanical click, dry, isolated, 0.2 seconds."),
            ("Le boîtier serré dans la main", "300 Hz-2 kHz", "« toc » creux et étouffé", 5, 120, -9,
             "Muffled hollow knock of a small metal case closing inside a fist, dull, short, isolated, 0.2 seconds."),
            ("La paume qui serre", "60-200 Hz", "petit coup sourd", 0, 80, -18,
             "Very soft low thud of a hand closing around a small object, subtle, isolated, 0.1 seconds."),
            ("La flamme étouffée", "500 Hz-4 kHz", "petit « pff » d'air coupé, puis rien", 30, 250, -12,
             "Tiny puff of a small flame being smothered under a metal lid, short soft hiss cut off, isolated, 0.3 seconds."),
        ],
    },
    {
        "name": "MolotovThrow",
        "thing": "a lit Molotov cocktail bottle being thrown overhand and flying past",
        "fr": "Le lancer : le bras, le liquide qui ballotte, la flamme du chiffon qui file dans l'air.",
        "when": "NAPALM LOB et NAPALM MORTAR : la boule de napalm en vol (la flamme qui passe).",
        "gain": -3,
        "layers": [
            ("Le bras et la veste qui fendent l'air", "300 Hz-4 kHz", "« fff » de mouvement rapide, tissu", 0, 150, -4,
             "Quick swish of an arm and jacket sleeve swinging hard overhand, cloth whoosh, short, isolated, 0.2 seconds."),
            ("L'essence qui ballotte dans la bouteille de verre", "200 Hz-2 kHz", "glouglou de liquide dans du verre", 0, 300, -9,
             "Liquid sloshing inside a glass wine bottle as it is swung, short glug and slosh, close-miked, isolated, 0.3 seconds."),
            ("La flamme du chiffon qui file", "150 Hz-3 kHz", "flamme qui ronfle en passant (effet Doppler)", 80, 700, 0,
             "A small burning rag flame flying through the air and passing by, fluttering fire whoosh with a doppler pitch drop, isolated, 0.8 seconds."),
            ("L'air poussé", "40-120 Hz", "souffle grave léger", 80, 300, -16,
             "Subtle low air push of an object thrown hard, soft low whump, isolated, 0.3 seconds."),
            ("La flamme qui s'éloigne", "300 Hz-3 kHz", "flottement qui s'éteint au loin", 500, 900, -12,
             "Fluttering flame receding into the distance, fading fire flutter, isolated, 1 second."),
        ],
    },
    {
        "name": "FuelIgnite",
        "thing": "spilled petrol on the ground igniting into a fireball",
        "fr": "L'essence répandue qui s'embrase : la boule de feu.",
        "when": "Juste après GlobSplat (la flaque prend feu).",
        "gain": 0,
        "layers": [
            ("Les vapeurs d'essence qui s'enflamment", "300 Hz-6 kHz", "« fwump » sec, claquant", 0, 80, -2,
             "Sharp dry pop of petrol vapour igniting, a quick fwump crack, not an explosion, close, isolated one-shot, 0.15 seconds."),
            ("Le front de flamme qui court sur la flaque", "500 Hz-6 kHz", "balayage de feu qui file sur le liquide", 30, 400, -6,
             "Flame front rushing across a spreading pool of petrol, fast sweeping hiss of fire, isolated, 0.5 seconds."),
            ("La boule de feu", "100 Hz-3 kHz", "rugissement de flamme large et chaud", 50, 1200, 0,
             "Large roaring fireball rising from burning petrol, deep warm rolling roar that swells then settles, no explosion debris, isolated, 1.3 seconds."),
            ("La pression d'air", "25-90 Hz", "« whoomp » profond", 40, 500, -4,
             "Deep low-frequency whoomp of a fireball pushing air, sub-bass pressure swell, no high frequencies, isolated, 0.5 seconds."),
            ("Le feu qui retombe en crépitant", "300 Hz-5 kHz", "rugissement qui baisse vers un crépitement", 700, 1500, -8,
             "A large fire roar settling down into a steady crackling burn, fading, isolated, 1.5 seconds."),
        ],
    },
    {
        "name": "PoolFire",
        "looped": True,
        "thing": "a pool of burning petrol on a street floor (seamless loop)",
        "fr": "La flaque d'essence qui brûle (BOUCLE, tant que le feu dure).",
        "when": "Pendant tout le feu au sol (napalm, INFERNO), en 3D sur la flaque, baisse quand le feu meurt.",
        "gain": -3,
        "layers": [
            ("Les petits claquements de la flamme (bulles qui éclatent)", "1-8 kHz", "« pops » irréguliers", 0, 0, -8,
             "Seamless loop of irregular small pops and snaps from a fire burning on a liquid, sparse crackle only, no roar, isolated, 6 seconds, loopable."),
            ("L'essence qui bout et grésille à la surface", "1-7 kHz", "grésillement continu, mouillé", 0, 0, -10,
             "Seamless loop of fuel bubbling and sizzling on a hot surface, wet continuous sizzle, isolated, 6 seconds, loopable."),
            ("Les flammes", "150 Hz-3 kHz", "ronflement continu de feu, moyen", 0, 0, 0,
             "Seamless loop of a medium pool fire burning steadily outdoors, continuous warm roar with flutter, no wind, isolated, 8 seconds, loopable."),
            ("Le grondement", "30-100 Hz", "grondement grave stable", 0, 0, -10,
             "Seamless loop of a low steady rumble of a fire, sub-bass only, smooth, isolated, 6 seconds, loopable."),
            ("L'air aspiré par le feu", "200 Hz-2 kHz", "souffle d'air qui flotte, comme du vent", 0, 0, -14,
             "Seamless loop of air being drawn into a fire, soft breathy flutter like gentle wind, isolated, 6 seconds, loopable."),
        ],
    },
    {
        "name": "FireBreath",
        "thing": "a fire breather spitting atomised fuel through a lighter flame into a roaring jet of fire",
        "fr": "Le cracheur de feu : l'essence pulvérisée à travers la flamme, un jet de feu qui rugit.",
        "when": "FLAME STREAM (0,45 s → 1 s), TORCH CHARGE (le jet devant lui) et le pilier de l'Awakening (0,45 s).",
        "gain": 0,
        "layers": [
            ("Les lèvres qui crachent le liquide en brouillard", "1-8 kHz", "« pfff » éclaté, mouillé", 0, 120, -4,
             "Explosive wet spit of a mouthful of liquid sprayed through pursed lips into a mist, sharp pff, close, isolated, 0.15 seconds."),
            ("Le brouillard d'essence qui siffle", "2-10 kHz", "sifflement de pulvérisation fin", 20, 500, -8,
             "Fine hiss of atomised liquid spraying through the air, continuous misty spray, isolated, 0.6 seconds."),
            ("Le jet de flamme", "100 Hz-4 kHz", "rugissement de chalumeau large qui gonfle", 60, 700, 0,
             "Big roaring jet of flame from a fire breather, a fast rising whoosh that holds as a roaring tongue of fire, warm and wide, isolated, 0.8 seconds."),
            ("La poussée d'air chaud", "30-110 Hz", "« whoomp » grave", 60, 500, -6,
             "Deep low whoomp of a large flame blooming in the air, sub-bass swell, isolated, 0.5 seconds."),
            ("La flamme qui s'enroule et retombe", "300 Hz-5 kHz", "flamme qui roule et crépite en s'éteignant", 600, 900, -10,
             "A jet of flame curling up and dying out in the air, rolling flutter with crackle, fading, isolated, 1 second."),
        ],
    },
    {
        "name": "FuelSplash",
        "thing": "petrol flung from a metal jerrycan onto a person",
        "fr": "L'essence projetée hors du jerrican sur quelqu'un (DOUSE).",
        "when": "FUEL SPRAY (0,4 s) : le carburant cru pulvérisé ; IMMOLATION (0,4 s) : le carburant versé.",
        "gain": -2,
        "layers": [
            ("Le liquide qui sort d'un coup du bec", "500 Hz-6 kHz", "claque de liquide lancée", 0, 80, -3,
             "Sudden slap of liquid thrown out of a can spout, sharp wet burst, close, isolated, 0.1 seconds."),
            ("Le jerrican en tôle qui se tord et la poignée qui grince", "200 Hz-3 kHz", "« bonk » de tôle creuse, grincement", 0, 250, -8,
             "Hollow metal jerrycan flexing with a dull bonk as it is swung, handle creak, isolated, 0.3 seconds."),
            ("L'arc d'essence qui s'écrase sur le corps et le sol", "150 Hz-5 kHz", "grande éclaboussure étalée, mouillée", 50, 500, 0,
             "Wide arc of liquid splashing over a person and onto concrete, heavy wet splatter, isolated, 0.6 seconds."),
            ("Le poids du liquide", "40-140 Hz", "« floc » grave", 40, 200, -12,
             "Low heavy thud of a large mass of liquid landing, soft low splat, isolated, 0.2 seconds."),
            ("Les gouttes qui tombent", "1-8 kHz", "gouttes et filets qui ruissellent", 400, 1300, -14,
             "Liquid dripping from clothes onto concrete, scattered drips and a small trickle, quiet, isolated, 1.3 seconds."),
        ],
    },
    {
        "name": "BodyBurn",
        "looped": True,
        "thing": "a human body and its clothes burning (seamless loop)",
        "fr": "Un corps et ses vêtements en feu (BOUCLE). Aussi, plus bas, ses poings en feu pendant l'Awakening.",
        "when": "Sur la victime du finisher pendant qu'elle brûle, et (en plus faible) sur les avant-bras du Pyromane en Awakening.",
        "gain": -3,
        "layers": [
            ("Les petits éclatements (graisse, tissu)", "1-8 kHz", "« pops » et claquements irréguliers", 0, 0, -10,
             "Seamless loop of irregular sharp pops and snaps of a fire burning cloth and fat, sparse crackles only, isolated, 6 seconds, loopable."),
            ("Le tissu qui brûle", "1-7 kHz", "crépitement de vêtements qui se consument", 0, 0, -8,
             "Seamless loop of clothing burning, dense dry crackle of cotton and fabric being consumed, isolated, 6 seconds, loopable."),
            ("Les flammes autour du corps", "150 Hz-3 kHz", "ronflement de feu moyen, irrégulier", 0, 0, 0,
             "Seamless loop of a person-sized fire burning, irregular warm roar with flutter, close, isolated, 8 seconds, loopable."),
            ("Le grondement", "30-100 Hz", "grave doux et stable", 0, 0, -12,
             "Seamless loop of a soft low rumble under a fire, sub-bass only, isolated, 6 seconds, loopable."),
            ("Le grésillement de la peau (vapeur)", "2-9 kHz", "sifflement humide continu", 0, 0, -14,
             "Seamless loop of a wet sizzle, like meat on a hot grill, continuous steam hiss, isolated, 6 seconds, loopable."),
        ],
    },
    {
        "name": "SelfIgnite",
        "thing": "petrol-soaked forearm wraps being lit with a lighter and flaring up along both arms",
        "fr": "Il allume ses propres avant-bras imbibés d'essence (BURNING MAN).",
        "when": "L'activation de l'Awakening (0,55 s) : le retour de flamme sur ses avant-bras.",
        "gain": 0,
        "layers": [
            ("La flamme du briquet qui touche le tissu", "1-6 kHz", "petit « pff » sec", 0, 60, -6,
             "Tiny dry puff as a lighter flame touches fuel-soaked cloth wraps, short pop, isolated, 0.1 seconds."),
            ("Le tissu imbibé qui prend", "2-10 kHz", "crépitement qui court le long du bras", 20, 400, -6,
             "Crackle of fire racing along fuel-soaked fabric wrapped on an arm, quick running crackle, isolated, 0.5 seconds."),
            ("Les deux bras qui s'embrasent", "150 Hz-3 kHz", "double « whoosh » de flamme qui monte", 60, 700, 0,
             "Two quick whooshes of flame flaring up along both arms, rising warm fire roar, isolated, 0.8 seconds."),
            ("La flamme qui gonfle", "30-110 Hz", "« whoomp » grave", 60, 400, -8,
             "Deep soft whoomp of flames blooming, low-frequency swell, isolated, 0.4 seconds."),
            ("Les poings qui brûlent", "300 Hz-4 kHz", "flamme qui flotte et crépite", 500, 1200, -10,
             "Fire burning on fists and forearms, fluttering roar with crackle settling to steady, isolated, 1.2 seconds."),
        ],
    },
    {
        "name": "BodyIgnite",
        "thing": "a petrol-soaked person on the ground going up in flames",
        "fr": "Le corps imbibé qui s'embrase d'un coup (« whump »).",
        "when": "IMMOLATION, à 3,05 s (le jet à bout portant).",
        "gain": 0,
        "layers": [
            ("Les vapeurs d'essence qui s'enflamment", "300 Hz-6 kHz", "« fwump » sec", 0, 80, -2,
             "Sharp dry fwump of petrol vapour igniting around a body, quick pop, not an explosion, isolated, 0.1 seconds."),
            ("Le feu qui court sur les vêtements", "500 Hz-7 kHz", "balayage de flamme qui file sur le tissu", 20, 500, -5,
             "Fire racing over fuel-soaked clothes from chest to legs, fast sweeping crackling hiss, isolated, 0.5 seconds."),
            ("Le corps qui s'embrase", "100 Hz-3 kHz", "rugissement de feu qui enveloppe", 40, 1100, 0,
             "A person-sized fire engulfing a body in one roaring whoosh, warm deep roar swelling then holding, isolated, 1.2 seconds."),
            ("La pression d'air", "25-90 Hz", "« whoomp » profond", 30, 450, -4,
             "Deep low whoomp of flames bursting up, sub-bass pressure swell, isolated, 0.5 seconds."),
            ("Le feu qui s'installe", "300 Hz-5 kHz", "rugissement qui devient un crépitement", 800, 1300, -8,
             "A fire roar settling into a steady crackling burn of clothes, fading, isolated, 1.3 seconds."),
        ],
    },
    {
        "name": "BurnScream",
        "thing": "a man screaming in agony while burning, his voice breaking and cut short",
        "fr": "Les cris de la victime qui brûle (coupés à la mort).",
        "when": "IMMOLATION, de 3,2 s à 4,6 s (coupé net au « Still »).",
        "gain": -1,
        "layers": [
            ("L'inspiration brutale avant le cri", "300 Hz-4 kHz", "halètement aigu, choc", 0, 250, -4,
             "Sharp panicked gasp of an adult man in sudden pain, a short ragged intake of breath, close, isolated, 0.3 seconds."),
            ("La gorge qui râpe, la toux dans la fumée", "200 Hz-3 kHz", "râle et toux étouffée", 250, 1200, -8,
             "Raspy throat strain and choking coughs of a man in smoke, rough, close, isolated, 1.2 seconds."),
            ("Le cri d'agonie", "150 Hz-3 kHz", "cri brut, déchiré, homme adulte", 200, 1300, 0,
             "Raw agonised scream of an adult man in pain, ragged and breaking, realistic, not theatrical, no music, close, isolated, 1.4 seconds."),
            ("La poitrine", "70-200 Hz", "grognement grave de fond", 200, 1200, -14,
             "Low guttural chest groan under a scream, subtle, isolated, 1.2 seconds."),
            ("La voix qui se brise", "150 Hz-2.5 kHz", "voix qui casse en sifflement rauque", 1100, 400, -8,
             "A scream breaking into a rasping wheeze and stopping, voice giving out, isolated, 0.4 seconds."),
        ],
    },
]

# Cues with no five-layer design: their layers are only the ones in STOCK.
EXTRA_CUES = [
    {
        "name": "InfernoBreath",
        "thing": "the Inferno's longer jet of fire",
        "fr": "Le jet de l'INFERNO : le même que FireBreath, plus long.",
        "when": "INFERNO (0,45 s → 1,25 s) et le plein jet du finisher (3,05 s).",
    },
    {
        "name": "FireSwing",
        "thing": "a burning fist swung past like a torch",
        "fr": "Le poing ou le bras en feu qui fend l'air : une torche qui passe.",
        "when": "BLOWTORCH (0,16 s) : le canon chaud lancé vers eux.",
    },
    {
        "name": "FireImpact",
        "thing": "a burning fist landing: a puff of flame and searing skin",
        "fr": "Le poing en feu qui touche : un « pouf » de flamme et la peau qui grésille.",
        "when": "BLOWTORCH / TORCH CHARGE, au coup confirmé par le serveur.",
    },
    {
        "name": "CatchFire",
        "thing": "someone catching fire: a whoosh of flame wrapping round them, a sizzle",
        "fr": "Quelqu'un qui prend feu : un souffle de flamme qui l'enveloppe, un grésillement.",
        "when": "Le premier instant où un corps brûle (napalm, jet, flaque, finisher).",
    },
    {
        "name": "Extinguish",
        "thing": "the last flames on a body going out: a sizzle that dies down",
        "fr": "Le feu qui s'éteint sur un corps : un grésillement qui retombe.",
        "when": "Quand les dernières flammes d'un corps s'éteignent, et à la fin de l'Awakening.",
    },
    {
        "name": "PyreRoar",
        "thing": "the roar of a whole body burning (loop)",
        "looped": True,
        "fr": "Le grondement du corps qui brûle en entier (BOUCLE).",
        "when": "IMMOLATION, de l'embrasement (3,05 s) à la fin du feu (12 s), par-dessus le crépitement du corps.",
    },
    {
        "name": "GunDraw",
        "thing": "the flamethrower swung off his back, the fuel sloshing in the bottle",
        "fr": "Le lance-flammes ramené du dos à la hanche : l'essence qui ballotte dans la bouteille.",
        "when": "Chaque attaque, quand la main prend la poignée (0,15 s ; 0,08 s en Awakening).",
    },
    {
        "name": "PilotLight",
        "thing": "the pilot burner lit: a lever click and a soft blue fwip",
        "fr": "La veilleuse qui s'allume : un clic de levier et un petit « fwip » bleu.",
        "when": "Après le dégainage de chaque attaque, FUEL SPRAY (0,66 s : rallumée), IMMOLATION (2,3 s).",
    },
    {
        "name": "PilotOut",
        "thing": "the pilot flame shut off: a short high sizzle",
        "fr": "La veilleuse coupée : un petit grésillement aigu.",
        "when": "FUEL SPRAY (0,27 s), IMMOLATION (avant de verser le carburant).",
    },
    {
        "name": "TriggerClick",
        "thing": "the flamethrower's trigger squeezed: a dull metal click",
        "fr": "La gâchette pressée : un clic métallique sourd.",
        "when": "FLASH BURST (0,38 s), NAPALM LOB (0,6 s), FLAME STREAM (0,42 s), NAPALM MORTAR, INFERNO, TORCH CHARGE.",
    },
    {
        "name": "BurstPop",
        "thing": "a pressurised ball of fire popping out of a flamethrower, crackling drops",
        "fr": "La boule de feu sous pression qui éclate : un « pouf » franc, des gouttes qui crépitent.",
        "when": "FLASH BURST, sur le coup (0,42 s).",
    },
    {
        "name": "GlobLaunch",
        "thing": "a glob of napalm coughed out of the muzzle: a short burst of fire",
        "fr": "La boule de napalm crachée par le canon : une courte bouffée de feu.",
        "when": "NAPALM LOB (0,62 s), NAPALM MORTAR (0,45 s).",
    },
    {
        "name": "GlobSplat",
        "thing": "a glob of burning napalm splatting on the floor (no glass)",
        "fr": "La boule de napalm qui s'écrase au sol : un « splash » mouillé (pas de verre).",
        "when": "À l'impact de la boule (sol, mur ou sur quelqu'un), juste avant FuelIgnite.",
    },
    {
        "name": "StreamEnd",
        "thing": "the jet let go: the tail of the flame whooshing away",
        "fr": "Le jet relâché : la queue de la flamme qui s'éloigne.",
        "when": "Fin de FLAME STREAM, d'INFERNO et du plein jet du finisher (4,25 s).",
    },
    {
        "name": "PressureHiss",
        "thing": "the regulator's pressurised gas hiss rising",
        "fr": "Le sifflement du détendeur sous pression qui monte.",
        "when": "Sous les jets : FLASH BURST, NAPALM LOB (la pression qui monte), FLAME STREAM, l'Awakening, NAPALM MORTAR, INFERNO, IMMOLATION.",
    },
    {
        "name": "ValveCrank",
        "thing": "the ball valve slapped shut or the bottle's handwheel cranked: a metal clack",
        "fr": "La vanne claquée ou le volant de la bouteille tourné : un « clac » métallique.",
        "when": "NAPALM LOB (0,33 s étranglée, 0,58 s rouverte), l'Awakening (0,14 s), INFERNO (0,2 s), IMMOLATION.",
    },
    {
        "name": "TorchLance",
        "thing": "a short hard blowtorch lance lighting",
        "fr": "La lance du chalumeau qui s'allume : un jet court et dur.",
        "when": "BLOWTORCH (0,22 s, juste avant le coup).",
    },
    {
        "name": "Vent",
        "thing": "the overheated gun's relief valve venting: a white-hot hiss",
        "fr": "La soupape de sécurité du lance-flammes surchauffé : un long sifflement brûlant.",
        "when": "IMMOLATION (4,8 s), après la mort.",
    },
]
ALL_CUES = CUES + EXTRA_CUES


class L:
    """One filled layer of a cue (free Creator Store sounds).

    ids     the variants (one at random each time, never twice in a row)
    target  the level it should have: loudest momentary loudness (LUFS) for a
            one-shot, integrated loudness for a loop. The volume and each id's
            gain are worked out from the measurements (pyro_measure.json).
    at      seconds after the cue starts
    start   "onset" (cut the blank: 10 ms before the file's onset), "peak-X"
            (start X seconds before its loudest point: the peak lands X s after
            the cue), or seconds; the same for every id
    length  seconds played (then faded out over `fade`)
    """

    def __init__(self, layer, ids, target, at=0.0, pitch=1.0, start="onset", length=None, fade=None,
                 pv=None, vv=1.5):
        self.layer, self.ids, self.target, self.at = layer, ids, target, at
        self.pitch, self.start, self.length, self.fade = pitch, start, length, fade
        self.pv, self.vv = pv, vv


# THE SOURCE of the ids (Sounds.luau is rewritten from it). Every id is a
# public, free ProSoundEffects sound effect (Roblox's licensed library,
# verified creator), downloaded and measured by --measure.
STOCK = {
    "ZippoOpen": [L("Body", [9121005566], -26, pv=0.07)],
    "ZippoStrike": [
        L("Body", [9121005779], -24, pv=0.06),
        # (the flame catching: a soft puff under the wheel, two kinds)
        L("Tail", [9114446183, 9114445526], -33, at=0.12, pv=0.08),
    ],
    "ZippoClose": [L("Body", [9121005783], -27, pv=0.07)],
    "MolotovThrow": [L("Body", [9114463219, 9114463410, 9114463208, 9114463016], -21, length=1.4, fade=0.3)],
    # (the fireball pops 0.06 s after the glass; its tail fades over 1 s while
    # the pool's loop fades in: one sound turning into the other)
    "FuelIgnite": [
        L("Body", [9114429507, 9114429835, 9114429958, 9114429740], -13, length=2.2, fade=1.0),
        L("Sub", [9114554567], -21, pitch=0.8, length=1.5, fade=0.5, pv=0.03),
    ],
    "PoolFire": [
        L("Body", [9112780561], -25),
        L("Mechanism", [9112780462], -31),
    ],
    "FireBreath": [
        L("Transient", [9114446277, 9114441555], -19, start="peak-0.08"),
        L("Body", [9117984812, 9117985848, 9117985933], -15, at=0.05, length=0.75, fade=0.3),
        L("Tail", [9114445526], -29, at=0.6, length=1.0, fade=0.3),
    ],
    "InfernoBreath": [
        L("Transient", [9114446277, 9114441555], -18, start="peak-0.08"),
        L("Body", [9117984812, 9117985848, 9117985933], -14, at=0.05, length=0.95, fade=0.35),
        L("Tail", [9114445526], -28, at=0.8, length=1.0, fade=0.3),
    ],
    "FuelSplash": [
        L("Body", [9125702439, 9125702803], -20, pv=0.08),
        L("Mechanism", [9126173160], -22, length=1.0, fade=0.3),
    ],
    "BodyBurn": [L("Body", [9112780438, 9112780212, 9112780193], -29)],
    "PyreRoar": [L("Body", [9112780691], -28)],
    # (the boom's peak lands on the arms flung out, 0.2 s after the cue)
    "SelfIgnite": [
        # (the left wrist catching at 0.55, the right arm at 0.63)
        L("Mechanism", [9114446277, 9114441555], -20, start="peak-0.1"),
        L("Body", [9117983605, 9117983322, 9117986652], -16, start="peak-0.2", pv=0.04),
    ],
    "BodyIgnite": [
        L("Body", [9114429835, 9114429507], -12, start="peak-0.04", length=3.0, fade=1.2),
        L("Sub", [9114554567], -20, pitch=0.8, length=1.5, fade=0.5, pv=0.03),
        L("Tail", [9119165650, 9119166424], -22, at=0.15),
    ],
    "BurnScream": [L("Body", [9116454870, 9125652466, 9125652432], -15, length=1.4, fade=0.15, pv=0.04)],
    "FireSwing": [L("Body", [9114462915, 9114462930, 9114463010, 9114463022], -20, start="peak-0.12", length=1.0, fade=0.3)],
    "FireImpact": [
        L("Body", [9114443884, 9114444052], -18, start="peak-0.02", length=0.8, fade=0.2),
        L("Tail", [9119166424, 9119166217, 9119165644, 9119166425], -22, at=0.02, length=1.2, fade=0.3),
    ],
    "CatchFire": [
        L("Body", [9114446183, 9114445526, 9114462912], -22),
        L("Tail", [9119165912, 9119165930], -30, at=0.1),
    ],
    "Extinguish": [L("Body", [9119166199, 9119165933], -30, pitch=0.9, length=1.2, fade=0.4)],
    # --- the flamethrower (built from the same measured files) ---
    "GunDraw": [L("Body", [9114190682], -30, length=0.4, fade=0.15)],
    "PilotLight": [
        L("Body", [9121005783], -32, pitch=1.3),
        L("Tail", [9114446183], -34, at=0.05),
    ],
    "PilotOut": [L("Body", [9119166199], -32, pitch=1.2, length=0.4, fade=0.15)],
    "TriggerClick": [L("Body", [9121005566], -30, pitch=0.8)],
    # (the peak lands 30 ms after the cue, on the hit)
    "BurstPop": [
        L("Body", [9114442751, 9114444052, 9114443884, 9114444008], -15, start="peak-0.03", length=1.0, fade=0.3),
        L("Tail", [9119166424, 9119166217, 9119165644, 9119166425], -23, at=0.05, length=1.2, fade=0.3),
    ],
    "GlobLaunch": [
        L("Transient", [9114446277, 9114441555], -20, start="peak-0.05", length=0.4, fade=0.15),
        L("Body", [9114429507, 9114429835], -17, length=0.5, fade=0.2),
    ],
    "GlobSplat": [L("Body", [9125702439, 9125702803], -18, pv=0.08)],
    "StreamEnd": [L("Tail", [9114445526], -28, length=1.0, fade=0.4)],
    "PressureHiss": [L("Body", [9126173160], -30, pitch=1.4, length=0.8, fade=0.3)],
    "ValveCrank": [L("Body", [9121005783], -27, pitch=0.6)],
    "TorchLance": [L("Body", [9114446277, 9114441555], -18, pitch=1.25, start="peak-0.05", length=0.25, fade=0.1)],
    "Vent": [
        L("Body", [9119166199, 9119165933], -26, pitch=0.8, length=1.5, fade=0.5),
        L("Tail", [9114445526], -30, at=0.1, length=1.5, fade=0.5),
    ],
}

# Why each file was picked (French, for the doc). Name and creator come from the
# store's details API (--verify), the numbers from --measure.
WHY = {
    9121005566: "le « clink » du couvercle, net, sans blanc",
    9121005779: "la molette puis le « fff » de la mèche",
    9114446183: "petit souffle doux : la mèche qui prend",
    9114445526: "souffle doux et long : la flamme qui flotte, qui retombe",
    9121005783: "un « clac » sec : le couvercle refermé",
    9114442751: "« pouf » de kérosène très court et franc",
    9114444052: "variante, plus ronde",
    9114443884: "variante, plus grave",
    9114444008: "variante, plus sèche",
    9125616715: "les gouttes qui crépitent après le pouf",
    9125616655: "variante",
    9114446852: "le chiffon qui s'embrase, court",
    9114447022: "variante qui gonfle plus lentement",
    9114446802: "variante",
    9114463219: "torche qui passe : la flamme du chiffon qui file",
    9114463410: "variante",
    9114463208: "variante",
    9114463016: "variante, plus grave",
    9113552392: "bouteille qui éclate sur du béton",
    9113552215: "variante",
    9113552246: "variante",
    9113553645: "variante, plus grosse",
    9125702439: "l'essence qui gicle au sol",
    9125702803: "variante",
    9114429507: "boule de feu qui part d'un coup (pas une montée lente)",
    9114429835: "variante, plus grave",
    9114429958: "variante, plus claire",
    9114429740: "variante",
    9114554567: "le « whoump » grave de l'essence",
    9112780561: "kérosène qui brûle au sol, 49 s, niveau stable, sans crépitement fort",
    9112780462: "crépitement de feu de bois, 43 s : le grain sous la flaque",
    9114171960: "une gorgée bue de près",
    9114172109: "variante",
    9114446277: "jet de kérosène à travers une torche (« lance-flammes »)",
    9114441555: "variante, plus courte",
    9117984812: "long jet de feu (pyrotechnie de cinéma)",
    9117985848: "variante",
    9117985933: "variante, plus sèche",
    9114190682: "liquide qui ballotte dans un fût",
    9126173160: "le liquide qui part d'un coup",
    9112780438: "feu qui brûle, régulier, 36 s (une boucle choisie par corps)",
    9112780212: "variante, plus de crépitements",
    9112780193: "variante, plus sourde",
    9112780691: "grondement de feu de kérosène, 56 s",
    9117983605: "boule de feu courte et grave",
    9117983322: "variante",
    9117986652: "variante",
    9120575856: "liquide versé qui éclabousse",
    9113704875: "bidon de métal lâché qui rebondit : net, creux, sans saturation (crête -4,3 dBFS)",
    9114462912: "petite flamme qui passe, jouée plus aiguë",
    9119165650: "saisie qui grésille : la chair qui brûle",
    9119166424: "grésillement court",
    9119166217: "variante",
    9119165644: "variante",
    9119166425: "variante",
    9116454870: "homme qui hurle de douleur",
    9125652466: "cri d'agonie bref",
    9125652432: "variante",
    9114462915: "torche agitée qui passe",
    9114462930: "variante",
    9114463010: "variante",
    9114463022: "variante",
    9119165912: "grésillement doux qui monte",
    9119165930: "variante",
    9119166199: "grésillement qui retombe",
    9119165933: "variante",
}

MEASURE_PATH = "tools/sounds/pyro_measure.json"


def looped(name):
    for cue in ALL_CUES:
        if cue["name"] == name:
            return bool(cue.get("looped"))
    raise KeyError(name)


def load_measure():
    try:
        return json.load(open(MEASURE_PATH))
    except FileNotFoundError:
        return {"files": {}, "segments": {}, "details": {}}


def start_of(spec, whole):
    if isinstance(spec.start, (int, float)):
        return float(spec.start)
    if spec.start == "onset":
        return max(0.0, round(whole["onset"] - 0.01, 2))
    if spec.start.startswith("peak-"):
        return max(0.0, round(whole["peak"] - float(spec.start[5:]), 2))
    raise ValueError(spec.start)


def seg_key(i, start, length):
    return f"{i}@{start:g}+{length:g}" if length else f"{i}@{start:g}"


def mix(name, spec, measure):
    """-> volume, {id: (start, gain, measured, final level)}"""
    loop = looped(name)
    rows = {}
    for i in spec.ids:
        whole = measure["files"][str(i)]
        start = 0.0 if loop else start_of(spec, whole)
        seg = whole if loop else measure["segments"][seg_key(i, start, spec.length)]
        level = seg["I"] if loop else seg["Mmax"]
        rows[i] = [start, 1.0, level, seg]
    mean = sum(r[2] for r in rows.values()) / len(rows)
    vol = min(10.0, round(10 ** ((spec.target - mean) / 20), 2))
    for i, r in rows.items():
        r[1] = 1.0 if len(rows) == 1 else round(10 ** ((mean - r[2]) / 20), 2)
    return vol, rows


def measure(cache):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import ears  # noqa

    os.makedirs(cache, exist_ok=True)
    data = load_measure()
    used = set()
    for name, specs in STOCK.items():
        for spec in specs:
            for i in spec.ids:
                path = os.path.join(cache, f"{i}.ogg")
                if not os.path.exists(path):
                    raw = subprocess.run(["curl", "-sSL", f"https://assetdelivery.roblox.com/v1/asset/?id={i}"],
                                         capture_output=True).stdout
                    if raw[:2] == b"\x1f\x8b":
                        raw = gzip.decompress(raw)
                    assert raw[:4] == b"OggS", f"{i}: not a public sound file"
                    open(path, "wb").write(raw)
                if str(i) not in data["files"]:
                    data["files"][str(i)] = ears.analyse(path)
                if looped(name):
                    continue
                start = start_of(spec, data["files"][str(i)])
                key = seg_key(i, start, spec.length)
                if key not in data["segments"]:
                    data["segments"][key] = ears.analyse(path, start, spec.length)
                used.add(key)
                print(name, spec.layer, key, data["segments"][key]["Mmax"])
    # (only what STOCK uses now)
    ids = {str(i) for specs in STOCK.values() for spec in specs for i in spec.ids}
    data["files"] = {k: v for k, v in data["files"].items() if k in ids}
    data["segments"] = {k: v for k, v in data["segments"].items() if k in used}
    data["details"] = {k: v for k, v in data["details"].items() if k in ids}
    json.dump(data, open(MEASURE_PATH, "w"), indent=1, sort_keys=True, default=float)


def verify():
    """Every id through the Creator Store details API: public, audio, creator."""
    data = load_measure()
    ids = sorted({i for specs in STOCK.values() for spec in specs for i in spec.ids})
    for k in range(0, len(ids), 30):
        chunk = ",".join(str(i) for i in ids[k:k + 30])
        out = subprocess.run(["curl", "-sS", f"https://apis.roblox.com/toolbox-service/v1/items/details?assetIds={chunk}"],
                             capture_output=True, text=True).stdout
        for item in json.loads(out).get("data", []):
            a, c = item.get("asset", {}), item.get("creator", {})
            data["details"][str(a.get("id"))] = {
                "name": a.get("name"), "creator": c.get("name"), "verified": c.get("isVerifiedCreator"),
                "type": (a.get("audioDetails") or {}).get("audioType"), "visible": a.get("visibilityStatus") == 0,
                "free": (item.get("fiatProduct") or {}).get("isFree"),
            }
    missing = [i for i in ids if str(i) not in data["details"]]
    bad = [i for i in ids if str(i) in data["details"] and (
        # (the long Pro Sound Effects files are typed "Unknown", not "SoundEffect")
        data["details"][str(i)]["type"] not in ("SoundEffect", "Unknown") or not data["details"][str(i)]["verified"]
        or not data["details"][str(i)]["visible"] or not data["details"][str(i)]["free"])]
    for i in ids:
        d = data["details"].get(str(i))
        print(i, d)
    json.dump(data, open(MEASURE_PATH, "w"), indent=1, sort_keys=True, default=float)
    assert not missing, f"not found in the store: {missing}"
    assert not bad, f"not a free public sound effect from a verified creator: {bad}"


LUA_HEADER_COMMENT = """\t-- Pyromaniac (Shared/Kits/Pyromaniac) --------------------------------------------------
\t-- A kit sound is a cue of up to FIVE layers played together (Shared/SoundCues: when each
\t-- starts): _Transient, _Mechanism, _Body, _Sub, _Tail. A layer with ids = {} is silent.
\t-- The ids are free Pro Sound Effects sounds, picked and levelled by measurement
\t-- (docs/SONS_PYROMANE_FR.md): `trims` cuts each file's blank and evens out its level.
\t-- Generated by tools/sounds/pyro_sounds.py (edit STOCK there, then --write; ids typed
\t-- here in a layer that is not in STOCK are kept).
"""
BEGIN = "\t-- >>> Pyromaniac sounds (generated)\n"
END = "\t-- <<< Pyromaniac sounds (generated)\n"


def volume(cue, db):
    return round(10 ** ((cue["gain"] + db) / 20), 2)


def entry_name(name, layer):
    return f"{name}_{layer}"


def stock_layer(name, layer):
    for spec in STOCK.get(name, []):
        if spec.layer == layer:
            return spec
    return None


def layer_names(cue):
    if "layers" in cue:
        return LAYERS
    return [s.layer for s in STOCK.get(cue["name"], [])]


def lua_entry(name, ids, vol, pitch, pv, extra):
    fields = [f"ids = {{{ids}}}", f"volume = {vol:g}", f"pitch = {pitch:g}", f"pitchVariation = {pv:g}"] + extra
    line = f"\t{name} = {{ {', '.join(fields)} }},\n"
    if "\n" not in "".join(extra) and len(line.expandtabs(4)) - 1 <= 100:  # (StyLua's column width)
        return line
    lines = [f"\t{name} = {{\n", f"\t\tids = {{{ids}}},\n", f"\t\tvolume = {vol:g},\n",
             f"\t\tpitch = {pitch:g},\n", f"\t\tpitchVariation = {pv:g},\n"]
    lines += [f"\t\t{e},\n" for e in extra]
    lines.append("\t},\n")
    return "".join(lines)


def lua_sounds(existing_ids, measure):
    out = [BEGIN, LUA_HEADER_COMMENT]
    for cue in ALL_CUES:
        name = cue["name"]
        out.append(f"\t-- {name}: {cue.get('thing') or cue['fr']}\n")
        for index, layer in enumerate(layer_names(cue)):
            entry = entry_name(name, layer)
            spec = stock_layer(name, layer)
            loop = looped(name)
            extra = []
            if spec:
                vol, rows = mix(name, spec, measure)
                ids = " " + ", ".join(str(i) for i in spec.ids) + " "
                pitch = spec.pitch
                pv = 0 if loop else (spec.pv if spec.pv is not None else 0.06)
                if not loop and spec.vv:
                    extra.append(f"volumeVariation = {spec.vv:g}")
                if spec.length:
                    extra.append(f"length = {spec.length:g}")
                if spec.fade:
                    extra.append(f"fadeOut = {spec.fade:g}")
                trims = []
                for i, (start, gain, _, _) in rows.items():
                    fields = []
                    if start:
                        fields.append(f"start = {start:g}")
                    if gain != 1:
                        fields.append(f"gain = {gain:g}")
                    if fields:
                        trims.append(f"\t\t\t[{i}] = {{ {', '.join(fields)} }},\n")
                if trims:
                    extra.append("trims = {\n" + "".join(trims) + "\t\t}")
            else:
                ids = existing_ids.get(entry, "")
                vol = volume(cue, cue["layers"][index][5])
                pitch = 1
                pv = 0 if loop else (0.03 if layer in ("Sub", "Body") else 0.06)
            if loop:
                extra.append("looped = true")
            out.append(lua_entry(entry, ids, vol, pitch, pv, extra))
    out.append(END)
    return "".join(out)


def lua_cues(existing_ids):
    lines = [
        "--!strict\n",
        "-- Layered sounds: one cue = several Shared/Sounds entries played together, each\n",
        "-- starting `at` seconds after the cue (synced to the clip and the VFX). Played by\n",
        "-- Client/Combat/SoundLayers. Only the layers that have ids are listed.\n",
        "-- Generated by tools/sounds/pyro_sounds.py (edit there): the Pyromaniac's sounds,\n",
        "-- docs/SONS_PYROMANE_FR.md.\n",
        "\n",
        "export type Layer = { sound: string, at: number }\n",
        "export type Cue = { layers: { Layer }, looped: boolean }\n",
        "\n",
        "local cues: { [string]: Cue } = {\n",
    ]
    for cue in ALL_CUES:
        name = cue["name"]
        lines.append(f"\t{name} = {{\n")
        lines.append(f"\t\tlooped = {'true' if cue.get('looped') else 'false'},\n")
        lines.append("\t\tlayers = {\n")
        for index, layer in enumerate(layer_names(cue)):
            spec = stock_layer(name, layer)
            if spec:
                at = spec.at
            elif existing_ids.get(entry_name(name, layer), "").strip():
                at = cue["layers"][index][3] / 1000
            else:
                continue
            lines.append(f"\t\t\t{{ sound = \"{entry_name(name, layer)}\", at = {at:g} }},\n")
        lines.append("\t\t},\n")
        lines.append("\t},\n")
    lines.append("}\n\nreturn table.freeze(cues)\n")
    return "".join(lines)


def fmt(value, digits=1):
    if value is None:
        return "–"
    return f"{value:.{digits}f}".replace(".", ",").replace("-", "−")


def stock_doc(measure):
    o = ["## Les sons en place (boutique Roblox, mesurés)\n\n"]
    o.append(
        "Chaque son du Pyromane utilise des **effets sonores gratuits et publics** du *Creator Store* "
        "de Roblox, tous de **Pro Sound Effects** (`ProSoundEffects`, créateur vérifié : la bibliothèque "
        "sous licence que Roblox offre à toutes les expériences). Il n'y a **rien à faire** : Rojo "
        "synchronise, *Play*.\n\n"
        "**Comment ils ont été choisis.** Chaque candidat a été téléchargé et **mesuré** "
        "(`tools/sounds/ears.py`) : sonie (LUFS), crête, blanc au début, montée, brillance, part de "
        "2-5 kHz (ce qui « pique »), part de grave sous 150 Hz (inaudible sur téléphone), et pour les "
        "boucles la stabilité du niveau et la soudure fin → début. On garde ceux qui partent net, ne "
        "saturent pas et ne piquent pas, puis :\n\n"
        "- **le blanc au début est coupé** pour chaque fichier (`start`), et pour les sons calés sur un "
        "coup, le début est réglé pour que **le pic tombe sur l'image du coup** (« pic à +0,03 s ») ;\n"
        "- **chaque fichier est ramené au même niveau** que ses variantes (`gain`) : plus de variante "
        "12 dB plus forte qu'une autre ;\n"
        "- **chaque son a son niveau cible** (colonne *Cible*) : le briquet discret, le lancer moyen, "
        "le Molotov et l'embrasement les plus forts, les boucles en dessous ;\n"
        "- **2 à 4 variantes** pour les sons fréquents, jamais la même deux fois de suite, avec une "
        "petite variation de hauteur (± 3-8 %) et de volume (± 1,5 dB) ;\n"
        "- **les boucles** sont longues (36-56 s), stables, et passent d'un tour au suivant **en fondu "
        "enchaîné** (pas de clic) ; elles démarrent à un endroit au hasard et **entrent en fondu** "
        "pendant que l'explosion qui les lance s'éteint ;\n"
        "- tous les sons du Pyromane passent dans un **groupe de mix** (compresseur doux + aigus un "
        "peu baissés) : quand le verre, l'explosion, la flaque et les cris tombent ensemble, ça reste "
        "lisible et ça ne sature pas.\n\n"
        "Colonnes : *Durée* du fichier ; *I* sonie moyenne (LUFS) ; *Max* sonie maximale sur 0,4 s du "
        "morceau joué ; *Crête* (dBFS) ; *Blanc* coupé au début (s) ; *Montée* jusqu'au pic (s) ; "
        "*Brillance* (Hz) ; *2-5k* et *<150* les parts d'énergie ; *Gain* le volume propre au fichier ; "
        "*Niveau* final (Max + volume + gain). Pour une boucle, *Max* est remplacé par la stabilité "
        "(écart-type du niveau, dB) et la soudure (saut de niveau fin → début, dB).\n\n"
        "| Son | Couche | À | ID | Nom sur la boutique | Pourquoi | Durée | I | Max | Crête | Blanc | Montée "
        "| Brillance | 2-5k | <150 | Gain | Niveau | Cible | Réglage |\n"
        "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n"
    )
    for cue in ALL_CUES:
        name = cue["name"]
        loop = looped(name)
        cue_cell = f"[`{name}`](#{name.lower()})"
        for spec in STOCK.get(name, []):
            vol, rows = mix(name, spec, measure)
            setting = [f"`volume` {fmt(vol, 2)}"]
            if spec.pitch != 1:
                setting.append(f"`pitch` {fmt(spec.pitch, 2)}")
            if spec.length:
                setting.append(f"coupé à {fmt(spec.length, 2)} s")
            if spec.fade:
                setting.append(f"fondu {fmt(spec.fade, 2)} s")
            if isinstance(spec.start, str) and spec.start.startswith("peak-"):
                setting.append(f"pic à +{fmt(float(spec.start[5:]), 2)} s")
            layer_cell, at_cell = f"`_{spec.layer}`", f"{fmt(spec.at, 2)} s"
            setting_cell = ", ".join(setting)
            target = f"{fmt(spec.target, 0)} {'I' if loop else 'Max'}"
            for i, (start, gain, level, seg) in rows.items():
                whole = measure["files"][str(i)]
                d = measure["details"].get(str(i), {})
                title = d.get("name") or "?"
                final = level + 20 * math.log10(vol * gain)
                if loop:
                    mcell = f"σ {fmt(whole.get('stability'))} / soudure {fmt(whole.get('seam_dB'))}"
                else:
                    mcell = fmt(seg["Mmax"])
                o.append(
                    f"| {cue_cell} | {layer_cell} | {at_cell} | `{i}` | {title} | {WHY.get(i, '')} "
                    f"| {fmt(whole['dur'], 2)} s | {fmt(whole['I'])} | {mcell} | {fmt(whole['truePeak'])} "
                    f"| {fmt(start, 2)} | {fmt(seg['attack'], 2)} | {whole['centroid']} | {fmt(whole['harsh'], 2)} "
                    f"| {fmt(whole['sub'], 2)} | {fmt(gain, 2)} | {fmt(final)} | {target} | {setting_cell} |\n"
                )
                cue_cell, layer_cell, at_cell, setting_cell, target = "", "", "", "", ""
    o.append(
        "\n**Écartés après mesure** : *Zippo Lighter 2/4/6* (presque muets : un clic de 20 ms puis "
        "rien), *Fire Burst 2* et *11* (une montée lente : le pic arrive 1,3 s après la boule de feu), "
        "*Gas Fire Explosion 4* (un grondement plat et saturé, sans attaque), *Fire Whoosh 13* "
        "(9114442370 : trop de 2-5 kHz, il pique), *Fry Or Sizzle 1* (trop sifflant pour une boucle), "
        "les briquets à pipe (*Lighter Flicking…* : un briquet jetable puis quelqu'un qui aspire), et les "
        "boucles de la communauté utilisées avant (impossibles à télécharger sans compte, donc "
        "impossibles à vérifier).\n\n"
        "**Le lance-flammes** (depuis qu'il a remplacé le Zippo, les Molotov, le jerrican et la flasque "
        "dans les attaques) n'a demandé **aucun nouveau téléchargement** : ses sons sont faits des mêmes "
        "fichiers mesurés, coupés, montés ou descendus en hauteur (`pitch`) : *Fire Whoosh 6* (un vrai "
        "jet de lance-flammes) pour le jet et la lance du chalumeau, le levier du Zippo grave pour la "
        "gâchette et les vannes, le liquide qui part d'un coup monté d'une quinte pour le sifflement du "
        "détendeur, le grésillement qui retombe pour la veilleuse coupée et la soupape du finisher. "
        "Retirés du générateur car plus utilisés : *FlameFlare* (devenu *BurstPop*), *MolotovLight*, "
        "*MolotovShatter* (plus de verre : *GlobSplat*), *FuelSwig*, *FuelPour*, *CanThrow*, *ZippoDrop*, "
        "*CanSlosh* (devenu *GunDraw*).\n\n"
    )
    return "".join(o)


def doc(measure):
    o = []
    o.append("# Sons du Pyromane\n\n")
    o.append(
        "Chaque son du kit **Pyromane** (un *cue*) est fait de **une à cinq couches** jouées ensemble, "
        "chacune avec son propre son dans `src/shared/Sounds.luau` (section *Pyromaniac*, à la fin "
        "du fichier) et son moment de départ dans `src/shared/SoundCues.luau` (colonne *À*) :\n\n"
        "| Couche | Rôle |\n|---|---|\n"
        "| `_Transient` | l'attaque : le tout premier instant, sec et court |\n"
        "| `_Mechanism` | ce qui bouge : charnière, molette, liquide, verre |\n"
        "| `_Body` | le cœur du son, ce qu'on reconnaît |\n"
        "| `_Sub` | le grave, le poids (on le sent plus qu'on ne l'entend) |\n"
        "| `_Tail` | la fin qui s'éteint |\n\n"
        "Une couche dont les `ids` sont vides (`{}`) est **muette** (aucune erreur).\n\n"
    )
    o.append(stock_doc(measure))
    o.append(
        "## Changer un son\n\n"
        "1. Mets son ID dans `STOCK` (`tools/sounds/pyro_sounds.py`) avec un niveau *cible*.\n"
        "2. `python3 tools/sounds/pyro_sounds.py --measure --cache <dossier>` : télécharge et mesure "
        "(numpy + ffmpeg ; seuls les sons publics se téléchargent sans compte).\n"
        "3. `python3 tools/sounds/pyro_sounds.py --verify` : vérifie chaque ID sur la boutique.\n"
        "4. `python3 tools/sounds/pyro_sounds.py --write` puis `stylua src` : réécrit `Sounds.luau`, "
        "`SoundCues.luau` et ce document.\n\n"
        "## Plus tard (optionnel) : générer ses propres sons\n\n"
        "Pas nécessaire. Mais pour un son encore plus précis, chaque fiche plus bas donne un design en "
        "cinq couches et un **prompt** prêt à coller dans un générateur audio. Coupe le silence au "
        "début du fichier, fais boucler sans clic les sons marqués **BOUCLE**, importe-les (*Creator "
        "Hub → Creations → Audio → Upload*) et mets leurs IDs dans `STOCK`.\n\n"
    )
    o.append("## La liste\n\n| Son | Ce que c'est | Quand |\n|---|---|---|\n")
    for cue in ALL_CUES:
        loop = " **BOUCLE**" if cue.get("looped") else ""
        o.append(f"| [`{cue['name']}`](#{cue['name'].lower()}) | {cue['fr']}{loop} | {cue['when']} |\n")
    o.append("\n")
    for cue in ALL_CUES:
        o.append(f"## {cue['name']}\n\n")
        o.append(f"{cue['fr']} **Quand :** {cue['when']}")
        if cue.get("looped"):
            o.append(" C'est une **BOUCLE**.")
        o.append("\n\n")
        if "layers" not in cue:
            o.append("Pas de design en cinq couches : les couches en place sont dans le tableau plus haut.\n\n")
            continue
        o.append(f"> *Brief :* {BRIEF.format(thing=cue['thing'])}\n\n")
        o.append("### Les couches (design)\n\n")
        o.append("| Couche | Source | Hauteur (Hz) | Texture | Début | Durée |\n|---|---|---|---|---|---|\n")
        for layer, data in zip(LAYERS, cue["layers"]):
            src, pitch, texture, start, length, db, _ = data
            dur = "boucle" if cue.get("looped") else f"{length} ms"
            o.append(f"| {LAYERS_FR[layer]} | {src} | {pitch} | {texture} | {start} ms | {dur} |\n")
        o.append("\n### Les prompts (à coller)\n\n")
        for layer, data in zip(LAYERS, cue["layers"]):
            o.append(f"**`{entry_name(cue['name'], layer)}`**\n```\n{data[6]}\n```\n")
        o.append("\n")
    return "".join(o)


def write():
    measure = load_measure()
    path = "src/shared/Sounds.luau"
    text = open(path).read()
    existing = {}
    if BEGIN in text:
        start = text.index(BEGIN)
        end = text.index(END) + len(END)
        for match in re.finditer(r"\t(\w+) = \{\s*ids = \{([^}]*)\}", text[start:end]):
            existing[match.group(1)] = match.group(2)
        text = text[:start] + text[end:]
    block = lua_sounds(existing, measure)
    marker = "}\n\nreturn table.freeze(sounds)\n"
    assert marker in text
    text = text.replace(marker, "\n" + block + marker)
    text = text.replace("\n\n\n" + BEGIN, "\n\n" + BEGIN)
    open(path, "w").write(text)
    open("src/shared/SoundCues.luau", "w").write(lua_cues(existing))
    open("docs/SONS_PYROMANE_FR.md", "w").write(doc(measure))


if __name__ == "__main__":
    for cue in CUES:
        assert len(cue["layers"]) == 5, cue["name"]
    for name, specs in STOCK.items():
        looped(name)
        for spec in specs:
            for i in spec.ids:
                assert i in WHY, i
    if "--measure" in sys.argv:
        measure(sys.argv[sys.argv.index("--cache") + 1])
    if "--verify" in sys.argv:
        verify()
    if "--write" in sys.argv:
        write()
