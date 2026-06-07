from pathlib import Path
import warnings

import pandas as pd


PROJ = Path(
    "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/"
    "My Drive/Projects/ongoing/japan_war"
)

SRC = PROJ / "data/raw/census/census1982(1).dta"
OUT_CSV = PROJ / "data/temp/census1982_birthorder_proxy_v1.csv"
OUT_DTA = PROJ / "data/temp/census1982_birthorder_proxy_v1.dta"
AUDIT_CSV = PROJ / "result/table/census1982_birthorder_proxy_audit_v1.csv"


def process_block(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    for c in ["serial", "pernum", "momloc", "poploc", "age", "sex", "county", "edattain"]:
        df[c] = pd.to_numeric(df[c], errors="coerce")

    df = df.sort_values(["serial", "momloc", "age", "pernum"], kind="mergesort")
    mgrp = df["momloc"].gt(0)
    df.loc[mgrp, "older_m"] = (
        df.loc[mgrp].groupby(["serial", "momloc"], sort=False).cumcount(ascending=False)
    )

    df = df.sort_values(["serial", "poploc", "age", "pernum"], kind="mergesort")
    pgrp = df["poploc"].gt(0)
    df.loc[pgrp, "older_p"] = (
        df.loc[pgrp].groupby(["serial", "poploc"], sort=False).cumcount(ascending=False)
    )

    df["parent_present"] = df["momloc"].gt(0) | df["poploc"].gt(0)
    df["any_older_sib_proxy"] = (
        df["older_m"].fillna(-1).gt(0) | df["older_p"].fillna(-1).gt(0)
    ).astype("boolean")
    df.loc[~df["parent_present"], "any_older_sib_proxy"] = pd.NA

    df["birthyr"] = 1982 - df["age"]
    adult = df["birthyr"].between(1920, 1960, inclusive="both")
    out = df.loc[
        adult,
        [
            "serial",
            "pernum",
            "county",
            "age",
            "sex",
            "birthyr",
            "edattain",
            "parent_present",
            "any_older_sib_proxy",
        ],
    ].copy()
    out["firstborn_proxy"] = pd.Series(pd.NA, index=out.index, dtype="Int64")
    has_proxy = out["any_older_sib_proxy"].notna()
    out.loc[has_proxy, "firstborn_proxy"] = (
        out.loc[has_proxy, "any_older_sib_proxy"].eq(False).astype("Int64")
    )
    return out


def main() -> None:
    warnings.filterwarnings("ignore", category=FutureWarning)
    if OUT_CSV.exists():
        OUT_CSV.unlink()

    totals = {
        "adult_obs_1920_1960": 0,
        "with_parent_present": 0,
        "proxy_identifiable": 0,
        "any_older_sib_proxy": 0,
        "firstborn_proxy": 0,
    }

    reader = pd.read_stata(
        SRC,
        columns=["serial", "pernum", "momloc", "poploc", "age", "sex", "county", "edattain"],
        convert_categoricals=False,
        chunksize=200_000,
    )

    carry = None
    wrote_header = False
    chunk_no = 0

    for chunk in reader:
        chunk_no += 1
        if carry is not None and not carry.empty:
            chunk = pd.concat([carry, chunk], ignore_index=True)

        if chunk.empty:
            continue

        last_serial = chunk["serial"].iloc[-1]
        carry = chunk.loc[chunk["serial"] == last_serial].copy()
        work = chunk.loc[chunk["serial"] != last_serial].copy()

        if work.empty:
            continue

        out = process_block(work)
        totals["adult_obs_1920_1960"] += len(out)
        totals["with_parent_present"] += int(out["parent_present"].sum())
        totals["proxy_identifiable"] += int(out["any_older_sib_proxy"].notna().sum())
        totals["any_older_sib_proxy"] += int((out["any_older_sib_proxy"] == 1).sum())
        totals["firstborn_proxy"] += int((out["firstborn_proxy"] == 1).sum())

        keep = out.loc[out["parent_present"] == 1].copy()
        keep["countyid_old6"] = pd.to_numeric(keep["county"], errors="coerce")
        keep.to_csv(OUT_CSV, mode="a", header=not wrote_header, index=False)
        wrote_header = True
        print(f"chunk {chunk_no} done: adult={len(out)} keep={len(keep)}")

    if carry is not None and not carry.empty:
        out = process_block(carry)
        totals["adult_obs_1920_1960"] += len(out)
        totals["with_parent_present"] += int(out["parent_present"].sum())
        totals["proxy_identifiable"] += int(out["any_older_sib_proxy"].notna().sum())
        totals["any_older_sib_proxy"] += int((out["any_older_sib_proxy"] == 1).sum())
        totals["firstborn_proxy"] += int((out["firstborn_proxy"] == 1).sum())

        keep = out.loc[out["parent_present"] == 1].copy()
        keep["countyid_old6"] = pd.to_numeric(keep["county"], errors="coerce")
        keep.to_csv(OUT_CSV, mode="a", header=not wrote_header, index=False)
        print(f"final carry done: adult={len(out)} keep={len(keep)}")

    audit = pd.DataFrame(
        {
            "metric": list(totals.keys())
            + ["share_parent_present", "share_any_older_sib_proxy", "share_firstborn_proxy"],
            "value": list(totals.values())
            + [
                totals["with_parent_present"] / totals["adult_obs_1920_1960"] if totals["adult_obs_1920_1960"] else pd.NA,
                totals["any_older_sib_proxy"] / totals["proxy_identifiable"] if totals["proxy_identifiable"] else pd.NA,
                totals["firstborn_proxy"] / totals["proxy_identifiable"] if totals["proxy_identifiable"] else pd.NA,
            ],
        }
    )
    audit.to_csv(AUDIT_CSV, index=False)

    proxy = pd.read_csv(OUT_CSV)
    proxy.to_stata(OUT_DTA, write_index=False, version=118)

    print(AUDIT_CSV)
    print(OUT_CSV)
    print(OUT_DTA)


if __name__ == "__main__":
    main()
