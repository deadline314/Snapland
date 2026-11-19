#!/usr/bin/env python3
"""Build/check character regions and source-bound annotations without editing PNGs."""
from __future__ import annotations
import argparse, copy, hashlib, json, sys
from pathlib import Path
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/characters/complete-animation-regions.json"
AUTHORING = ROOT / "assets/characters/animation-authoring.json"
TRAVELLER_VARIANT = ROOT / "assets/characters/traveller-vest-actions-v1.png"
TRAVELLER_PROFILE_WAVES = {
    "left": (
        "832c0ed81f01ed9c9ebc79c933828816c0369fb118458a39a92502dd018be83c", 130,
        (([249, 63, 314, 591], [153, 585], [150, 7]),
         ([927, 63, 337, 591], [179, 585], [175, 7]),
         ([1637, 63, 331, 591], [173, 585], [168, 7])),
    ),
    "right": (
        "1c9d14ae8337283fb5854b3bc47bea0cbb6a10868dee09ebac794cb9ced1dc74", 150,
        (([200, 61, 334, 589], [124, 584], [163, 8]),
         ([923, 60, 338, 590], [125, 585], [164, 9]),
         ([1647, 61, 326, 589], [125, 584], [164, 8])),
    ),
}
TRAVELLER_CAMERA_CHECK = ROOT / "assets/characters/traveller-camera-check-front-v1.png"
TRAVELLER_CAMERA_CHECK_SHA256 = "cd4ec54e2826adc23832e48f12328de201bb447f41363ce85867676e536f9d43"
TRAVELLER_PROFILE_PHOTOS = {
    "left": (
        "770eee3f4d94ac01c3d4ab534bdfa9dd563706e1d967a1ef3be5fcb724c39294", 583,
        (([214, 67, 318, 596], [148, 590], [168, 7]),
         ([930, 67, 325, 598], [156, 590], [176, 7]),
         ([1666, 67, 313, 597], [143, 590], [164, 7])),
    ),
    "right": (
        "8914e81634da95d8ad7c2c7955bc9f4d2f92d329b7e39277f81e259bf5913b5e", 594,
        (([205, 56, 318, 607], [133, 601], [151, 7]),
         ([924, 57, 323, 606], [138, 600], [150, 6]),
         ([1647, 57, 312, 608], [138, 600], [145, 6])),
    ),
}
ANNOUNCER_SIDE_WALK = ROOT / "assets/characters/announcer-walk-sides-v2.png"
ANNOUNCER_SIDE_SCALE = 0.54
ANNOUNCER_SIDE_SETTLE = ROOT / "assets/characters/announcer-settle-sides-v1.png"
ANNOUNCER_SETTLE_SCALE = 0.40
ANNOUNCER_SIDE_DEPARTURE = ROOT / "assets/characters/announcer-departure-sides-v1.png"
ANNOUNCER_DEPARTURE_SHA256 = "93678ba1048aabd4777652f64842ee6ced9fc1c68381c0d7314a88bead811ee5"
ANNOUNCER_STOP_LANDING = ROOT / "assets/characters/announcer-stop-landing-v1.png"
ANNOUNCER_STOP_SHA256 = "9fa1593f039b9a4bdc7ca967bb2ffcf7e83b919480df73349ba59ee856bd28ba"
ANNOUNCER_RIGHT_STOP_LANDING = ROOT / "assets/characters/announcer-stop-landing-right-v1.png"
ANNOUNCER_RIGHT_STOP_SHA256 = "d582f8a342b0426c6f43d8de4d96b460cce49c8df5e25ed3c497bb19003b937b"
IMP_SIDE_WALK = ROOT / "assets/characters/imp-walk-sides-v1.png"
IMP_SIDE_SCALE = 0.395
IMP_SIDE_SETTLE = ROOT / "assets/characters/imp-settle-sides-v1.png"
TICKET_SIDE_WALK = ROOT / "assets/characters/ticket-walk-sides-v1.png"
TICKET_SIDE_SCALE = 0.432
TICKET_SIDE_SETTLE = ROOT / "assets/characters/ticket-settle-sides-v1.png"
TRAVELLER_JUMP = ROOT / "assets/characters/traveller-jump-front-v1.png"
# One sequence-wide scale derived from the largest row-baseline-preserving crop:
# 360 canonical px / (1.6 actor scale * 343 source px) ~= 0.656.
TRAVELLER_JUMP_SCALE = 0.656
TRAVELLER_COVERAGE_NOTE = "Front actions with dedicated authored idle in all eight directions. Existing eight-direction walk remains in the legacy atlas. Jump is an eight-pose front action at 12 FPS; other jump directions are not authored here. Seated and catch actions retain separately authored metadata."
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

