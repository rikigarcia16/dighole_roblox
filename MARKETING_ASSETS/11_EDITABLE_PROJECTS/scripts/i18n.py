"""ES -> EN copy for every text drawn by the marketing scripts. Set THNE_LANG=en to render English."""
import os
LANG = os.environ.get("THNE_LANG", "es")
TR = {
    # shorts
    "CAVÉ 1.000 m\nEN MI JARDÍN": "I DUG 1,000 m\nIN MY BACKYARD", "1.000 m": "1,000 m", "+1.000 m": "+1,000 m",
    "¿QUÉ HAY DEBAJO\nDE TU CASA?": "WHAT'S UNDER\nYOUR HOUSE?", "MINAS": "MINES", "CRISTAL": "CRYSTAL", "EL ABISMO": "THE ABYSS",
    "HERRAMIENTA 1\nVS HERRAMIENTA 10": "TOOL 1\nVS TOOL 10", "PALAS": "SHOVELS", "PICOS": "PICKAXES", "TALADROS": "DRILLS",
    "POTENCIA 85": "POWER 85", "HERRAMIENTA 1\nVS 10": "TOOL 1\nVS 10",
    "EL MINERAL MÁS RARO\nDEL JUEGO": "THE RAREST ORE\nIN THE GAME", "¿CUÁNTO CREES\nQUE VALE?": "HOW MUCH DO YOU\nTHINK IT'S WORTH?",
    "EL MINERAL\nMÁS RARO": "THE RAREST\nORE", "PICAR CRISTAL\nA CÁMARA LENTA": "MINING CRYSTAL\nIN SLOW MOTION",
    "POV: HEREDAS UNA CASA\nCON JARDÍN…": "POV: YOU INHERIT A HOUSE\nWITH A BACKYARD…", "…Y UNA NOTA\nQUE DICE «CAVA»": "…AND A NOTE\nTHAT SAYS «DIG»",
    "ASÍ QUE CAVAS": "SO YOU DIG", "Y CAVAS…": "AND DIG…", "POV: HEREDAS\nUNA CASA…": "POV: YOU INHERIT\nA HOUSE…",
    "1. EL JARDÍN": "1. THE GARDEN", "2. MINAS OLVIDADAS": "2. FORGOTTEN MINES", "3. CUEVAS DE CRISTAL": "3. CRYSTAL CAVES",
    "4. CAVERNAS ANTIGUAS": "4. ANCIENT CAVERNS", "5. PROFUNDIDADES VOLCÁNICAS": "5. VOLCANIC DEPTHS", "6. EL ABISMO": "6. THE ABYSS",
    "650–1.000 m": "650–1,000 m", "1.000–1.500 m": "1,000–1,500 m", "1.500–2.200 m": "1,500–2,200 m",
    "LAS 7 CAPAS\nDEL AGUJERO": "THE 7 LAYERS\nOF THE HOLE", "TODO LO QUE CAVAS\nSE VENDE": "EVERYTHING YOU DIG\nCAN BE SOLD",
    "VENDE Y MEJORA": "SELL AND UPGRADE", "¡A VENDER!": "SELL IT ALL!", "NO MIRES ABAJO.": "DON'T LOOK DOWN.",
    "…DEMASIADO TARDE.": "…TOO LATE.", "NO MIRES\nABAJO.": "DON'T LOOK\nDOWN.", "ALGUIEN CAVÓ AQUÍ\nANTES QUE YO": "SOMEONE DUG HERE\nBEFORE ME",
    "¿QUIÉN ERA «E.»?": "WHO WAS «E.»?", "ALGUIEN CAVÓ\nAQUÍ ANTES": "SOMEONE DUG\nHERE BEFORE",
    "RETO: ¿A QUÉ PROFUNDIDAD\nESTOY?": "CHALLENGE: HOW DEEP\nAM I?", "¿CUÁNTOS ACERTASTE?": "HOW MANY DID YOU GET?",
    "¿A QUÉ\nPROFUNDIDAD?": "HOW\nDEEP?", "7 ZONAS": "7 ZONES", "2.200 METROS": "2,200 METERS", "10 HERRAMIENTAS": "10 TOOLS",
    "MINERALES Y HALLAZGOS": "ORES AND FINDS", "UN MISTERIO": "A MYSTERY", "SIN MASCOTAS\nNI RENACIMIENTOS": "NO PETS,\nNO REBIRTHS",
    "LLEVO MESES HACIENDO\nESTE JUEGO EN ROBLOX": "I'VE SPENT MONTHS MAKING\nTHIS ROBLOX GAME", "¿LO PROBARÍAS?": "WOULD YOU PLAY IT?",
    "LO HE HECHO\nYO": "I MADE\nTHIS", "A 1.000 METROS\nTODO BRILLA": "AT 1,000 METERS\nEVERYTHING GLOWS", "A 1.000 m\nTODO BRILLA": "AT 1,000 m\nIT ALL GLOWS",
    "CUANDO LA MOCHILA\nSE LLENA A 16 METROS…": "WHEN YOUR BACKPACK\nFILLS UP AT 16 METERS…", "…Y TOCA SUBIR A VENDER": "…AND IT'S BACK UP TO SELL",
    "MOCHILA\nLLENA…": "BACKPACK\nFULL…", "MUY PRONTO\nEN ROBLOX": "COMING SOON\nTO ROBLOX", "MUY PRONTO": "COMING SOON",
    "BÚSCALO EN ROBLOX": "FIND IT ON ROBLOX", "The Hole Never Ends\nEnlace en la bio": "The Hole Never Ends\nLink in bio",
    # ads
    "CAVA EN TU JARDÍN": "DIG IN YOUR BACKYARD", "CAVA. VENDE. MEJORA.": "DIG. SELL. UPGRADE.", "MINERALES\nRAROS": "RARE\nORES",
    "DE 0 A 2.200 m": "FROM 0 TO 2,200 m", "EXPLORA 7 ZONAS": "EXPLORE 7 ZONES", "¿QUIÉN CAVÓ AQUÍ ANTES?": "WHO DUG HERE BEFORE?",
    "MEJORA TU HERRAMIENTA": "UPGRADE YOUR TOOL", "1.100 m": "1,100 m",
    # social
    "Cava en tu jardín hasta el fondo del mundo.": "Dig from your backyard to the bottom of the world.",
    "HEREDAS UNA CASA": "YOU INHERIT A HOUSE", "…y una nota firmada por «E.» que dice: cava.": "…and a note signed «E.» that says: dig.",
    "Jardín · Minas · Cristal · Cavernas · Volcán · Abismo · ???": "Garden · Mines · Crystal · Caverns · Volcano · Abyss · ???",
    "De la pala oxidada a la perforadora abisal.": "From the rusty shovel to the abyss borer.", "HALLAZGOS": "FINDS",
    "Minerales, fósiles, geodas… y algún legendario.": "Ores, fossils, geodes… and the odd legendary.",
    "¿HASTA DÓNDE\nLLEGARÁS?": "HOW DEEP\nWILL YOU GO?", "GRATIS EN ROBLOX": "FREE ON ROBLOX", "Enlace en la bio": "Link in bio",
    "PREGUNTA\nRÁPIDA": "QUICK\nQUESTION", "LLEVO MESES CON\nESTO EN SECRETO…": "I'VE BEEN WORKING ON\nTHIS IN SECRET…",
    "¿CUÁL TE DAN MÁS\nGANAS DE JUGAR?": "WHICH ONE MAKES YOU\nWANT TO PLAY?", "BUSCO 50 PERSONAS\nDE 16+ PARA PROBARLO": "LOOKING FOR 50 PLAYERS\n16+ TO TEST IT",
    "SE ABRE\nEL AGUJERO": "THE HOLE\nOPENS SOON", "¡YA ESTÁ!\nGRATIS EN ROBLOX": "IT'S OUT!\nFREE ON ROBLOX",
    "¿A CUÁNTOS METROS\nHAS LLEGADO?": "HOW DEEP\nHAVE YOU GONE?", "Dímelo en comentarios": "Tell me in the comments",
    "CAPTURA DE\nLA SEMANA": "SCREENSHOT\nOF THE WEEK", "Etiqueta tus mejores capturas del juego": "Tag your best screenshots of the game",
    "¿EN QUÉ ZONA\nESTOY?": "WHICH ZONE\nAM I IN?", "Pista: hay setas que brillan": "Hint: the mushrooms glow",
    "¡NUEVO HALLAZGO!": "NEW FIND!", "HERRAMIENTA": "TOOL", "NOVEDAD": "NEW", "[ captura real aquí ]": "[ real screenshot here ]",
    "[ nombre · dato real ]": "[ name · real fact ]", "TRÁILER": "TRAILER", "CAVÉ 1.000 m": "I DUG 1,000 m",
    "LAS 7 CAPAS": "THE 7 LAYERS", "HICE UN JUEGO\nEN ROBLOX": "I MADE A\nROBLOX GAME",
}
MISSING = set()
SPANISH_HINTS = "ÁÉÍÓÚÑ¿¡áéíóúñ"


def tr(text):
    if LANG != "en" or not isinstance(text, str):
        return text
    if text in TR:
        return TR[text]
    if any(c in text for c in SPANISH_HINTS) or any(w in text.upper().split() for w in ("DE", "EL", "LA", "Y", "TU", "EN", "QUE", "CAVA")):
        MISSING.add(text)
    return text


def suffix(path):
    """Route English renders to an EN sibling folder."""
    return os.path.join(path, "EN") if LANG == "en" else path
