# -*- coding: utf-8 -*-
"""Option D / E2 demo architecture with Exchange Server SE on the OTP lane.

Built with Azure icons from the verified allow-list at
  ~/.scout/m-skills/azure-drawio-waf-pack/references/icons.md
Never invent an icon path - every path below is copied from that index.

Shows the TARGET state of the lab: Exchange SE Edge Transport is the front door
for the OTP lane, Postfix remains the front door for the bulk lane. The two
front doors exist because Exchange cannot select an outbound connector by
sender address, which is a verified Exchange Server limitation.
"""
import os

OUT = os.path.dirname(os.path.abspath(__file__))
NAME = "priority_email_relay"

# ---- verified icon paths (azure2 library) -----------------------------------
I = {
    "vm":       "img/lib/azure2/compute/Virtual_Machine.svg",
    "caenv":    "img/lib/azure2/other/Container_App_Environments.svg",
    "worker":   "img/lib/azure2/other/Worker_Container_App.svg",
    "acr":      "img/lib/azure2/containers/Container_Registries.svg",
    "sbus":     "img/lib/azure2/integration/Service_Bus.svg",
    "storage":  "img/lib/azure2/storage/Storage_Accounts.svg",
    "redis":    "img/lib/azure2/databases/Azure_Managed_Redis.svg",
    "acs":      "img/lib/azure2/other/Azure_Communication_Services.svg",
    "bastion":  "img/lib/azure2/networking/Bastions.svg",
    "nat":      "img/lib/azure2/networking/NAT.svg",
    "vnet":     "img/lib/azure2/networking/Virtual_Networks.svg",
    "pe":       "img/lib/azure2/networking/Private_Endpoint.svg",
    "law":      "img/lib/azure2/analytics/Log_Analytics_Workspaces.svg",
    "mi":       "img/lib/azure2/identity/Managed_Identities.svg",
    "wb":       "img/lib/azure2/analytics/Azure_Workbooks.svg",
}

OTP_C, BULK_C, NEU_C, GREEN = "#C2404A", "#0857C3", "#44566B", "#15803D"

cells = []


def esc(s):
    """Escape a draw.io label for an XML attribute.

    draw.io renders HTML inside the value attribute, but the attribute itself must
    be valid XML - so <b> has to arrive as &lt;b&gt;. Numeric character references
    like &#183; are already valid and must survive untouched.
    """
    import re
    keep = []

    def stash(m):
        keep.append(m.group(0))
        return "\x00%d\x00" % (len(keep) - 1)

    s = re.sub(r"&#\d+;|&nbsp;|&amp;|&lt;|&gt;|&quot;", stash, s)
    s = s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")
    return re.sub(r"\x00(\d+)\x00", lambda m: keep[int(m.group(1))], s)


def band(cid, x, y, w, h, stroke, fill, title, sub):
    cells.append(
        '<mxCell id="%s" value="" style="rounded=1;whiteSpace=wrap;html=1;fillColor=%s;'
        'strokeColor=%s;strokeWidth=1.5;arcSize=2;" vertex="1" parent="1">'
        '<mxGeometry x="%d" y="%d" width="%d" height="%d" as="geometry"/></mxCell>'
        % (cid, fill, stroke, x, y, w, h))
    text(cid + "_t", title, x + 14, y + 8, 320, 18, 11, stroke, bold=True)
    text(cid + "_s", sub, x + 14, y + 27, 340, 16, 8.5, stroke)


def icon(cid, key, label, x, y, w=54, h=54):
    cells.append(
        '<mxCell id="%s" value="%s" style="sketch=0;points=[[0.5,0,0],[1,0.5,0],[0.5,1,0],[0,0.5,0]];'
        'outlineConnect=0;fontColor=#233A51;gradientColor=none;fillColor=#0078D4;strokeColor=none;'
        'shape=image;html=1;verticalLabelPosition=bottom;verticalAlign=top;align=center;'
        'imageAspect=0;aspect=fixed;fontSize=9;image=%s;" vertex="1" parent="1">'
        '<mxGeometry x="%d" y="%d" width="%d" height="%d" as="geometry"/></mxCell>'
        % (cid, esc(label), I[key], x, y, w, h))


def text(cid, s, x, y, w, h, fs=9, color="#233A51", bold=False, align="left"):
    cells.append(
        '<mxCell id="%s" value="%s" style="text;html=1;strokeColor=none;fillColor=none;'
        'align=%s;verticalAlign=top;whiteSpace=wrap;fontSize=%s;fontColor=%s;%s" '
        'vertex="1" parent="1"><mxGeometry x="%d" y="%d" width="%d" height="%d" as="geometry"/>'
        '</mxCell>' % (cid, esc(s), align, fs, color, "fontStyle=1;" if bold else "", x, y, w, h))


