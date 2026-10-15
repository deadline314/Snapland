#!/usr/bin/env python3
"""Build/check alpha-derived character animation regions. Never modifies source PNGs."""
from __future__ import annotations
import argparse, json, sys
from pathlib import Path
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/characters/complete-animation-regions.json"
TRAVELLER_VARIANT = ROOT / "assets/characters/traveller-vest-actions-v1.png"
ANNOUNCER_SIDE_WALK = ROOT / "assets/characters/announcer-walk-sides-v2.png"
ANNOUNCER_SIDE_SCALE = 0.54
TRAVELLER_JUMP = ROOT / "assets/characters/traveller-jump-front-v1.png"
# One sequence-wide scale derived from the largest row-baseline-preserving crop:
# 360 canonical px / (1.6 actor scale * 343 source px) ~= 0.656.
TRAVELLER_JUMP_SCALE = 0.656
TRAVELLER_COVERAGE_NOTE = "Front actions plus four dedicated idle poses each for left/right. Existing eight-direction walk remains in the legacy atlas. Back and diagonal dedicated idle remain uncovered. Jump is an eight-pose front action at 12 FPS; other jump directions are not authored here. Seated and catch actions retain separately authored metadata."
ACTORS = {
    "traveller": {"cols": 8, "rows": ["idle", "wave", "photograph", "interact"], "ref": [175, 220], "canvas": [280, 360], "feet": 346, "fps": {"idle": 3, "wave": 6, "photograph": 5, "interact": 5}},
    "ticket": {"cols": 8, "rows": ["idle", "greet", "interact", "idle_gesture", "emotion_happy", "walk_candidate"], "ref": [130, 200], "canvas": [320, 460], "feet": 448, "fps": {"idle": 3, "greet": 6, "interact": 5, "idle_gesture": 3, "emotion_happy": 4, "walk_candidate": 7}},
    "imp": {"cols": 7, "rows": ["idle", "greet", "interact", "idle_gesture", "emotion_proud", "dance"], "ref": [150, 180], "canvas": [320, 460], "feet": 448, "fps": {"idle": 3, "greet": 6, "interact": 5, "idle_gesture": 3, "emotion_proud": 4, "dance": 6}},
    "announcer": {"cols": 8, "rows": ["idle", "greet", "interact", "special", "emotion_curious", "walk_candidate"], "ref": [160, 180], "canvas": [320, 460], "feet": 448, "fps": {"idle": 3, "greet": 6, "interact": 5, "special": 5, "emotion_curious": 4, "walk_candidate": 7}},
}

def runs(mask: np.ndarray) -> list[tuple[int, int]]:
    indices = np.flatnonzero(mask)
    if not len(indices): return []
    result=[]; start=prev=int(indices[0])
    for raw in indices[1:]:
        value=int(raw)
        if value != prev+1:
            result.append((start, prev+1)); start=value
        prev=value
    result.append((start, prev+1))
    return result