def add_npc_side_action(actor_data: dict, actor: str, source: Path, columns: int, source_scale: float, fixed_cell_root: bool = False, column_bounds: tuple[int, ...] | None = None, *, action: str = "walk", fps: int = 7, loop: bool = True, return_direction: str | None = None) -> dict:
    """Register four complete side-action keys; preserve their authored roots and row ground."""
    if not source.exists():
        raise ValueError(f"missing side-action atlas: {source.relative_to(ROOT)}")
    rgba=np.asarray(Image.open(source).convert("RGBA")); alpha=rgba[:,:,3]; h,w=alpha.shape
    xs=runs((alpha>128).any(axis=0)); ys=runs((alpha>128).any(axis=1))
    xb=boundaries(xs,w,columns,f"{actor}/{action} columns")
    if column_bounds is not None:
        if len(column_bounds) != columns + 1 or any(type(value) is not int or not 0 <= value <= w for value in column_bounds) or any(a >= b for a, b in zip(column_bounds, column_bounds[1:])):
            raise ValueError(f"{actor}: invalid authored column bounds")
        xb=list(column_bounds)
    elif fixed_cell_root:
        xb=[round(i*w/columns) for i in range(columns+1)]
    yb=boundaries(ys,h,2,f"{actor}/{action} rows")
    spec=ACTORS[actor]
    actor_scale=min(spec["canvas"][0]/spec["ref"][0],spec["canvas"][1]/spec["ref"][1])
    effective_scale=actor_scale*source_scale
    side_actions={}; edge_hits=0; min_margins=[float("inf")]*4; min_aa_margins=[float("inf")]*4; summaries=[]
    for row,direction in enumerate(("right","left")):
        frames=[]
        shared_ground=int(np.flatnonzero((alpha[yb[row]:yb[row+1],:]>128).any(axis=1))[-1])+1
        for col in range(4):
            x0,x1=xb[col],xb[col+1]; y0,y1=yb[row],yb[row+1]
            tile=alpha[y0:y1,x0:x1]; body=tile>128
            yy,xx=np.where(body)
            if not len(xx): raise ValueError(f"{actor}/{action}/{direction}/frame {col}: no primary alpha body")
            bx0,bx1=int(xx.min()),int(xx.max()+1); by0,by1=int(yy.min()),int(yy.max()+1)
            edge_hits+=int(bool(body[0].any() or body[-1].any() or body[:,0].any() or body[:,-1].any()))
            pad=2; rx0=max(0,bx0-pad); ry0=max(0,by0-pad); rx1=min(tile.shape[1],bx1+pad); ry1=min(tile.shape[0],by1+pad)
            feet,head,methods=authored_anchors(body)
            if fixed_cell_root:
                ry1=min(tile.shape[0],shared_ground+2)
                feet=[round((x1-x0)/2)-rx0,shared_ground-ry0]
                methods={"feet_method":"fixed_authored_cell_root_and_shared_row_ground","head_method":methods["head_method"]}
            else:
                feet=[feet[0]-rx0,feet[1]-ry0]
            head=[head[0]-rx0,head[1]-ry0]
            region=[x0+rx0,y0+ry0,rx1-rx0,ry1-ry0]
            frame={"source":"res://"+source.relative_to(ROOT).as_posix(),"region":region,"anchors":{"feet":feet,"head":head},"anchor_method":methods,"source_scale":source_scale,"layers":[]}
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
        side_actions[direction]={"fps":fps,"loop":loop,"frames":frames}
        if return_direction is not None: side_actions[direction]["return_direction"]=return_direction
    actor_data[action]=side_actions
    return {"actor":actor,"source":source.relative_to(ROOT).as_posix(),"source_size":[w,h],"atlas_rows":{"right":0,"left":1},"registered_frames_per_direction":4,"repeated_cells_excluded":columns>4,"frame_count":sum(len(entry["frames"]) for entry in side_actions.values()),"grid_from_global_alpha_gutters":True,"source_scale":source_scale,"actor_scale":round(actor_scale,4),"effective_scale":round(effective_scale,4),"primary_alpha_boundary_hits":edge_hits,"canonical_margins_min_px":{"left":round(min_margins[0],1),"top":round(min_margins[1],1),"right":round(min_margins[2],1),"bottom":round(min_margins[3],1)},"canonical_aa_margins_min_px":{"left":round(min_aa_margins[0],1),"top":round(min_aa_margins[1],1),"right":round(min_aa_margins[2],1),"bottom":round(min_aa_margins[3],1)},"frames":summaries}

