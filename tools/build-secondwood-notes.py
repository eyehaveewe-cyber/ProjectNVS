"""Append or update the second-level record while retaining earlier DOCX edits.

Use the Codex primary Python runtime. The existing woodland addendum is the
input and output; this tool replaces only its own final milestone section.
Native results are included only when both matching reports say they passed.
"""
import json
from pathlib import Path

from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "ProjectNVS_Woodland_Expansion.docx"
APPENDIX = "The Returning Wood second level"


def proof(name):
    path = ROOT / "docs" / name
    if not path.exists():
        return None
    value = json.loads(path.read_text())
    if value.get("status") != "passed" or value.get("failures"):
        return None
    return value


progression = proof("secondwood-progression-verification.json")
traversal = proof("secondwood-traversal-verification.json")
doc = Document(OUTPUT)
if float(doc.core_properties.version or "0") > 0.4:
    raise SystemExit("A later design revision exists. Preserve its planning and human edits.")
for paragraph in list(doc.paragraphs):
    if paragraph.text == APPENDIX:
        element = paragraph._p
        while element is not None and element.tag != qn("w:sectPr"):
            following = element.getnext()
            element.getparent().remove(element)
            element = following
        break
for paragraph in doc.paragraphs:
    if paragraph.style.name == "Subtitle" and paragraph.text.startswith("Design addendum "):
        paragraph.text = "Design addendum 0.4  |  28 October 2026  |  Director Jonathan Sanders"
    elif paragraph.text == "Current verification and limits":
        paragraph.text = "Far woodland verification and limits"
for section in doc.sections:
    for paragraph in section.footer.paragraphs:
        for run in paragraph.runs:
            run.text = run.text.replace("27 October 2026", "28 October 2026")
doc.core_properties.version = "0.4"
doc.core_properties.subject = "Woodland expansion and second-level design record"


def p(text):
    return doc.add_paragraph(text)


def h(text, level=2):
    return doc.add_heading(text, level=level)


def table(headers, rows, widths):
    t = doc.add_table(rows=1, cols=len(headers))
    t.autofit = False
    for i, width in enumerate(widths):
        t.columns[i].width = Inches(width)
        t.rows[0].cells[i].text = headers[i]
    for row in rows:
        cells = t.add_row().cells
        for i, text in enumerate(row):
            cells[i].text = str(text)
    borders = OxmlElement("w:tblBorders")
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        border = OxmlElement(f"w:{edge}")
        for key, val in (("val", "single"), ("sz", "4"), ("color", "D9D9D9")):
            border.set(qn(f"w:{key}"), val)
        borders.append(border)
    t._tbl.tblPr.append(borders)
    repeat = OxmlElement("w:tblHeader")
    t.rows[0]._tr.get_or_add_trPr().append(repeat)
    for ri, row in enumerate(t.rows):
        for ci, cell in enumerate(row.cells):
            cell.width = Inches(widths[ci])
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            properties = cell._tc.get_or_add_tcPr()
            margins = OxmlElement("w:tcMar")
            for edge in ("top", "left", "bottom", "right"):
                margin = OxmlElement(f"w:{edge}")
                margin.set(qn("w:w"), "85")
                margin.set(qn("w:type"), "dxa")
                margins.append(margin)
            properties.append(margins)
            shade = OxmlElement("w:shd")
            shade.set(qn("w:fill"), "39443F" if ri == 0 else "F2F5F4" if ri % 2 == 0 else "FFFFFF")
            properties.append(shade)
            for paragraph in cell.paragraphs:
                paragraph.paragraph_format.space_after = Pt(2)
                paragraph.paragraph_format.line_spacing = 1.03
                for run in paragraph.runs:
                    run.font.size = Pt(9.3)
                    if ri == 0:
                        run.bold = True
                        run.font.color.rgb = RGBColor(255, 255, 255)
    return t


heading = h(APPENDIX, 1)
heading.paragraph_format.page_break_before = True
p("H008 is the director's approved request of 28 October 2026 for a startup level selector and a second level with long branching, curling paths, unlockable shortcuts and returns to earlier objectives with items that heal the land. The Returning Wood title, tool names, healing recipes and exact gates are AI implementation choices within that request. No further mythology or Artemis storyline is adopted here.")

h("Choose and keep each journey")
p("Startup offers Begin and, when a save exists, Continue for each level. Replacing an existing journey requires a second click for that level. Pause can return to the selector. The Quiet Bloom keeps journey.json; The Returning Wood keeps secondwood.json. Their positions and progress remain independent. The second level reuses the native faun, keyboard, pipe audio and woodland cast, with its own route map and quest state.")

h("Find tools and revisit the wounds")
route_length = float(traversal["total_authored_length"]) if traversal is not None else 1068.86109828949
p(f"A turning glade branches into western and eastern curls. The three damaged places are visible near the hub before their tools are found. Eight authored paths and three shortcuts occupy a bordered corridor network inside 180 by 180 unit bounds; their combined centerline length is {route_length:,.2f} units. Banks and blocked roots describe the routes, while native walkability prevents crossing locked ground.")
table(["Reusable tool", "Find it", "Return and heal", "Route change"], [
    ("Spring Vessel", "Western curl", "The Dry Source", "Western shortcut and northern spiral open"),
    ("Living Spore", "Eastern curl", "The Sealed Hollow", "Eastern shortcut opens"),
    ("Rootheart Spindle", "Northern spiral after the source heals", "The Ash Scar", "Northern shortcut opens"),
], [1.30, 1.62, 1.62, 2.42])
first_after_table = p("Approach a tool to collect it, then lower the pipes and press E near its matching wound. For example, find the vessel along the western curl, carry it back to the dry source, then follow the newly opened northern walk. Interacting without the needed tool explains what is missing and leaves progress intact. Tools remain in the inventory after use. Returning water, small growth, particles and woodland residents show recovery.")
first_after_table.paragraph_format.space_before = Pt(6)
p("The final route opens after all three healings. At the Joined Grove, raise the pipes with Tab and play Q E U I U E Q in any octave. The journal shows inventory, places to revisit and a map with open and closed routes. The MBean1 keyboard remains freely playable.")

h("Verification and the next playtest")
if progression is not None and traversal is not None:
    p(f"Native progression passes {len(progression['checks'])} checks and walks {float(progression['walked_distance']):,.2f} units through the quest with no spatial relocation. Healing and the finale use physical keyboard events; disk saves, Continue and selection are exercised. Traversal passes {len(traversal['checks'])} checks across {int(traversal['centerline_samples']):,} centerline samples and full-floor gate reachability. All eleven route sections are walked outward and back over {float(traversal['walked_distance']):,.2f} units, using eleven starting relocations. Evidence is in secondwood-progression-verification.json and secondwood-traversal-verification.json.")
else:
    p("Implementation is present in the native project. The second-level progression and traversal reports have not both passed yet, so verification remains pending in this revision. No completion claim is inferred from the route data alone.")
p("Human playtesting still needs to assess first-time route reading, whether the first long returns feel worthwhile, and whether shortcuts make later visits easier. Target-hardware performance is unmeasured. The note highway, Artemis' human form and the wider mythological conflict remain deferred. S5 is the director's 28 October request; revision 0.4 preserves the earlier pages and adds H008 and this scoped implementation record.")

doc.save(OUTPUT)
print(OUTPUT)
