"""도 상세 지도 좌표 ↔ 위경도 맞추기 → lib/features/korea_map/geo_projection.dart 의 값.

    curl -LO https://raw.githubusercontent.com/southkorea/southkorea-maps/master/kostat/2018/json/skorea-municipalities-2018-geo.json
    python3 tool/fit_geo_projection.py skorea-municipalities-2018-geo.json assets/maps/korea-map.json

시·군·구마다 앱 지도 경계와 원본 경계(위경도, 메르카토르 y)의 넓이 무게중심을 구해 도마다 1차식을 맞춘다.
- 어긋나면(1.5칸 넘게) 가장 먼 곳부터 뺀다(5곳 남을 때까지). 그래도 어긋나면 섬이 여러 조각인 곳(옮겨 그린 섬)을 빼고 다시.
- 시·군·구가 4곳 미만인 도(세종·제주)는 넓이 비로 축척, 무게중심으로 위치(가로·세로 축척 비는 다른 도의 가운데 값).
"""
import json
import math
import re
import sys

import numpy as np

MERC = lambda lat: math.log(math.tan(math.pi / 4 + math.radians(lat) / 2))


def svg_rings(d):
    rings, cur = [], []
    for cmd, x, y in re.findall(r"([MLZ])\s*(?:(-?[\d.]+)[ ,](-?[\d.]+))?", d):
        if cmd == "M":
            if cur:
                rings.append(cur)
            cur = [(float(x), float(y))]
        elif cmd == "L":
            cur.append((float(x), float(y)))
        elif cur:
            rings.append(cur)
            cur = []
    if cur:
        rings.append(cur)
    return rings


def centroid(rings):
    a = cx = cy = 0.0
    for r in rings:
        for (x0, y0), (x1, y1) in zip(r, r[1:] + r[:1]):
            c = x0 * y1 - x1 * y0
            a, cx, cy = a + c, cx + (x0 + x1) * c, cy + (y0 + y1) * c
    return cx / (3 * a), cy / (3 * a), abs(a) / 2


def geo_rings(geo):
    out = []
    for f in geo["features"]:
        g = f["geometry"]
        polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        rings = [[(lon, MERC(lat)) for lon, lat in ring] for poly in polys for ring in poly]
        out.append((f["properties"]["code"], f["properties"]["name"], rings))
    return out


def geo_for(geo, province, city):
    for code, _, rings in geo:
        if code == city["id"]:
            return rings
    # 합친 시(31:수원시 = 수원시장안구 + …)
    rings = [r for code, name, rs in geo if code[:2] == province and name.startswith(city["name"]) for r in rs]
    return rings or None


def fit(rows):
    a = np.array([[r["gx"], r["gy"], 1] for r in rows])
    ax = np.linalg.lstsq(a, np.array([r["sx"] for r in rows]), rcond=None)[0]
    ay = np.linalg.lstsq(a, np.array([r["sy"] for r in rows]), rcond=None)[0]
    res = [math.hypot(ax @ [r["gx"], r["gy"], 1] - r["sx"], ay @ [r["gx"], r["gy"], 1] - r["sy"]) for r in rows]
    return ax, ay, res


def main(geo_path, app_path):
    geo = geo_rings(json.load(open(geo_path)))
    app = json.load(open(app_path))
    rows_by = {}
    for code, p in app["provinces"].items():
        rows = []
        for c in p["cities"]:
            g = geo_for(geo, code, c)
            if not g:
                print("원본 경계 없음:", c["id"], c["name"], file=sys.stderr)
                continue
            rs = svg_rings(c["d"])
            sx, sy, sa = centroid(rs)
            gx, gy, ga = centroid(g)
            rows.append(dict(name=c["name"], pieces=len(rs), sx=sx, sy=sy, sa=sa, gx=gx, gy=gy, ga=ga))
        rows_by[code] = rows

    fits, ratios = {}, []
    for code, rows in rows_by.items():
        if len(rows) < 4:
            continue
        def trim(use):
            ax, ay, res = fit(use)
            while max(res) > 1.5 and len(use) > 5:
                use.pop(res.index(max(res)))
                ax, ay, res = fit(use)
            return use, ax, ay, res

        use, ax, ay, res = trim(list(rows))
        if max(res) > 1.5:
            use, ax, ay, res = trim([r for r in rows if r["pieces"] <= 2])
        left_out = [r["name"] for r in rows if r not in use]
        print(f"{code} {app['provinces'][code]['short']}: {len(use)}곳, 최대 {max(res):.2f}칸, 뺀 곳 {left_out}", file=sys.stderr)
        fits[code] = [float(v) for v in (*ax, *ay)]
        ratios.append(-ay[1] / ax[0])
    ratio = float(np.median(ratios))
    for code, rows in rows_by.items():
        if code in fits:
            continue
        a = math.sqrt(sum(r["sa"] for r in rows) / (ratio * sum(r["ga"] for r in rows)))
        c = float(np.mean([r["sx"] - a * r["gx"] for r in rows]))
        f = float(np.mean([r["sy"] + ratio * a * r["gy"] for r in rows]))
        fits[code] = [a, 0.0, c, 0.0, -ratio * a, f]
        print(f"{code} {app['provinces'][code]['short']}: 넓이 비로 맞춤", file=sys.stderr)
    for code in sorted(fits):
        vals = ", ".join(repr(round(v, 4)) for v in fits[code])
        print(f"  '{code}': [{vals}], // {app['provinces'][code]['short']}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