def add_traveller_idle_atlas(actor_data: dict, filename: str, directions: tuple[str, ...], source_scale: float) -> dict:
    """Register complete planted-foot poses with one source scale per atlas."""
    path = ROOT / "assets/characters" / filename
    alpha = np.asarray(Image.open(path).convert("RGBA"))[:, :, 3]
    h, w = alpha.shape
    xb = boundaries(runs((alpha > 128).any(axis=0)), w, 4, "traveller side-idle columns")
    yb = boundaries(runs((alpha > 128).any(axis=1)), h, len(directions), filename + " rows")
    summaries = []
    for row, direction in enumerate(directions):
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
            frame = {"source": "res://assets/characters/" + filename,
                     "region": [x0 + rx0, y0 + ry0, rx1 - rx0, ry1 - ry0],
                     "anchors": {"feet": [feet[0] - rx0, feet[1] - ry0], "head": [head[0] - rx0, head[1] - ry0]},
                     "anchor_method": methods, "source_scale": source_scale, "layers": []}
            frames.append(frame)
            summaries.append({"direction": direction, "frame": col, "region": frame["region"]})
        # Four authored poses, not duplicated timing cels: neutral, inhale, blink, return.
        actor_data["idle"][direction] = {"fps": 4, "loop": True,
                                          "frame_durations": [1.9, 0.3, 0.12, 0.5], "frames": frames}
    return {"source": path.relative_to(ROOT).as_posix(), "frame_count": len(summaries),
            "directions": list(directions), "source_scale": source_scale,
            "frame_durations": [1.9, 0.3, 0.12, 0.5], "frames": summaries}


def add_traveller_side_idle(actor_data: dict) -> dict:
    return add_traveller_idle_atlas(actor_data, "traveller-idle-sides-v1.png", ("left", "right"), 0.46)


def add_traveller_directional_idle(actor_data: dict) -> dict:
    reports = [add_traveller_side_idle(actor_data),
               add_traveller_idle_atlas(actor_data, "traveller-idle-front-diagonal-v1.png", ("front_left", "front_right"), 0.38),
               add_traveller_idle_atlas(actor_data, "traveller-idle-rear-v1.png", ("back_left", "back", "back_right"), 0.53)]
    return {"frame_count": sum(r["frame_count"] for r in reports), "atlases": reports}


def validate_pose_metadata(metadata: dict, canvas: list[int], context: str) -> None:
    def point(value: object) -> bool:
        return (
            isinstance(value, list) and len(value) == 2
            and all(type(p) is int and 0 <= p < size for p, size in zip(value, canvas))
        )

    def polygon(value: object) -> bool:
        return isinstance(value, list) and 3 <= len(value) <= 256 and all(point(p) for p in value)

    def eye_rect(value: object) -> bool:
        return (
            isinstance(value, list) and len(value) == 4
            and all(type(v) is int for v in value) and point(value[:2])
            and value[2] > 0 and value[3] > 0
            and value[0] + value[2] <= canvas[0]
            and value[1] + value[3] <= canvas[1]
        )

    for field, values in metadata.items():
        valid = isinstance(values, list) and bool(values) and len(values) <= 256
        if valid and field == "normalized_face_eyes":
            valid = all(eye_rect(rect) for rect in values)
        elif valid and field == "normalized_head_contour":
            valid = polygon(values)
        elif valid and field == "foreground_polygons":
            valid = all(polygon(poly) for poly in values)
        if not valid:
            raise ValueError(f"{context}: invalid {field} coordinates")