def note(cid, s, x, y, w, h, stroke, fill, fs=8.5):
    cells.append(
        '<mxCell id="%s" value="%s" style="rounded=1;whiteSpace=wrap;html=1;fillColor=%s;'
        'strokeColor=%s;strokeWidth=1;arcSize=8;align=left;verticalAlign=middle;fontSize=%s;'
        'fontColor=#233A51;spacingLeft=8;spacingRight=8;" vertex="1" parent="1">'
        '<mxGeometry x="%d" y="%d" width="%d" height="%d" as="geometry"/></mxCell>'
        % (cid, esc(s), fill, stroke, fs, x, y, w, h))


def edge(cid, src, dst, label="", color=NEU_C, dashed=False,
         ex=None, ey=None, nx=None, ny=None, lx=None):
    style = ('edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=%s;strokeWidth=1.6;'
             'fontSize=8;fontColor=%s;endArrow=block;endFill=1;endSize=6;labelBackgroundColor=#FFFFFF;'
             % (color, color))
    if dashed:
        style += "dashed=1;dashPattern=4 4;"
    if ex is not None:
        style += "exitX=%s;exitY=%s;exitDx=0;exitDy=0;" % (ex, ey)
    if nx is not None:
        style += "entryX=%s;entryY=%s;entryDx=0;entryDy=0;" % (nx, ny)
    geo = ('<mxGeometry relative="1" x="%s" as="geometry"/>' % lx) if lx is not None \
        else '<mxGeometry relative="1" as="geometry"/>'
    cells.append(
        '<mxCell id="%s" value="%s" style="%s" edge="1" parent="1" source="%s" target="%s">'
        '%s</mxCell>' % (cid, esc(label), style, src, dst, geo))


def step(cid, n, x, y):
    cells.append(
        '<mxCell id="%s" value="%s" style="ellipse;whiteSpace=wrap;html=1;fillColor=#233A51;'
        'strokeColor=none;fontColor=#FFFFFF;fontSize=9;fontStyle=1;" vertex="1" parent="1">'
        '<mxGeometry x="%d" y="%d" width="20" height="20" as="geometry"/></mxCell>' % (cid, n, x, y))


