#!/usr/bin/env python3
"""Plot China map from the county shapefile (no geopandas required)."""

from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import shapefile


def main() -> None:
    base = Path(
        "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
    )
    shp_path = base / "data/raw/China_Map/County0010/Data/County0010.shp"
    out_path = base / "result/figure/china_map_county_outline.png"
    out_path.parent.mkdir(parents=True, exist_ok=True)

    sf = shapefile.Reader(str(shp_path), encoding="utf-8")

    fig, ax = plt.subplots(figsize=(10, 8), dpi=300)

    for shp in sf.shapes():
        pts = shp.points
        parts = list(shp.parts) + [len(pts)]
        for i in range(len(parts) - 1):
            seg = pts[parts[i] : parts[i + 1]]
            if not seg:
                continue
            xs = [p[0] for p in seg]
            ys = [p[1] for p in seg]
            ax.plot(xs, ys, color="#1f1f1f", linewidth=0.15)

    ax.set_aspect("equal", adjustable="box")
    ax.set_axis_off()
    fig.tight_layout(pad=0)
    fig.savefig(out_path, bbox_inches="tight", pad_inches=0.02, facecolor="white")
    plt.close(fig)
    print(out_path)


if __name__ == "__main__":
    main()