def apply_authoring_metadata(manifest: dict) -> None:
    """Restore reviewed metadata only onto the exact source pose it belongs to.

    This sidecar is an authoring input, not runtime data. Missing or stale input
    fails the build before main() can overwrite the live manifest.
    """
    authored = json.loads(AUTHORING.read_text(encoding="utf-8"))
    if not isinstance(authored, dict) or authored.get("schema_version") != 1:
        raise ValueError("animation authoring: expected schema_version 1 object")
    for key in ("outfit_modes", "outfit_required_poses", "coverage_notes"):
        if not isinstance(authored.get(key), dict):
            raise ValueError(f"animation authoring: missing or invalid {key}")
    if any(
        not isinstance(item, str) or mode not in ("palette", "variant")
        for item, mode in authored["outfit_modes"].items()
    ):
        raise ValueError("animation authoring: unknown outfit mode")
    for actor, actions in authored["outfit_required_poses"].items():
        if actor not in ACTORS or not isinstance(actions, dict):
            raise ValueError(f"animation authoring: invalid outfit actor {actor}")
        for action, directions in actions.items():
            if not isinstance(action, str) or not isinstance(directions, dict):
                raise ValueError(f"animation authoring: invalid outfit coverage {actor}/{action}")
            if any(
                not isinstance(direction, str) or type(count) is not int or not 1 <= count <= 256
                for direction, count in directions.items()
            ):
                raise ValueError(f"animation authoring: invalid outfit coverage {actor}/{action}")
    if any(not isinstance(key, str) or not isinstance(value, str) for key, value in authored["coverage_notes"].items()):
        raise ValueError("animation authoring: coverage notes must be strings")
    annotations = authored.get("frame_annotations")
    if not isinstance(annotations, list):
        raise ValueError("animation authoring: frame_annotations must be an array")
    hashes: dict[str, str] = {}
    seen: set[tuple[str, str, str, int]] = set()
    allowed_fields = {"normalized_face_eyes", "normalized_head_contour", "foreground_polygons"}
    for annotation in annotations:
        if not isinstance(annotation, dict):
            raise ValueError("animation authoring: pose annotation must be an object")
        actor, action, direction = (annotation.get(key) for key in ("actor", "action", "direction"))
        context = f"animation authoring {actor}/{action}/{direction}"
        if not all(isinstance(key, str) for key in (actor, action, direction)):
            raise ValueError(f"{context}: expected string pose identity")
        actor_data = manifest["actors"].get(actor, {})
        sequence = actor_data.get(action, {}).get(direction, {})
        if not sequence.get("frames"):
            raise ValueError(f"{context}: missing generated pose sequence")
        for key in ("canvas_size", "reference_size", "feet_baseline"):
            if annotation.get(key) != actor_data.get(key):
                raise ValueError(f"{context}: changed {key}; review annotations")
        source = annotation.get("source", "")
        if not isinstance(source, str) or not source.startswith("res://assets/characters/"):
            raise ValueError(f"{context}: expected character source path")
        path = (ROOT / source.removeprefix("res://")).resolve()
        if not path.is_relative_to((ROOT / "assets/characters").resolve()):
            raise ValueError(f"{context}: source escapes character assets")
        if source not in hashes:
            with path.open("rb") as stream:
                hashes[source] = hashlib.file_digest(stream, "sha256").hexdigest()
        if annotation.get("source_sha256") != hashes[source]:
            raise ValueError(f"{context}: source fingerprint changed; review annotations")
        frames = annotation.get("frames")
        if not isinstance(frames, list) or not frames:
            raise ValueError(f"{context}: expected annotated frames")
        for item in frames:
            index = item.get("index") if isinstance(item, dict) else None
            if type(index) is not int or not 0 <= index < len(sequence["frames"]):
                raise ValueError(f"{context}: invalid frame index {index}")
            identity = (actor, action, direction, index)
            if identity in seen:
                raise ValueError(f"{context}/frame {index}: duplicate annotation")
            seen.add(identity)
            frame = sequence["frames"][index]
            geometry_matches = (
                frame["source"] == source
                and all(item.get(key) == frame.get(key) for key in ("region", "anchors"))
                and item.get("source_scale", 1.0) == frame.get("source_scale", 1.0)
            )
            if not geometry_matches:
                raise ValueError(f"{context}/frame {index}: changed pose geometry; review annotations")
            metadata = item.get("metadata")
            if not isinstance(metadata, dict) or not metadata or metadata.keys() - allowed_fields:
                raise ValueError(f"{context}/frame {index}: unsupported annotation fields")
            validate_pose_metadata(metadata, actor_data["canvas_size"], f"{context}/frame {index}")
            frame.update(copy.deepcopy(metadata))
    # The atlas builder owns bounds, not wardrobe policy or reviewed source
    # coverage. Keep those explicit inputs independent of its generated output.
    manifest["outfit_modes"] = copy.deepcopy(authored["outfit_modes"])
    manifest["outfit_required_poses"] = copy.deepcopy(authored["outfit_required_poses"])
    manifest["coverage_notes"].update(copy.deepcopy(authored["coverage_notes"]))


def add_route_departures(actor_data: dict) -> None:
    """Replay approved whole-body pivots toward the walking side; no new art."""
    actor_data["depart"] = {}
    for direction, settle in actor_data["settle"].items():
        entry = {"fps": settle["fps"], "loop": False,
                 "frames": copy.deepcopy(list(reversed(settle["frames"])))}
        if "frame_durations" in settle:
            entry["frame_durations"] = list(reversed(settle["frame_durations"]))
        actor_data["depart"][direction] = entry


