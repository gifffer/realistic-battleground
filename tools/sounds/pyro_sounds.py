"""The Pyromaniac's layered sounds: ONE source for three generated files.

Each sound of the kit (a "cue") is designed in five layers (transient,
mechanism, body, sub, tail), following the player's brief. This script
writes:
  * the Sounds.luau block (one entry per layer, ids = {} until the player
    gives them): printed between markers, pasted at the end of
    src/shared/Sounds.luau by --write;
  * src/shared/SoundCues.luau (which layers make a cue, when each starts);
  * docs/SONS_PYROMANE_FR.md (the design, the prompts to paste, the mix).

Run from the repo root:  python3 tools/sounds/pyro_sounds.py --write
"""

import re
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
        "when": "ZIPPO FLARE, MOLOTOV, FIRE BREATH, l'Awakening et le finisher, quand il ouvre le briquet.",
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
        "when": "Juste après ZippoOpen (ZIPPO FLARE, MOLOTOV, FIRE BREATH, Awakening, finisher).",
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
        "when": "À la fin de ZIPPO FLARE et de FIRE BREATH.",
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
        "name": "FlameFlare",
        "thing": "lighter fluid squirted through a lighter flame into someone's face, flaring into a burst of fire",
        "fr": "Le jet de liquide à briquet à travers la flamme : une boule de feu courte dans le visage.",
        "when": "ZIPPO FLARE, au moment du coup (0,42 s).",
        "gain": -1,
        "layers": [
            ("Le bidon de liquide pressé, le jet qui part", "2-8 kHz", "« tsst » sous pression", 0, 80, -4,
             "Short pressurized squirt of liquid from a small squeezed metal can, sharp tss sound, close-miked, dry, isolated, 0.15 seconds."),
            ("Le jet de liquide qui crépite en traversant la flamme", "1-9 kHz", "sifflement mouillé et crépitant", 20, 250, -6,
             "Hiss and spatter of a thin stream of lighter fluid spraying through a flame, wet sizzling crackle, isolated, 0.3 seconds."),
            ("Le liquide qui s'embrase d'un coup", "150 Hz-3 kHz", "« fwoosh » de flamme, rond et chaud", 50, 500, 0,
             "Sudden fwoosh of a burst of flame flaring up from sprayed fuel, warm roaring whoosh, medium size, no explosion, isolated, 0.6 seconds."),
            ("La bouffée d'air chaud", "40-120 Hz", "« whump » grave et mou", 50, 300, -10,
             "Soft deep whump of air pushed by a flame flaring up, low-frequency pressure puff, no crack, isolated, 0.3 seconds."),
            ("Les gouttes qui brûlent encore", "1-6 kHz", "petits crépitements et grésillements qui s'éteignent", 250, 900, -12,
             "Small burning droplets crackling and sizzling as they die out, sparse pops fading away, isolated, 1 second."),
        ],
    },
    {
        "name": "MolotovLight",
        "thing": "a petrol-soaked rag stuffed in a bottle neck being lit and catching fire",
        "fr": "Le chiffon imbibé d'essence au goulot qui prend feu.",
        "when": "MOLOTOV, quand le briquet touche le chiffon (0,3 s).",
        "gain": -3,
        "layers": [
            ("La flamme du briquet qui touche le tissu imbibé", "1-6 kHz", "petit « pff » sec", 0, 60, -6,
             "Tiny dry puff as a lighter flame touches a fuel-soaked cloth, short soft pop, isolated, 0.1 seconds."),
            ("Les fibres du coton qui s'enflamment", "2-10 kHz", "crépitement fin et sec", 20, 400, -6,
             "Fine crisp crackle of cotton fibres catching fire, dry tight crackling, close-miked, isolated, 0.5 seconds."),
            ("Le chiffon imbibé d'essence qui s'embrase", "150 Hz-2.5 kHz", "« whouf » chaud qui gonfle", 60, 500, 0,
             "Petrol-soaked rag bursting into flame, warm rising whoof of fire catching on fabric, medium-small, no explosion, isolated, 0.6 seconds."),
            ("La flamme qui monte", "40-120 Hz", "souffle grave doux", 60, 300, -14,
             "Soft low bloom of a flame rising, subtle low-frequency airy push, isolated, 0.3 seconds."),
            ("Le chiffon qui brûle en flottant", "300 Hz-4 kHz", "flamme de tissu qui flotte et crépite", 300, 1200, -9,
             "Small rag flame burning and fluttering on a bottle neck, soft roar with light crackle, steady, isolated, 1.2 seconds."),
        ],
    },
    {
        "name": "MolotovThrow",
        "thing": "a lit Molotov cocktail bottle being thrown overhand and flying past",
        "fr": "Le lancer : le bras, le liquide qui ballotte, la flamme du chiffon qui file dans l'air.",
        "when": "MOLOTOV et FIREBOMB, au lâcher de la bouteille.",
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
        "name": "MolotovShatter",
        "thing": "a glass Molotov bottle smashing on concrete and splashing petrol",
        "fr": "La bouteille qui éclate au sol : le verre, les éclats, l'essence qui gicle.",
        "when": "Quand le Molotov se brise (sol, mur ou sur quelqu'un).",
        "gain": 0,
        "layers": [
            ("Le verre épais qui casse à l'impact", "1-12 kHz", "« crack » de verre net et violent", 0, 60, 0,
             "Sharp loud crack of a thick glass bottle smashing on concrete, the first impact only, bright, close, dry, isolated one-shot, 0.1 seconds."),
            ("Les éclats qui se dispersent et tintent", "3-14 kHz", "pluie d'éclats de verre qui tintent et roulent", 20, 600, -5,
             "Shards of a broken glass bottle scattering and tinkling across a concrete floor, bright granular glass debris, isolated, 0.7 seconds."),
            ("L'essence qui gicle et claque au sol", "200 Hz-4 kHz", "éclaboussure de liquide mouillée", 15, 350, -3,
             "Wet splash of about a litre of liquid slapping onto concrete and spreading, splattering, isolated, 0.4 seconds."),
            ("Le choc sur le béton", "40-150 Hz", "« toum » sourd", 0, 150, -10,
             "Low dull thud of a heavy bottle hitting concrete, weight only, no glass, isolated, 0.2 seconds."),
            ("Les derniers éclats qui se posent, l'essence qui coule", "2-10 kHz", "petits tintements épars et gouttes", 300, 1200, -14,
             "Last few glass fragments settling with sparse tinkles, a little liquid trickling, quiet, isolated, 1.2 seconds."),
        ],
    },
    {
        "name": "FuelIgnite",
        "thing": "spilled petrol on the ground igniting into a fireball",
        "fr": "L'essence répandue qui s'embrase : la boule de feu.",
        "when": "Juste après MolotovShatter (la flaque prend feu).",
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
        "when": "Pendant tout le feu au sol du Molotov, en 3D sur la flaque, baisse quand le feu meurt.",
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
        "name": "FuelSwig",
        "thing": "a man taking a mouthful of fuel from a metal hip flask",
        "fr": "Il boit une gorgée d'essence (pour la cracher) : le bouchon, le liquide, la bouche pleine.",
        "when": "FIRE BREATH / INFERNO BREATH, au début.",
        "gain": -6,
        "layers": [
            ("Le bouchon métallique dévissé", "1-8 kHz", "petit clic de métal", 0, 60, -4,
             "Small metallic click of a hip flask screw cap being opened, close, dry, isolated, 0.1 seconds."),
            ("Le liquide qui coule dans le flacon de métal", "300 Hz-3 kHz", "glouglou métallique", 80, 350, -6,
             "Liquid glugging out of a small metal flask, hollow metallic glug, close, isolated, 0.4 seconds."),
            ("La bouche qui se remplit", "150 Hz-2 kHz", "gorgée humide, bouche fermée", 150, 400, 0,
             "A man filling his mouth with liquid and holding it, wet gulp with closed lips, no swallowing, close-miked, isolated, 0.4 seconds."),
            ("La gorge", "60-200 Hz", "résonance grave de la poitrine", 150, 300, -16,
             "Very subtle low throat and chest resonance of someone holding a mouthful, soft, isolated, 0.3 seconds."),
            ("Le souffle par le nez", "500 Hz-5 kHz", "expiration courte et tendue", 500, 400, -12,
             "Short tense exhale through the nose, breathy, close-miked, isolated, 0.4 seconds."),
        ],
    },
    {
        "name": "FireBreath",
        "thing": "a fire breather spitting atomised fuel through a lighter flame into a roaring jet of fire",
        "fr": "Le cracheur de feu : l'essence pulvérisée à travers la flamme, un jet de feu qui rugit.",
        "when": "FIRE BREATH (0,55 s → 1 s) et INFERNO BREATH (plus long).",
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
        "when": "DOUSE, au balancement du jerrican (0,42 s).",
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
        "when": "L'activation de l'Awakening (0,55 s).",
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
        "name": "FuelPour",
        "thing": "petrol being poured from a jerrycan over a body lying on the ground",
        "fr": "L'essence versée du jerrican sur le corps (finisher).",
        "when": "IMMOLATION, de 0,4 s à 1,45 s.",
        "gain": -2,
        "layers": [
            ("Le bouchon du jerrican qui saute", "500 Hz-6 kHz", "« clonk » métallique et « pop » d'air", 0, 120, -4,
             "Metal jerrycan cap being unclipped with a clonk and a little air pop, close, isolated, 0.2 seconds."),
            ("Les gloussements d'air dans le jerrican", "150 Hz-1.5 kHz", "glouglous creux, rythmés", 250, 1000, -6,
             "Rhythmic hollow glugging of air bubbles entering a metal jerrycan while it is poured, isolated, 1 second."),
            ("Le filet d'essence sur les vêtements et le corps", "200 Hz-6 kHz", "coulée continue, qui éclabousse", 250, 1050, 0,
             "Steady stream of liquid pouring onto clothes and a body lying on concrete, wet splashing pour, isolated, 1.1 seconds."),
            ("La résonance du bidon", "50-150 Hz", "« bloub » grave", 250, 1000, -14,
             "Low hollow resonance of a large metal can being emptied, soft bloub, sub only, isolated, 1 second."),
            ("Les dernières gouttes", "1-8 kHz", "gouttes qui tombent, filet qui s'arrête", 1150, 700, -12,
             "Last drips of liquid from a can spout landing on fabric and concrete, the stream stopping, isolated, 0.7 seconds."),
        ],
    },
    {
        "name": "CanThrow",
        "thing": "an almost empty metal jerrycan tossed aside onto a concrete floor",
        "fr": "Le jerrican vide jeté par terre (finisher).",
        "when": "IMMOLATION, à 1,6 s.",
        "gain": -4,
        "layers": [
            ("Le bidon qui frappe le béton", "300 Hz-6 kHz", "« klang » de tôle creuse", 300, 80, 0,
             "Hollow metal jerrycan hitting a concrete floor, loud klang of thin sheet metal, the impact only, isolated, 0.1 seconds."),
            ("La poignée et le bouchon qui cliquettent au rebond", "1-8 kHz", "cliquetis métalliques", 330, 300, -6,
             "Rattle of a metal handle and a dangling cap as a can bounces, small metallic clatter, isolated, 0.3 seconds."),
            ("La résonance du bidon vide", "200 Hz-2 kHz", "« bwong » creux qui sonne", 310, 600, -4,
             "Hollow ringing bwong of an empty metal jerrycan resonating after a hit, isolated, 0.6 seconds."),
            ("Le choc", "40-120 Hz", "« toum » sourd", 300, 120, -12,
             "Low dull thud of a light metal container landing, weight only, isolated, 0.1 seconds."),
            ("Le bidon qui glisse, le reste d'essence qui ballotte", "300 Hz-5 kHz", "frottement sur le sol, clapotis", 500, 700, -12,
             "Metal can skidding to a stop on concrete with a little liquid sloshing inside, isolated, 0.7 seconds."),
        ],
    },
    {
        "name": "ZippoDrop",
        "thing": "a lit Zippo lighter dropped onto a petrol-soaked body",
        "fr": "Le Zippo allumé lâché sur le corps (finisher).",
        "when": "IMMOLATION, à 2,8 s (il tombe, touche la poitrine à 3,05 s).",
        "gain": -6,
        "layers": [
            ("Le briquet qui touche la poitrine", "500 Hz-6 kHz", "petit choc de métal sur tissu mouillé", 250, 50, 0,
             "Small metal lighter landing on a wet jacket on a body, soft dull tap, isolated, 0.1 seconds."),
            ("Le couvercle qui cliquette", "2-8 kHz", "petit cliquetis", 255, 100, -6,
             "Tiny rattle of a lighter lid as it lands, light metallic tick, isolated, 0.1 seconds."),
            ("La flamme qui tombe", "300 Hz-3 kHz", "flamme qui flotte en chute", 0, 300, -6,
             "Small lighter flame fluttering as it falls through the air, brief soft whoosh, isolated, 0.3 seconds."),
            ("Le poids", "60-200 Hz", "« tup » mou", 250, 80, -14,
             "Very soft low thud of a small object on a body, subtle, isolated, 0.1 seconds."),
            ("La flamme qui lèche le tissu", "500 Hz-4 kHz", "petit sifflement avant l'embrasement", 280, 200, -10,
             "Tiny flame licking at a fuel-soaked fabric, a short rising hiss right before ignition, isolated, 0.2 seconds."),
        ],
    },
    {
        "name": "BodyIgnite",
        "thing": "a petrol-soaked person on the ground going up in flames",
        "fr": "Le corps imbibé qui s'embrase d'un coup (« whump »).",
        "when": "IMMOLATION, à 3,05 s.",
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

LUA_HEADER_COMMENT = """\t-- Pyromaniac (Shared/Kits/Pyromaniac) --------------------------------------------------
\t-- Every sound of the kit is FIVE layers played together (Shared/SoundCues: when each one
\t-- starts): _Transient, _Mechanism, _Body, _Sub, _Tail. Their volumes are the mix levels.
\t-- ids = {} until the player makes them (docs/SONS_PYROMANE_FR.md: the prompt of each).
\t-- Silent meanwhile. Generated by tools/sounds/pyro_sounds.py (edit there, then --write;
\t-- the ids already filled in here are kept).
"""
BEGIN = "\t-- >>> Pyromaniac sounds (generated)\n"
END = "\t-- <<< Pyromaniac sounds (generated)\n"


def volume(cue, db):
    return round(10 ** ((cue["gain"] + db) / 20), 2)


def entry_name(cue, layer):
    return f"{cue['name']}_{layer}"


def lua_sounds(existing_ids):
    out = [BEGIN, LUA_HEADER_COMMENT]
    for cue in CUES:
        out.append(f"\t-- {cue['name']}: {cue['thing']}\n")
        for layer, data in zip(LAYERS, cue["layers"]):
            name = entry_name(cue, layer)
            ids = existing_ids.get(name, "")
            vol = volume(cue, data[5])
            variation = 0 if cue.get("looped") else (0.03 if layer in ("Sub", "Body") else 0.06)
            looped = ", looped = true" if cue.get("looped") else ""
            out.append(
                f"\t{name} = {{ ids = {{{ids}}}, volume = {vol}, pitch = 1, pitchVariation = {variation}{looped} }},\n"
            )
    out.append(END)
    return "".join(out)


def lua_cues():
    lines = [
        "--!strict\n",
        "-- Layered sounds: one cue = several Shared/Sounds entries played together, each\n",
        "-- starting `at` seconds after the cue (its timing in the design). Played by\n",
        "-- Client/Combat/SoundLayers. A layer with no id yet is silent.\n",
        "-- Generated by tools/sounds/pyro_sounds.py (edit there): the Pyromaniac's sounds,\n",
        "-- docs/SONS_PYROMANE_FR.md.\n",
        "\n",
        "export type Layer = { sound: string, at: number }\n",
        "export type Cue = { layers: { Layer }, looped: boolean }\n",
        "\n",
        "local cues: { [string]: Cue } = {\n",
    ]
    for cue in CUES:
        lines.append(f"\t{cue['name']} = {{\n")
        lines.append(f"\t\tlooped = {'true' if cue.get('looped') else 'false'},\n")
        lines.append("\t\tlayers = {\n")
        for layer, data in zip(LAYERS, cue["layers"]):
            at = data[3] / 1000
            lines.append(f"\t\t\t{{ sound = \"{entry_name(cue, layer)}\", at = {at:g} }},\n")
        lines.append("\t\t},\n")
        lines.append("\t},\n")
    lines.append("}\n\nreturn table.freeze(cues)\n")
    return "".join(lines)


def doc():
    o = []
    o.append("# Sons du Pyromane (à générer)\n\n")
    o.append(
        "Chaque son du kit **Pyromane** est fait de **cinq couches** jouées ensemble, chacune avec "
        "son propre son dans `src/shared/Sounds.luau` (section *Pyromaniac*, à la fin du fichier) :\n\n"
        "| Couche | Rôle |\n|---|---|\n"
        "| `_Transient` | l'attaque : le tout premier instant, sec et court |\n"
        "| `_Mechanism` | ce qui bouge : charnière, molette, liquide, verre |\n"
        "| `_Body` | le cœur du son, ce qu'on reconnaît |\n"
        "| `_Sub` | le grave, le poids (on le sent plus qu'on ne l'entend) |\n"
        "| `_Tail` | la fin qui s'éteint |\n\n"
        "Tant que les `ids` d'une couche sont vides (`{}`), elle est **muette** (aucune erreur). Le jeu "
        "joue déjà toutes les couches **au bon moment** (colonne *Début*) et au **bon volume** (le "
        "*mix* ci-dessous, déjà mis dans `volume`).\n\n"
        "## Comment faire\n"
        "1. Pour chaque son, copie le **prompt** de chaque couche (en anglais) dans ton générateur "
        "audio. Un fichier par couche.\n"
        "2. Coupe le silence au début du fichier (sinon la couche arrive en retard).\n"
        "3. Les sons marqués **BOUCLE** doivent boucler sans clic : coupe-les sur un passage à zéro et "
        "fais un fondu enchaîné début / fin.\n"
        "4. Importe-les (*Creator Hub → Creations → Audio → Upload*), copie chaque ID et mets-le dans "
        "`ids` de la bonne entrée, par exemple :\n\n"
        "```lua\nZippoOpen_Transient = { ids = { 1234567890 }, volume = 0.63, pitch = 1, pitchVariation = 0.06 },\n```\n\n"
        "5. Rojo synchronise, *Play*. Si une couche est trop forte ou faible, change seulement son "
        "`volume`.\n\n"
        "> Le texte de départ de chaque fiche est exactement ta demande (le *brief*) ; la suite en est "
        "la réponse. Ces fichiers (`Sounds.luau` section Pyromane, `SoundCues.luau`, ce document) sont "
        "générés par `tools/sounds/pyro_sounds.py` : pour changer un design, change-le là puis lance "
        "`python3 tools/sounds/pyro_sounds.py --write` (les IDs déjà remplis sont gardés).\n\n"
    )
    o.append("## La liste\n\n| Son | Ce que c'est | Quand |\n|---|---|---|\n")
    for cue in CUES:
        loop = " **BOUCLE**" if cue.get("looped") else ""
        o.append(f"| [`{cue['name']}`](#{cue['name'].lower()}) | {cue['fr']}{loop} | {cue['when']} |\n")
    o.append("\n")
    for cue in CUES:
        o.append(f"## {cue['name']}\n\n")
        o.append(f"{cue['fr']} **Quand :** {cue['when']}")
        if cue.get("looped"):
            o.append(" C'est une **BOUCLE** : toutes les couches bouclent ensemble (le *Début* est 0).")
        o.append("\n\n")
        o.append(f"> *Brief :* {BRIEF.format(thing=cue['thing'])}\n\n")
        o.append("### Les couches\n\n")
        o.append("| Couche | Source | Hauteur (Hz) | Texture | Début | Durée |\n|---|---|---|---|---|---|\n")
        for layer, data in zip(LAYERS, cue["layers"]):
            src, pitch, texture, start, length, db, _ = data
            dur = "boucle" if cue.get("looped") else f"{length} ms"
            o.append(f"| {LAYERS_FR[layer]} | {src} | {pitch} | {texture} | {start} ms | {dur} |\n")
        o.append("\n### Les prompts (à coller)\n\n")
        for layer, data in zip(LAYERS, cue["layers"]):
            o.append(f"**`{entry_name(cue, layer)}`**\n```\n{data[6]}\n```\n")
        o.append("\n### Le mix\n\n| Couche | Niveau | `volume` |\n|---|---|---|\n")
        for layer, data in zip(LAYERS, cue["layers"]):
            o.append(f"| `{entry_name(cue, layer)}` | {cue['gain'] + data[5]:+d} dB | {volume(cue, data[5])} |\n")
        o.append(
            f"\nLe son entier est à {cue['gain']:+d} dB ; chaque couche est réglée par rapport à la plus forte du son (0 dB). "
            "Le *Sub* reste bas : il doit donner du poids, pas du bruit.\n\n"
        )
    return "".join(o)


def write():
    path = "src/shared/Sounds.luau"
    text = open(path).read()
    existing = {}
    if BEGIN in text:
        start = text.index(BEGIN)
        end = text.index(END) + len(END)
        for match in re.finditer(r"\t(\w+) = \{ ids = \{([^}]*)\}", text[start:end]):
            existing[match.group(1)] = match.group(2)
        text = text[:start] + text[end:]
    block = lua_sounds(existing)
    marker = "}\n\nreturn table.freeze(sounds)\n"
    assert marker in text
    text = text.replace(marker, "\n" + block + marker)
    text = text.replace("\n\n\n" + BEGIN, "\n\n" + BEGIN)
    open(path, "w").write(text)
    open("src/shared/SoundCues.luau", "w").write(lua_cues())
    open("docs/SONS_PYROMANE_FR.md", "w").write(doc())


if __name__ == "__main__":
    for cue in CUES:
        assert len(cue["layers"]) == 5, cue["name"]
    if "--write" in sys.argv:
        write()
    else:
        print(lua_sounds({}))