def build():
    W = 1840

    # ---------------- title
    text("title", "Priority Email Relay &#8212; Demo Environment with Exchange Server SE on the OTP Lane",
         40, 22, 1500, 24, 15, "#073372", bold=True)
    text("sub",
         "Resource group rg-relay-demo, Indonesia Central. ACS is a global resource with an "
         "Asia Pacific data location. Two SMTP front doors exist because Exchange Server cannot "
         "choose an outbound connector by sender address.",
         40, 46, 1500, 30, 9, "#627D92")

    # ================= OTP LANE =================
    band("lane_otp", 30, 92, W - 60, 252, OTP_C, "#FDF7F7",
         "OTP FAST PATH &#183; Exchange Server SE",
         "sender otp@notify.example.com &#183; never queued &#183; own ACS resource")

    note("otp_gap",
         "<b>NOTHING BETWEEN THEM &#8212; THAT IS THE POINT.</b> The OTP is relayed straight out. "
         "No blob write, no queue, no worker, no rate governor. Nothing can hold it up.",
         620, 100, 560, 46, OTP_C, "#FBE9E9")

    icon("otp_app", "vm", "vm-app 10.30.3.4\nsend-otp.sh", 90, 172)
    icon("otp_exch", "vm", "vm-exch 10.30.5.4\nExchange SE &#183; Edge Transport", 380, 172)
    icon("otp_acs", "acs", "acs-priority\nEmail", 1240, 172)
    text("otp_dest", "&#9993;&#160;Recipient mailbox", 1520, 190, 220, 20, 10, OTP_C, bold=True)

    edge("e1", "otp_app", "otp_exch", "SMTP 25")
    edge("e2", "otp_exch", "otp_acs", "SMTP 587 &#183; TLS &#183; basic auth", OTP_C)
    step("s1", "1", 300, 189)
    step("s2", "2", 1180, 189)

    note("otp_conn",
         "<b>Send connector</b> &#183; SmartHosts smtp.azurecomm.net &#183; Port 587 &#183; "
         "SmartHostAuthMechanism BasicAuthRequireTLS &#183; RequireTLS true &#183; "
         "DNSRoutingEnabled false",
         90, 280, 900, 46, OTP_C, "#FFFFFF")

    # ================= BULK LANE =================
    band("lane_bulk", 30, 362, W - 60, 336, BULK_C, "#F5F8FE",
         "BULK ASYNC PATH &#183; Postfix front door",
         "sender campaign@notify.example.com &#183; claim-check &#183; paced &#183; separate ACS resource")

    icon("b_app", "vm", "vm-app 10.30.3.4\nsend-bulk.sh", 90, 452)
    icon("b_pf", "vm", "vm-postfix 10.30.1.4\nPostfix &#183; pipe transport", 340, 452)
    icon("b_ing", "caenv", "ca-ingest\nclaim-check writer", 610, 452)
    icon("b_blob", "storage", "strelaydemo&#8230;\nBlob &#183; payload", 860, 392)
    icon("b_sb", "sbus", "sb-relay-demo\nq-bulk &#183; pointer only", 860, 542)
    icon("b_worker", "worker", "ca-worker\nKEDA 0&#8594;10", 1140, 452)
    icon("b_redis", "redis", "redis-relay-demo\ntoken bucket", 1290, 560)
    icon("b_acs", "acs", "acs-bulk\nEmail", 1400, 452)
    text("b_dest", "&#9993;&#160;Recipient mailbox", 1580, 470, 220, 20, 10, BULK_C, bold=True)

    edge("e3", "b_app", "b_pf", "SMTP 25")
    edge("e4", "b_pf", "b_ing", "HTTPS")
    edge("e5", "b_ing", "b_blob", "payload", BULK_C, ex=0.5, ey=0, nx=0, ny=0.5)
    edge("e6", "b_ing", "b_sb", "pointer", BULK_C, ex=0.5, ey=1, nx=0, ny=0.5)
    edge("e7", "b_sb", "b_worker", "dequeue", BULK_C, ex=1, ey=0.5, nx=0.5, ny=1)
    edge("e8", "b_worker", "b_blob", "fetch payload", NEU_C, dashed=True,
         ex=0.5, ey=0, nx=1, ny=0.5)
    edge("e9", "b_redis", "b_worker", "take token", GREEN, dashed=True,
         ex=0, ey=0.5, nx=1, ny=0.5)
    edge("e10", "b_worker", "b_acs", "REST + HMAC", BULK_C)
    step("s3", "3", 290, 469)
    step("s4", "4", 560, 469)
    step("s5", "5", 1092, 469)
    step("s6", "6", 1350, 469)

    note("bulk_note",
         "<b>Why the payload never rides the queue.</b> A typical message here is several hundred KB, which "
         "exceeds the Service Bus Standard limit of 256 KB. The blob holds the message and the "
         "queue holds only a pointer &#8212; the claim-check pattern.",
         90, 636, 700, 46, BULK_C, "#FFFFFF")

    note("bulk_note2",
         "<b>The rate governor is the whole point.</b> Every worker replica draws from one shared "
         "Redis bucket, so the pool can never outrun the ACS quota however many replicas KEDA starts.",
         830, 636, 640, 46, GREEN, "#F1FAF4")

    # ================= PLATFORM =================
    band("lane_plat", 30, 716, W - 60, 226, NEU_C, "#F7F9FB",
         "SHARED PLATFORM",
         "network, identity, build and telemetry &#183; used by both lanes")

    px = [90, 300, 510, 720, 930, 1140, 1350, 1560]
    icon("p_vnet", "vnet", "vnet-relay-demo\n10.30.0.0/16", px[0], 778)
    icon("p_bast", "bastion", "bastion-relay-demo\nRDP + SSH", px[1], 778)
    icon("p_nat", "nat", "nat-relay-demo\negress for relays", px[2], 778)
    icon("p_pe", "pe", "pe-blob\nprivate endpoint", px[3], 778)
    icon("p_mi", "mi", "id-relay-demo\nmanaged identity", px[4], 778)
    icon("p_acr", "acr", "acrrelaydemo&#8230;\nSoutheast Asia", px[5], 778)
    icon("p_law", "law", "law-relay-demo\nACS email logs", px[6], 778)
    icon("p_wb", "wb", "Email Insights\ndelivery analytics", px[7], 778)

    note("exch_note",
         "<b>Why two front doors?</b> Exchange Server selects an outbound connector by recipient "
         "address space and cost &#8212; never by sender. RouteMessageOutboundConnector is Exchange "
         "Online only, so splitting by sender needs one Exchange server per lane. That is exactly "
         "how the customer already works: relay-bulk.example.com and relay-priority.example.com are different hosts.",
         90, 878, 880, 52, OTP_C, "#FDF7F7")

    note("plat_note",
         "<b>Two honest notes.</b> The container registry sits in Southeast Asia because ACR Tasks "
         "are not available in Indonesia Central. Storage is private-endpoint only because tenant "
         "policy forces it &#8212; which is closer to what a bank would build anyway.",
         1010, 878, 760, 52, NEU_C, "#FFFFFF")

    # ---------------- assemble
    xml = ('<mxfile host="app.diagrams.net" type="device">'
           '<diagram id="%s" name="Option D + Exchange SE">'
           '<mxGraphModel dx="1600" dy="900" grid="0" gridSize="10" guides="1" tooltips="1" '
           'connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="%d" pageHeight="970" '
           'math="0" shadow="0" background="#FFFFFF">'
           '<root><mxCell id="0"/><mxCell id="1" parent="0"/>%s</root>'
           '</mxGraphModel></diagram></mxfile>'
           % (NAME, W, "".join(cells)))

    path = os.path.join(OUT, NAME + ".drawio")
    with open(path, "w", encoding="utf-8") as f:
        f.write(xml)
    print("WROTE", path)
    print("cells:", len(cells))


if __name__ == "__main__":
    build()