def registered_frame_source(path: Path, sha256: str) -> str:
    with path.open("rb") as stream:
        if hashlib.file_digest(stream, "sha256").hexdigest() != sha256:
            raise ValueError(f"{path.name} changed; review the authored anchors before rebuilding")
    return "res://" + path.relative_to(ROOT).as_posix()


def add_traveller_profile_waves(actor_data: dict) -> dict:
    """Keep the full directional idle posture at both ends of each greeting."""
    for direction, (digest, neutral_head_x, poses) in TRAVELLER_PROFILE_WAVES.items():
        path = ROOT / f"assets/characters/traveller-wave-{direction}-v1.png"
        source = registered_frame_source(path, digest)
        neutral = {
            "source": f"res://assets/characters/idle-stability-v1/{direction}.png",
            "region": [0, 0, 280, 360], "anchors": {"feet": [140, 346], "head": [neutral_head_x, 69]},
            "source_scale": 0.625, "layers": [],
        }
        frames = [
            {"source": source, "region": region, "anchors": {"feet": feet, "head": head},
             "source_scale": 0.30, "layers": []}
            for region, feet, head in poses
        ]
        actor_data["wave"][direction] = {
            "fps": 10, "loop": False, "frame_durations": [0.12, 0.16, 0.24, 0.12, 0.16],
            "frames": [neutral, *frames, copy.deepcopy(neutral)],
        }
    return {"frame_count": sum(len(item[2]) for item in TRAVELLER_PROFILE_WAVES.values())}


def add_traveller_camera_check(actor_data: dict) -> dict:
    source = registered_frame_source(TRAVELLER_CAMERA_CHECK, TRAVELLER_CAMERA_CHECK_SHA256)
    poses = (
        ([315, 89, 274, 526], [137, 518], [146, 8]),
        ([941, 89, 275, 526], [137, 518], [147, 8]),
        ([1567, 89, 275, 526], [137, 518], [146, 8]),
    )
    # Keep the standing figure's 274px height with the same scale for all cels.
    frames = [
        {"source": source, "region": region, "anchors": {"feet": feet, "head": head},
         "source_scale": 274 / (1.6 * 510), "layers": []}
        for region, feet, head in poses
    ]
    actor_data["idle_gesture"] = {"front": {
        "fps": 8, "loop": False, "frame_durations": [0.20, 0.40, 0.28], "frames": frames,
    }}
    return {"source": TRAVELLER_CAMERA_CHECK.relative_to(ROOT).as_posix(), "frame_count": len(frames)}