def boundaries(intervals: list[tuple[int,int]], limit: int, expected: int, label: str) -> list[int]:
    if len(intervals) != expected:
        raise ValueError(f"{label}: expected {expected} alpha>128 bands, found {len(intervals)}: {intervals}")
    return [0] + [(intervals[i-1][1] + intervals[i][0]) // 2 for i in range(1,len(intervals))] + [limit]

def authored_anchors(body: np.ndarray) -> tuple[list[int], list[int], dict]:
    """Estimate shoe midpoint and hair/hat top from the primary-alpha silhouette."""
    yy, xx = np.where(body)
    x0, x1 = int(xx.min()), int(xx.max() + 1)
    y0, y1 = int(yy.min()), int(yy.max() + 1)
    width = x1 - x0
    # Restrict the head estimate to the central upper silhouette so a raised hand
    # cannot move the head anchor sideways or upward.
    head_band = max(1, int(round(width * 0.28)))
    center = (x0 + x1) / 2.0
    hx0 = max(x0, int(round(center - head_band)))
    hx1 = min(x1, int(round(center + head_band)))
    central = body[y0:y1, hx0:hx1]
    cy, cx = np.where(central)
    if not len(cx):
        head_x, head_y = int(round(center)), y0
    else:
        head_y = y0 + int(cy.min())
        head_slice = central[: min(20, central.shape[0]), :]
        sy, sx = np.where(head_slice)
        head_x = hx0 + int(round((int(sx.min()) + int(sx.max())) / 2.0)) if len(sx) else int(round(center))
    # Use only the bottom eight strong-alpha rows to find shoe contacts.
    bottom = body[max(y0, y1 - 8):y1, :]
    shoe_projection = bottom.any(axis=0)
    shoe_runs = [run for run in runs(shoe_projection) if run[1] - run[0] >= 3]
    if len(shoe_runs) >= 2:
        # Widest two separated contacts represent left and right shoes.
        shoes = sorted(shoe_runs, key=lambda run: run[1] - run[0], reverse=True)[:2]
        shoe_centers = sorted((run[0] + run[1] - 1) / 2.0 for run in shoes)
        feet_x = int(round((shoe_centers[0] + shoe_centers[1]) / 2.0))
        feet_method = "bottom_8px_two_contact_midpoint"
    else:
        # If the shoes touch in this pose, use the weighted lower-silhouette center.
        weights = shoe_projection.astype(np.int64)
        feet_x = int(round(float(np.dot(np.arange(body.shape[1]), weights)) / max(1, int(weights.sum()))))
        feet_method = "bottom_8px_joined_contact_centroid"
    return [feet_x, y1], [head_x, head_y], {"feet_method": feet_method, "head_method": "central_upper_alpha_hat_hair_top"}

def analyze(actor: str) -> tuple[dict, dict]:
    spec=ACTORS[actor]; path=ROOT/f"assets/characters/{actor}-front-actions-v2.png"
    image=Image.open(path).convert("RGBA"); rgba=np.asarray(image); alpha=rgba[:,:,3]; h,w=alpha.shape
    xs=runs((alpha>128).any(axis=0)); ys=runs((alpha>128).any(axis=1))
    xb=boundaries(xs,w,spec["cols"],actor+" columns")
    yb=boundaries(ys,h,len(spec["rows"]),actor+" rows")
    actions={}; summaries=[]; max_w=max_h=0; weak_outside=0; edge_hits=0; min_margins=[float("inf")]*4; min_aa_margins=[float("inf")]*4
    for row,action in enumerate(spec["rows"]):
        frames=[]
        for col in range(spec["cols"]):
            x0,x1=xb[col],xb[col+1]; y0,y1=yb[row],yb[row+1]
            tile=alpha[y0:y1,x0:x1]; body=tile>128
            yy,xx=np.where(body)
            if not len(xx): raise ValueError(f"{actor}/{action}/{col}: no primary alpha body")
            bx0,bx1=int(xx.min()),int(xx.max()+1); by0,by1=int(yy.min()),int(yy.max()+1)
            # Include a small anti-alias fringe, capped by the transparent-gap midpoint split.
            pad=2
            rx0=max(0,bx0-pad); ry0=max(0,by0-pad); rx1=min(tile.shape[1],bx1+pad); ry1=min(tile.shape[0],by1+pad)
            region=[x0+rx0,y0+ry0,rx1-rx0,ry1-ry0]
            crop=alpha[region[1]:region[1]+region[3],region[0]:region[0]+region[2]]
            # Flag high-alpha silhouette touching its assigned boundary, and record weak fringe omitted by crop.
            edge_hits += int(bool(body[0].any() or body[-1].any() or body[:,0].any() or body[:,-1].any()))
            slot=(alpha[y0:y1,x0:x1]>0)
            region_mask=np.zeros_like(slot); region_mask[ry0:ry1,rx0:rx1]=True
            weak_outside += int(np.count_nonzero(slot & ~region_mask & (alpha[y0:y1,x0:x1] <= 128)))
            fw,fh=region[2],region[3]; max_w=max(max_w,fw); max_h=max(max_h,fh)
            feet,head,anchor_methods=authored_anchors(body)
            # Anchors are stored in the cropped region's coordinate space.
            feet=[feet[0]-rx0, feet[1]-ry0]; head=[head[0]-rx0,head[1]-ry0]
            frames.append({"source":f"res://assets/characters/{actor}-front-actions-v2.png","region":region,"anchors":{"feet":feet,"head":head},"anchor_method":anchor_methods,"layers":[]})
            scale=min(spec["canvas"][0]/spec["ref"][0],spec["canvas"][1]/spec["ref"][1])
            draw_x=spec["canvas"][0]/2-feet[0]*scale
            draw_y=spec["feet"]-feet[1]*scale
            left=draw_x+(bx0-rx0)*scale
            right=spec["canvas"][0]-(draw_x+(bx1-rx0)*scale)
            top=draw_y+(by0-ry0)*scale
            bottom_margin=spec["canvas"][1]-(draw_y+(by1-ry0)*scale)
            min_margins=[min(min_margins[i],v) for i,v in enumerate([left,top,right,bottom_margin])]
            min_aa_margins=[min(min_aa_margins[i],v-pad*scale) for i,v in enumerate([left,top,right,bottom_margin])]
            summaries.append({"action":action,"frame":col,"region":region,"anchors":{"feet":feet,"head":head},"anchor_method":anchor_methods,"strong_alpha_pixels":int(np.count_nonzero(body)),"weak_alpha_omitted":int(np.count_nonzero(slot & ~region_mask & (alpha[y0:y1,x0:x1] <= 128)))})
        actions[action]={"front":{"fps":spec["fps"][action],"loop":action in ("idle","walk"),"frames":frames}}
    actor_data={"canvas_size":spec["canvas"],"reference_size":spec["ref"],"feet_baseline":spec["feet"],**actions}
    report={"actor":actor,"source":path.relative_to(ROOT).as_posix(),"source_size":[w,h],"alpha_threshold_body":128,"grid_from_global_alpha_gutters":True,"frame_count":sum(len(x["front"]["frames"]) for x in actions.values()),"max_region_size":[max_w,max_h],"scale_factor":round(min(spec["canvas"][0]/spec["ref"][0],spec["canvas"][1]/spec["ref"][1]),4),"canonical_margins_min_px":{"left":round(min_margins[0],1),"top":round(min_margins[1],1),"right":round(min_margins[2],1),"bottom":round(min_margins[3],1)},"canonical_aa_margins_min_px":{"left":round(min_aa_margins[0],1),"top":round(min_aa_margins[1],1),"right":round(min_aa_margins[2],1),"bottom":round(min_aa_margins[3],1)},"primary_alpha_boundary_hits":edge_hits,"weak_alpha_omitted_pixels":weak_outside,"frames":summaries}
    return actor_data,report

def add_traveller_outfit_variant(actor_data: dict) -> dict:
    """Attach aligned full-pose frames from the coral vest atlas to traveller actions."""
    if not TRAVELLER_VARIANT.exists():
        raise ValueError(f"missing variant atlas: {TRAVELLER_VARIANT.relative_to(ROOT)}")
    rgba=np.asarray(Image.open(TRAVELLER_VARIANT).convert("RGBA")); alpha=rgba[:,:,3]; h,w=alpha.shape
    spec=ACTORS["traveller"]
    xs=runs((alpha>128).any(axis=0)); ys=runs((alpha>128).any(axis=1))
    xb=boundaries(xs,w,spec["cols"],"traveller coral columns")
    yb=boundaries(ys,h,len(spec["rows"]),"traveller coral rows")
    scale=min(spec["canvas"][0]/spec["ref"][0],spec["canvas"][1]/spec["ref"][1])
    edge_hits=0; min_margins=[float("inf")]*4; row_reports=[]
    for row,action in enumerate(spec["rows"]):
        frames=actor_data[action]["front"]["frames"]
        if len(frames)!=spec["cols"]: raise ValueError(f"traveller/{action}: base pose count does not match variant")
        for col in range(spec["cols"]):
            x0,x1=xb[col],xb[col+1]; y0,y1=yb[row],yb[row+1]
            slot=alpha[y0:y1,x0:x1]; body=slot>128; yy,xx=np.where(body)
            if not len(xx): raise ValueError(f"traveller/{action}/frame {col}: coral variant lacks primary body alpha")
            bx0,bx1=int(xx.min()),int(xx.max()+1); by0,by1=int(yy.min()),int(yy.max()+1)
            if bool(body[0].any() or body[-1].any() or body[:,0].any() or body[:,-1].any()): edge_hits+=1
            pad=2; rx0=max(0,bx0-pad); ry0=max(0,by0-pad); rx1=min(slot.shape[1],bx1+pad); ry1=min(slot.shape[0],by1+pad)
            feet,head,methods=authored_anchors(body)
            feet=[feet[0]-rx0,feet[1]-ry0]; head=[head[0]-rx0,head[1]-ry0]
            variant={"source":"res://assets/characters/traveller-vest-actions-v1.png","region":[x0+rx0,y0+ry0,rx1-rx0,ry1-ry0],"anchors":{"feet":feet,"head":head}}
            frames[col].setdefault("variants",{})["outfit-coral"]=variant
            draw_x=spec["canvas"][0]/2-feet[0]*scale; draw_y=spec["feet"]-feet[1]*scale
            margins=[draw_x+(bx0-rx0)*scale,
                     draw_y+(by0-ry0)*scale,
                     spec["canvas"][0]-(draw_x+(bx1-rx0)*scale),
                     spec["canvas"][1]-(draw_y+(by1-ry0)*scale)]
            min_margins=[min(min_margins[i],value) for i,value in enumerate(margins)]
            row_reports.append({"action":action,"frame":col,"variant_region":variant["region"],"anchors":variant["anchors"],"anchor_method":methods})
    aa_margins=[value-2*scale for value in min_margins]
    report={"source":TRAVELLER_VARIANT.relative_to(ROOT).as_posix(),"source_size":[w,h],"frame_count":len(row_reports),"grid_from_global_alpha_gutters":True,"primary_alpha_boundary_hits":edge_hits,"canonical_margins_min_px":{"left":round(min_margins[0],1),"top":round(min_margins[1],1),"right":round(min_margins[2],1),"bottom":round(min_margins[3],1)},"canonical_aa_margins_min_px":{"left":round(aa_margins[0],1),"top":round(aa_margins[1],1),"right":round(aa_margins[2],1),"bottom":round(aa_margins[3],1)},"frames":row_reports}
    return report

def add_traveller_jump(actor_data: dict) -> dict:
    """Register eight authored front jump poses and their aligned coral wardrobe row."""
    if not TRAVELLER_JUMP.exists():
        raise ValueError(f"missing jump atlas: {TRAVELLER_JUMP.relative_to(ROOT)}")
    rgba=np.asarray(Image.open(TRAVELLER_JUMP).convert("RGBA")); alpha=rgba[:,:,3]; h,w=alpha.shape
    xs=runs((alpha>128).any(axis=0)); ys=runs((alpha>128).any(axis=1))
    xb=boundaries(xs,w,8,"traveller jump columns")
    yb=boundaries(ys,h,2,"traveller jump outfit rows")
    spec=ACTORS["traveller"]
    actor_scale=min(spec["canvas"][0]/spec["ref"][0],spec["canvas"][1]/spec["ref"][1])
    effective_scale=actor_scale*TRAVELLER_JUMP_SCALE
    frames=[]; variant_rows=[]; summaries=[]; variant_summaries=[]; max_region_height=0; max_region_width=0
    for row, outfit_name in enumerate(("base", "outfit-coral")):
        row_frames=frames if row == 0 else variant_rows
        y0,y1=yb[row],yb[row+1]
        for col in range(8):
            x0,x1=xb[col],xb[col+1]
            tile=alpha[y0:y1,x0:x1]; body=tile>128
            yy,xx=np.where(body)
            if not len(xx): raise ValueError(f"traveller/jump/front/frame {col}/{outfit_name}: no primary alpha body")
            bx0,bx1=int(xx.min()),int(xx.max()+1); by0,by1=int(yy.min()),int(yy.max()+1)
            # Keep the whole source-space distance to the shared atlas-row baseline.
            # This preserves authored airborne height while avoiding per-pose auto-fit.
            pad=2; rx0=max(0,bx0-pad); ry0=max(0,by0-pad); rx1=min(tile.shape[1],bx1+pad); ry1=tile.shape[0]
            feet,head,methods=authored_anchors(body)
            feet=[feet[0]-rx0, y1-(y0+ry0)]
            head=[head[0]-rx0,head[1]-ry0]
            region=[x0+rx0,y0+ry0,rx1-rx0,ry1-ry0]
            max_region_width=max(max_region_width,region[2]); max_region_height=max(max_region_height,region[3])
            frame={"source":"res://assets/characters/traveller-jump-front-v1.png","region":region,"anchors":{"feet":feet,"head":head},"anchor_method":{**methods,"feet_y_method":"shared_atlas_row_baseline_preserves_authored_vertical_pose"},"source_scale":TRAVELLER_JUMP_SCALE,"layers":[]}
            if row == 0:
                frames.append(frame)
            else:
                variant_rows.append(frame)
            used_alpha=body[by0:by1,bx0:bx1]
            summary={"frame":col,"region":region,"anchors":{"feet":feet,"head":head},"strong_alpha_bounds_in_cell":[bx0,by0,bx1-bx0,by1-by0],"strong_alpha_height_px":by1-by0,"strong_alpha_pixels":int(np.count_nonzero(used_alpha)),"anchor_method":frame["anchor_method"]}
            (summaries if row == 0 else variant_summaries).append(summary)
    for index in range(8):
        frames[index]["variants"]={"outfit-coral":variant_rows[index]}
    actor_data["jump"]={"front":{"fps":12,"loop":False,"frames":frames}}
    heights=[item["strong_alpha_height_px"] for item in summaries]
    variant_heights=[item["strong_alpha_height_px"] for item in variant_summaries]
    return {"actor":"traveller","action":"jump","direction":"front","source":TRAVELLER_JUMP.relative_to(ROOT).as_posix(),"source_size":[w,h],"atlas_rows":{"base":[yb[0],yb[1]],"outfit-coral":[yb[1],yb[2]]},"frame_count":len(frames),"variant_frame_count":len(variant_rows),"fps":12,"loop":False,"source_scale":round(TRAVELLER_JUMP_SCALE,6),"reference_size":spec["ref"],"actor_scale":round(actor_scale,4),"effective_scale":round(effective_scale,4),"max_region_size_px":[max_region_width,max_region_height],"strong_alpha_height_px":{"base":[min(heights),max(heights)],"outfit-coral":[min(variant_heights),max(variant_heights)]},"anchor_policy":"feet x comes from lower strong-alpha shoe contacts; feet y uses the shared atlas-row lower edge so authored airborne height remains visible","frames":summaries,"variant_frames":variant_summaries}

def add_announcer_side_walk(actor_data: dict) -> dict:
    """Register the four authored profile keys per side; repeated atlas cells stay unregistered."""
    if not ANNOUNCER_SIDE_WALK.exists():
        raise ValueError(f"missing side-walk atlas: {ANNOUNCER_SIDE_WALK.relative_to(ROOT)}")
    rgba=np.asarray(Image.open(ANNOUNCER_SIDE_WALK).convert("RGBA")); alpha=rgba[:,:,3]; h,w=alpha.shape
    xs=runs((alpha>128).any(axis=0)); ys=runs((alpha>128).any(axis=1))
    xb=boundaries(xs,w,8,"announcer side-walk columns")
    yb=boundaries(ys,h,2,"announcer side-walk rows")
    spec=ACTORS["announcer"]
    actor_scale=min(spec["canvas"][0]/spec["ref"][0],spec["canvas"][1]/spec["ref"][1])
    effective_scale=actor_scale*ANNOUNCER_SIDE_SCALE
    side_actions={}; edge_hits=0; min_margins=[float("inf")]*4; min_aa_margins=[float("inf")]*4; summaries=[]
    for row,direction in enumerate(("right","left")):
        frames=[]
        for col in range(4):
            x0,x1=xb[col],xb[col+1]; y0,y1=yb[row],yb[row+1]
            tile=alpha[y0:y1,x0:x1]; body=tile>128
            yy,xx=np.where(body)
            if not len(xx): raise ValueError(f"announcer/walk/{direction}/frame {col}: no primary alpha body")
            bx0,bx1=int(xx.min()),int(xx.max()+1); by0,by1=int(yy.min()),int(yy.max()+1)
            edge_hits+=int(bool(body[0].any() or body[-1].any() or body[:,0].any() or body[:,-1].any()))
            pad=2; rx0=max(0,bx0-pad); ry0=max(0,by0-pad); rx1=min(tile.shape[1],bx1+pad); ry1=min(tile.shape[0],by1+pad)
            feet,head,methods=authored_anchors(body)
            feet=[feet[0]-rx0,feet[1]-ry0]; head=[head[0]-rx0,head[1]-ry0]
            region=[x0+rx0,y0+ry0,rx1-rx0,ry1-ry0]
            frame={"source":"res://assets/characters/announcer-walk-sides-v2.png","region":region,"anchors":{"feet":feet,"head":head},"anchor_method":methods,"source_scale":ANNOUNCER_SIDE_SCALE,"layers":[]}
            frames.append(frame)
            draw_x=spec["canvas"][0]/2-feet[0]*effective_scale
            draw_y=spec["feet"]-feet[1]*effective_scale
            margins=[draw_x+(bx0-rx0)*effective_scale,
                     draw_y+(by0-ry0)*effective_scale,
                     spec["canvas"][0]-(draw_x+(bx1-rx0)*effective_scale),
                     spec["canvas"][1]-(draw_y+(by1-ry0)*effective_scale)]
            min_margins=[min(min_margins[i],value) for i,value in enumerate(margins)]
            min_aa_margins=[min(min_aa_margins[i],value-pad*effective_scale) for i,value in enumerate(margins)]
            summaries.append({"direction":direction,"frame":col,"region":region,"anchors":{"feet":feet,"head":head},"anchor_method":methods,"strong_alpha_pixels":int(np.count_nonzero(body))})
        side_actions[direction]={"fps":7,"loop":True,"frames":frames}
    actor_data["walk"]=side_actions
    return {"actor":"announcer","source":ANNOUNCER_SIDE_WALK.relative_to(ROOT).as_posix(),"source_size":[w,h],"atlas_rows":{"right":0,"left":1},"registered_frames_per_direction":4,"repeated_cells_excluded":True,"frame_count":sum(len(entry["frames"]) for entry in side_actions.values()),"grid_from_global_alpha_gutters":True,"source_scale":ANNOUNCER_SIDE_SCALE,"actor_scale":round(actor_scale,4),"effective_scale":round(effective_scale,4),"primary_alpha_boundary_hits":edge_hits,"canonical_margins_min_px":{"left":round(min_margins[0],1),"top":round(min_margins[1],1),"right":round(min_margins[2],1),"bottom":round(min_margins[3],1)},"canonical_aa_margins_min_px":{"left":round(min_aa_margins[0],1),"top":round(min_aa_margins[1],1),"right":round(min_aa_margins[2],1),"bottom":round(min_aa_margins[3],1)},"frames":summaries}

def add_traveller_side_idle(actor_data: dict) -> dict:
    """Register complete planted-foot profile poses, with one shared source scale."""
    path = ROOT / "assets/characters/traveller-idle-sides-v1.png"
    alpha = np.asarray(Image.open(path).convert("RGBA"))[:, :, 3]
    h, w = alpha.shape
    xb = boundaries(runs((alpha > 128).any(axis=0)), w, 4, "traveller side-idle columns")
    yb = boundaries(runs((alpha > 128).any(axis=1)), h, 2, "traveller side-idle rows")
    summaries = []
    for row, direction in enumerate(("left", "right")):
        frames = []
        for col in range(4):
            x0, x1 = xb[col], xb[col + 1]
            y0, y1 = yb[row], yb[row + 1]
            body = alpha[y0:y1, x0:x1] > 128
            yy, xx = np.where(body)
            if not len(xx) or body[0].any() or body[-1].any() or body[:, 0].any() or body[:, -1].any():
                raise ValueError(f"traveller/idle/{direction}/{col}: empty or clipped full-body pose")
            rx0, ry0 = max(0, int(xx.min()) - 2), max(0, int(yy.min()) - 2)
            rx1, ry1 = min(body.shape[1], int(xx.max()) + 3), min(body.shape[0], int(yy.max()) + 3)
            feet, head, methods = authored_anchors(body)
            frame = {"source": "res://assets/characters/traveller-idle-sides-v1.png",
                     "region": [x0 + rx0, y0 + ry0, rx1 - rx0, ry1 - ry0],
                     "anchors": {"feet": [feet[0] - rx0, feet[1] - ry0], "head": [head[0] - rx0, head[1] - ry0]},
                     "anchor_method": methods, "source_scale": 0.46, "layers": []}
            frames.append(frame)
            summaries.append({"direction": direction, "frame": col, "region": frame["region"]})
        # Four authored poses, not duplicated timing cels: neutral, inhale, blink, return.
        actor_data["idle"][direction] = {"fps": 4, "loop": True,
                                          "frame_durations": [1.9, 0.3, 0.12, 0.5], "frames": frames}
    return {"source": path.relative_to(ROOT).as_posix(), "frame_count": 8,
            "directions": ["left", "right"], "source_scale": 0.46,
            "frame_durations": [1.9, 0.3, 0.12, 0.5], "frames": summaries}


def build() -> tuple[dict,dict]:
    actors={}; reports={}
    for actor in ACTORS:
        actors[actor],reports[actor]=analyze(actor)
    variant_report=add_traveller_outfit_variant(actors["traveller"])
    reports["traveller"]["variants"]={"outfit-coral":{k:v for k,v in variant_report.items() if k!="frames"}}
    jump_report=add_traveller_jump(actors["traveller"])
    reports["traveller"]["jump_front"]={k:v for k,v in jump_report.items() if k not in ("frames","variant_frames")}
    announcer_walk_report=add_announcer_side_walk(actors["announcer"])
    reports["announcer"]["walk_side_atlas"]={k:v for k,v in announcer_walk_report.items() if k!="frames"}
    reports["traveller"]["idle_side_atlas"] = add_traveller_side_idle(actors["traveller"])
    manifest={"schema_version":1,"description":"Regions are alpha-trimmed per frame after row/column gutters are detected from the source-wide alpha>128 projection. Feet use shoe contacts in the bottom eight primary-alpha rows; head uses the central upper silhouette. Weak-alpha anti-alias fringes receive a 2px pad. Optional source_scale is a finite 0.01–4 per-frame multiplier on the shared actor/reference scale, never a per-frame bounds fit. The traveller jump action retains a shared atlas-row baseline so its authored airborne height is preserved. No frame is mirrored, copied, or synthetically padded.","runtime_aliases":{"traveller":{"station_stand":"idle/front/frame_0 (same authored frame; not a separate animation)"},"ticket":{"special":"idle_gesture/front (runtime alias; no duplicate frames)"}},"coverage_notes":{"traveller":TRAVELLER_COVERAGE_NOTE,"traveller_outfit_coral":"Full-pose clothing variant aligned to the 32 traveller front-action frames plus eight jump/front frames; not an independent clothing layer and does not establish all-direction coverage. Footwear/hands remain subject to visual review.","ticket":"Walk row is only a walk_candidate pending authored validation.","imp":"42 authored cells (7x6); no frames synthesized.","announcer":"Side-walk adds four authored profile poses each for right and left from the first four cells per atlas row. Four repeated cells per row are excluded; diagonal and front/back walk directions remain uncovered."},"actors":actors}
    return manifest,reports

def main() -> int:
    parser=argparse.ArgumentParser(); parser.add_argument("--check",action="store_true",help="validate alpha-derived regions and compare the committed manifest"); parser.add_argument("--write",action="store_true",help="write JSON manifest (source PNGs are read-only)")
    parser.add_argument("--side-idle-only", action="store_true", help="update/check only profile idle; preserve separately authored seated/catch actions")
    args=parser.parse_args()
    if args.side_idle_only:
        try:
            existing = json.loads(OUT.read_text(encoding="utf-8"))
            actor = {"idle": {}}
            report = add_traveller_side_idle(actor)
            if args.check:
                for direction in ("left", "right"):
                    if existing["actors"]["traveller"]["idle"].get(direction) != actor["idle"][direction]:
                        raise ValueError(f"traveller/idle/{direction}: differs from alpha-derived source metadata")
            if args.write:
                existing["actors"]["traveller"]["idle"].update(actor["idle"])
                existing.setdefault("coverage_notes", {})["traveller"] = TRAVELLER_COVERAGE_NOTE
                OUT.write_text(json.dumps(existing, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            print(f"PASS: {report['frame_count']} authored side-idle regions; unrelated action metadata preserved")
            return 0
        except Exception as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 1
    try: manifest,reports=build()
    except Exception as exc: print(f"ERROR: {exc}",file=sys.stderr); return 1
    if args.write:
        OUT.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    if args.check:
        if not OUT.exists(): print(f"ERROR: missing {OUT}",file=sys.stderr); return 1
        existing=json.loads(OUT.read_text(encoding="utf-8"))
        if existing != manifest: print("ERROR: manifest differs from alpha-derived source metadata",file=sys.stderr); return 1
        failures=[]
        for actor,report in reports.items():
            if report["primary_alpha_boundary_hits"]: failures.append(f"{actor}: {report['primary_alpha_boundary_hits']} strong silhouette(s) touch assigned region split")
            if min(report["canonical_margins_min_px"].values()) <= 2: failures.append(f"{actor}: strong-alpha margin is 2px or less")
            if min(report["canonical_aa_margins_min_px"].values()) < 0: failures.append(f"{actor}: padded weak-alpha bounds exceed canonical canvas")
            for variant_name,variant in report.get("variants",{}).items():
                if variant["frame_count"] != 32: failures.append(f"{actor}/{variant_name}: expected 32 aligned frames")
                if variant["primary_alpha_boundary_hits"]: failures.append(f"{actor}/{variant_name}: {variant['primary_alpha_boundary_hits']} strong silhouettes touch split")
                if min(variant["canonical_margins_min_px"].values()) <= 2: failures.append(f"{actor}/{variant_name}: strong-alpha margin is 2px or less")
                if min(variant["canonical_aa_margins_min_px"].values()) < 0: failures.append(f"{actor}/{variant_name}: padded weak-alpha bounds exceed canonical canvas")
            jump=report.get("jump_front")
            if jump:
                if jump["frame_count"] != 8 or jump["variant_frame_count"] != 8 or jump["fps"] != 12 or jump["loop"]: failures.append("traveller/jump/front: expected eight base and coral frames at 12 FPS, non-looping")
                if jump["source_size"] != [2172,724]: failures.append("traveller/jump/front: source atlas dimensions changed")
            side_walk=report.get("walk_side_atlas")
            if side_walk:
                if side_walk["frame_count"] != 8 or side_walk["registered_frames_per_direction"] != 4 or not side_walk["repeated_cells_excluded"]: failures.append("announcer: expected only four unique authored side-walk frames per direction")
                if side_walk["primary_alpha_boundary_hits"]: failures.append(f"announcer side-walk: {side_walk['primary_alpha_boundary_hits']} strong silhouettes touch split")
                if min(side_walk["canonical_margins_min_px"].values()) <= 2: failures.append("announcer side-walk: strong-alpha margin is 2px or less")
                if min(side_walk["canonical_aa_margins_min_px"].values()) < 0: failures.append("announcer side-walk: padded weak-alpha bounds exceed canonical canvas")
            print(json.dumps({k:v for k,v in report.items() if k!="frames"},ensure_ascii=False))
        if failures:
            print("FAIL: "+"; ".join(failures),file=sys.stderr); return 1
        verified_regions=sum(x["frame_count"]+x.get("walk_side_atlas",{}).get("frame_count",0) for x in reports.values())
        print(f"PASS: {verified_regions} authored regions verified; no synthetic frames")
    if not args.check and not args.write: parser.print_help()
    return 0
if __name__ == "__main__": raise SystemExit(main())