def add_traveller_footwork(actor_data: dict) -> dict:
    sides = ROOT / "assets/characters/traveller-settle-sides-v1.png"
    compass = ROOT / "assets/characters/traveller-settle-compass-v1.png"
    side_source = registered_frame_source(sides, "79f3f7ea1e9d995a4863aa529237a4ec31f4f41ad9cc950d5bf4f09af9fb7ba8")
    compass_source = registered_frame_source(compass, "4a46baacc2d2fc797bb239c0a4e651c70dce157e1d951e6a25b8e937f8948e9e")
    poses = [("left", side_source, 0, 0, [121, 69]), ("right", side_source, 280, 0, [180, 69])]
    compass_heads = [
        ("front", [157, 72]), ("front_right", [162, 58]), ("back_right", [187, 68]),
        ("back", [145, 63]), ("back_left", [96, 70]), ("front_left", [149, 58]),
    ]
    for index, (direction, head) in enumerate(compass_heads):
        poses.append((direction, compass_source, index % 3 * 280, index // 3 * 360, head))
    departure = ROOT / "assets/characters/traveller-departure-sides-v1.png"
    compass_departure = ROOT / "assets/characters/traveller-departure-compass-v1.png"
    departure_source = registered_frame_source(departure, "37f2821eb2e3b0dd96f93f3e67b625f49b4b75cc41fb5d7314888594e39833f5")
    compass_departure_source = registered_frame_source(compass_departure, "cae71b0312726b93273a264e1a1ae0b937d7e0bb0e3e8177ad4522b005cf5dbf")
    departures = [("left", departure_source, 0, 0, [121, 69]), ("right", departure_source, 280, 0, [180, 69])]
    for index, (direction, head) in enumerate(compass_heads):
        departures.append((direction, compass_departure_source, index % 3 * 280, index // 3 * 360, head))
    pivot = ROOT / "assets/characters/traveller-pivot-sides-v1.png"
    pivot_source = registered_frame_source(pivot, "6d097d4effb872644ba6ce586e9294c81f6d572c196a0dd96f96e6b628538703")
    pivot_frames = [("back", pivot_source, 0, 0, [145, 63]), ("back_right", pivot_source, 280, 0, [187, 68])]
    for action, entries, fps in (("settle", poses, 10), ("depart", departures, 12.5), ("pivot", pivot_frames, 25)):
        actor_data[action] = {}
        for direction, source, x, y, head in entries:
            actor_data[action][direction] = {
                "fps": fps, "loop": False, "frames": [{
                    "source": source, "region": [x, y, 280, 360],
                    "anchors": {"feet": [140, 346], "head": head},
                    "source_scale": 0.625, "layers": [],
                }],
            }
    return {"sources": [file.relative_to(ROOT).as_posix() for file in (sides, compass, departure, compass_departure, pivot)],
            "frame_count": len(poses) + len(departures) + len(pivot_frames)}


def add_traveller_celebration(actor_data: dict) -> dict:
    atlas = ROOT / "assets/characters/traveller-celebration-v1.png"
    source = registered_frame_source(atlas, "960b8825309e58347f9bfe808cd869f92be0904bdbaf7f7021ea4083bd945198")
    frames = [
        {"source": source, "region": [index * 280, 0, 280, 360],
         "anchors": {"feet": [140, 346], "head": [157, 72]},
         "source_scale": 0.625, "layers": []}
        for index in range(5)
    ]
    actor_data["celebrate"] = {"front": {
        "fps": 10, "loop": False, "frames": frames,
        "frame_durations": [0.09, 0.13, 0.22, 0.12, 0.11],
    }}
    return {"frame_count": len(frames)}


def add_traveller_profile_photos(actor_data: dict) -> dict:
    for direction, (digest, height, poses) in TRAVELLER_PROFILE_PHOTOS.items():
        path = ROOT / f"assets/characters/traveller-photograph-{direction}-v1.png"
        source = registered_frame_source(path, digest)
        frames = [
            {"source": source, "region": region, "anchors": {"feet": feet, "head": head},
             "source_scale": 274 / (1.6 * height), "layers": []}
            for region, feet, head in poses
        ]
        actor_data["photograph"][direction] = {
            "fps": 8, "loop": False, "frames": frames, "frame_durations": [0.23, 0.55, 0.28],
        }
    return {"frame_count": sum(len(spec[2]) for spec in TRAVELLER_PROFILE_PHOTOS.values())}


def add_announcer_first_step(actor_data: dict) -> dict:
    """Append the registered short step to each of the two existing pivots."""
    source = registered_frame_source(ANNOUNCER_SIDE_DEPARTURE, ANNOUNCER_DEPARTURE_SHA256)
    poses = {
        "right": ([374, 24, 351, 674], [162, 665], [211, 9], 311 / 1312),
        "left": ([1330, 27, 351, 671], [166, 662], [143, 9], 305 / 1316),
    }
    for direction, (region, feet, head, source_scale) in poses.items():
        entry = actor_data["depart"][direction]
        entry["frames"].append({
            "source": source,
            "region": region, "anchors": {"feet": feet, "head": head},
            "source_scale": source_scale, "layers": [],
        })
        entry["frame_durations"] = [0.10, 0.10, 0.10, 0.04, 0.06]
    return {"source": ANNOUNCER_SIDE_DEPARTURE.relative_to(ROOT).as_posix(), "frame_count": len(poses)}


def add_announcer_stop_landings(actor_data: dict) -> dict:
    landings = {
        "left": (ANNOUNCER_STOP_LANDING, ANNOUNCER_STOP_SHA256,
                 [1088, 123, 369, 668], [188, 660], [146, 9], 308 / 1302),
        "right": (ANNOUNCER_RIGHT_STOP_LANDING, ANNOUNCER_RIGHT_STOP_SHA256,
                  [934, 37, 317, 619], [153, 613], [191, 6], 306 / 1214),
    }
    for direction, (path, digest, region, feet, head, scale) in landings.items():
        entry = actor_data["settle"][direction]
        entry["frames"].insert(0, {
            "source": registered_frame_source(path, digest), "region": region,
            "anchors": {"feet": feet, "head": head}, "source_scale": scale, "layers": [],
        })
        entry["frame_durations"] = [0.06, 0.04, 0.10, 0.10, 0.10]
    return {"sources": [row[0].relative_to(ROOT).as_posix() for row in landings.values()],
            "frame_count": len(landings)}


def build() -> tuple[dict,dict]:
    actors={}; reports={}
    for actor in ACTORS:
        actors[actor],reports[actor]=analyze(actor)
    variant_report=add_traveller_outfit_variant(actors["traveller"])
    reports["traveller"]["variants"]={"outfit-coral":{k:v for k,v in variant_report.items() if k!="frames"}}
    jump_report=add_traveller_jump(actors["traveller"])
    reports["traveller"]["jump_front"]={k:v for k,v in jump_report.items() if k not in ("frames","variant_frames")}
    announcer_walk_report=add_npc_side_action(actors["announcer"], "announcer", ANNOUNCER_SIDE_WALK, 8, ANNOUNCER_SIDE_SCALE)
    reports["announcer"]["walk_side_atlas"]={k:v for k,v in announcer_walk_report.items() if k!="frames"}
    announcer_settle_report=add_npc_side_action(actors["announcer"], "announcer", ANNOUNCER_SIDE_SETTLE, 4, ANNOUNCER_SETTLE_SCALE, fixed_cell_root=True, column_bounds=(48,464,880,1296,1712), action="settle", fps=10, loop=False, return_direction="front")
    reports["announcer"]["settle_side_atlas"]={k:v for k,v in announcer_settle_report.items() if k!="frames"}
    imp_walk_report=add_npc_side_action(actors["imp"], "imp", IMP_SIDE_WALK, 4, IMP_SIDE_SCALE, fixed_cell_root=True)
    reports["imp"]["walk_side_atlas"]={k:v for k,v in imp_walk_report.items() if k!="frames"}
    imp_settle_report=add_npc_side_action(actors["imp"], "imp", IMP_SIDE_SETTLE, 4, IMP_SIDE_SCALE, fixed_cell_root=True, action="settle", fps=10, loop=False, return_direction="front")
    reports["imp"]["settle_side_atlas"]={k:v for k,v in imp_settle_report.items() if k!="frames"}
    ticket_walk_report=add_npc_side_action(actors["ticket"], "ticket", TICKET_SIDE_WALK, 4, TICKET_SIDE_SCALE, fixed_cell_root=True, column_bounds=(48,464,880,1296,1712))
    reports["ticket"]["walk_side_atlas"]={k:v for k,v in ticket_walk_report.items() if k!="frames"}
    ticket_settle_report=add_npc_side_action(actors["ticket"], "ticket", TICKET_SIDE_SETTLE, 4, TICKET_SIDE_SCALE, fixed_cell_root=True, column_bounds=(48,464,880,1296,1712), action="settle", fps=10, loop=False, return_direction="front")
    reports["ticket"]["settle_side_atlas"]={k:v for k,v in ticket_settle_report.items() if k!="frames"}
    # A second independently drawn front view can change head/clothing volume
    # at the idle boundary. End all pivots on the existing exact neutral cel.
    for role in ("ticket", "imp", "announcer"):
        neutral = actors[role]["idle"]["front"]["frames"][0]
        for sequence in actors[role]["settle"].values():
            sequence["frames"][-1] = copy.deepcopy(neutral)
    for role in ("ticket", "imp", "announcer"):
        add_route_departures(actors[role])
    reports["announcer"]["depart_side_atlas"] = add_announcer_first_step(actors["announcer"])
    reports["announcer"]["stop_landing"] = add_announcer_stop_landings(actors["announcer"])
    reports["traveller"]["idle_directional_atlases"] = add_traveller_directional_idle(actors["traveller"])
    reports["traveller"]["wave_side_atlas"] = add_traveller_profile_waves(actors["traveller"])
    reports["traveller"]["camera_check"] = add_traveller_camera_check(actors["traveller"])
    reports["traveller"]["photograph_side_atlas"] = add_traveller_profile_photos(actors["traveller"])
    reports["traveller"]["footwork_atlases"] = add_traveller_footwork(actors["traveller"])
    reports["traveller"]["celebration"] = add_traveller_celebration(actors["traveller"])
    # This builder owns the atlas rows above. Independent seated/catch sources
    # and additional authored directions must survive a complete regeneration.
    if OUT.exists():
        previous = json.loads(OUT.read_text(encoding="utf-8"))
        for actor, actions in previous.get("actors", {}).items():
            if actor not in actors:
                actors[actor] = actions
                continue
            for action, directions in actions.items():
                if action not in actors[actor]:
                    actors[actor][action] = directions
                elif isinstance(directions, dict) and isinstance(actors[actor][action], dict):
                    for direction, entry in directions.items():
                        actors[actor][action].setdefault(direction, entry)
    manifest={"schema_version":1,"description":"Regions are alpha-trimmed per frame after row/column gutters are detected from the source-wide alpha>128 projection. Feet use shoe contacts in the bottom eight primary-alpha rows; head uses the central upper silhouette. Weak-alpha anti-alias fringes receive a 2px pad. Optional source_scale is a finite 0.01–4 per-frame multiplier on the shared actor/reference scale, never a per-frame bounds fit. The traveller jump action retains a shared atlas-row baseline so its authored airborne height is preserved. No frame is mirrored, copied, or synthetically padded.","runtime_aliases":{"traveller":{"station_stand":"idle/front/frame_0 (same authored frame; not a separate animation)"},"ticket":{"special":"idle_gesture/front (runtime alias; no duplicate frames)"}},"coverage_notes":{"traveller":TRAVELLER_COVERAGE_NOTE,"traveller_outfit_coral":"Full-pose clothing variant aligned to the 32 traveller front-action frames plus eight jump/front frames; not an independent clothing layer and does not establish all-direction coverage. Footwear/hands remain subject to visual review.","ticket":"Four complete walking poses per side, preserving near/far shorts and anatomical right-side satchel. The older front walk_candidate remains a rejected exploratory row.","imp":"42 authored front cells plus four complete walking poses per side. Side walks retain fixed authored cell roots and shared row ground; no mirroring, limb reconstruction or per-frame autozoom.","announcer":"Side-walk adds four authored profile poses each for right and left from the first four cells per atlas row. Four repeated cells per row are excluded; diagonal and front/back walk directions remain uncovered."},"actors":actors}
    manifest["coverage_notes"]["route_pivots"] = "All three NPCs share exact idle neutral endpoints and reverse the four pivot poses for departure. The announcer adds one short step per side before walking and one landing pose per side before turning."
    apply_authoring_metadata(manifest)
    return manifest,reports

def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__, epilog="Reviewed wardrobe and pose metadata: assets/characters/animation-authoring.json. Source or pose mismatches stop before writing output."); parser.add_argument("--check",action="store_true",help="validate alpha-derived regions and compare the committed manifest"); parser.add_argument("--write",action="store_true",help="write JSON manifest (source PNGs are read-only)")
    parser.add_argument("--side-idle-only", action="store_true", help="update/check only profile idle; preserve separately authored seated/catch actions")
    parser.add_argument("--directional-idle-only", action="store_true", help="update/check all dedicated non-front idle sources while preserving unrelated actions")
    args=parser.parse_args()
    if args.side_idle_only and args.directional_idle_only: parser.error("choose side-idle-only or directional-idle-only")
    if args.side_idle_only or args.directional_idle_only:
        try:
            existing = json.loads(OUT.read_text(encoding="utf-8"))
            actor = {"idle": {}}
            report = add_traveller_directional_idle(actor) if args.directional_idle_only else add_traveller_side_idle(actor)
            if args.check:
                for direction in actor["idle"]:
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
            for side_action in ("walk_side_atlas", "settle_side_atlas"):
                side_walk=report.get(side_action)
                if not side_walk: continue
                if side_walk["frame_count"] != 8 or side_walk["registered_frames_per_direction"] != 4 or (actor=="announcer" and side_action=="walk_side_atlas" and not side_walk["repeated_cells_excluded"]): failures.append(f"{actor}: expected four unique authored side-action frames per direction")
                if side_walk["primary_alpha_boundary_hits"]: failures.append(f"{actor} side-walk: {side_walk['primary_alpha_boundary_hits']} strong silhouettes touch split")
                if min(side_walk["canonical_margins_min_px"].values()) <= 2: failures.append(f"{actor} side-walk: strong-alpha margin is 2px or less")
                if min(side_walk["canonical_aa_margins_min_px"].values()) < 0: failures.append(f"{actor} side-walk: padded weak-alpha bounds exceed canonical canvas")
            print(json.dumps({k:v for k,v in report.items() if k!="frames"},ensure_ascii=False))
        if failures:
            print("FAIL: "+"; ".join(failures),file=sys.stderr); return 1
        verified_regions = sum(
            report["frame_count"] + sum(report.get(action, {}).get("frame_count", 0)
                                        for action in ("walk_side_atlas", "settle_side_atlas", "depart_side_atlas",
                                                       "stop_landing", "wave_side_atlas", "camera_check", "photograph_side_atlas",
                                                       "footwork_atlases", "celebration"))
            for report in reports.values()
        )
        print(f"PASS: {verified_regions} authored regions verified; no synthetic frames")
    if not args.check and not args.write: parser.print_help()
    return 0
if __name__ == "__main__": raise SystemExit(main())
