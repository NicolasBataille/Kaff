#!/usr/bin/env python3
"""Génère les figures explicatives du README (SVG + PNG) à partir du modèle de Kaff.

Mêmes constantes que `Packages/KaffCore` : ka = 5 h⁻¹, t½ = 5 h par défaut, limite de pic
= 200 mg × peakFraction, coucher 35 mg (élevé à 60 %), journée 400 mg (élevé à 75 %).
Usage : `make figures` (ou `python3 docs/figures/make_figures.py`). Dépendance : matplotlib.
"""
from __future__ import annotations

import math
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Rectangle  # noqa: E402

OUT = Path(__file__).parent

# --- Constantes du modèle (PharmacokineticModel, UserProfile.default, LevelAssessor) -------------
KA = 5.0                       # h⁻¹
HALF_LIFE = 5.0                # h
DAILY_LIMIT = 400.0            # mg, élevé à 75 %
BEDTIME_LIMIT = 35.0           # mg, « élevé » dès cette valeur (Gardiner 2023)
BEDTIME_HIGH = 100.0           # mg, « trop haut » (EFSA 2015 : 100 mg près du coucher perturbe le sommeil)
SINGLE_DOSE_LIMIT = 200.0      # mg ingérés (3 mg/kg plafonné)
ELEVATED = {"peak": 0.6, "daily": 0.75, "bedtime": BEDTIME_LIMIT / BEDTIME_HIGH}   # coucher : 35 / 100
BEDTIME_H = 23.0

# --- Palette (KaffUI/Theme.swift) --------------------------------------------------------------
ACCENT = "#C8792B"
OK, ELEV, HIGH = "#00A88F", "#F28C1A", "#E5372E"
SLEEP = "#5856D6"
INK, MUTED, GRID, PAPER = "#1F1B16", "#7A7168", "#E7E1D8", "#FFFDF9"

plt.rcParams.update({
    "font.family": "sans-serif",
    "font.size": 10,
    "axes.edgecolor": MUTED,
    "axes.labelcolor": INK,
    "xtick.color": MUTED,
    "ytick.color": MUTED,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "figure.facecolor": PAPER,
    "axes.facecolor": PAPER,
    "savefig.facecolor": PAPER,
})


def ke(half_life: float = HALF_LIFE) -> float:
    return math.log(2) / half_life


def amount(dose: float, t: float, half_life: float = HALF_LIFE) -> float:
    """A(t) de Bateman, mg restant `t` heures après une dose `dose`."""
    if t <= 0 or dose <= 0:
        return 0.0
    k = ke(half_life)
    return dose * KA / (KA - k) * (math.exp(-k * t) - math.exp(-KA * t))


def tmax(half_life: float = HALF_LIFE) -> float:
    k = ke(half_life)
    return math.log(KA / k) / (KA - k)


def peak_fraction(half_life: float = HALF_LIFE) -> float:
    return amount(1, tmax(half_life), half_life)


PEAK_LIMIT = SINGLE_DOSE_LIMIT * peak_fraction()   # ≈ 180,6 mg


def total(doses: list[tuple[float, float]], t: float) -> float:
    return sum(amount(mg, t - t0) for t0, mg in doses)


def status(value: float, limit: float, elevated_at: float) -> int:
    ratio = value / limit
    return 2 if ratio >= 1 else 1 if ratio >= elevated_at else 0


def bedtime_status(projected: float) -> int:
    """Même règle que `LevelAssessor.bedtimeStatus` : ok < 35 mg, élevé dès 35, trop haut dès 100."""
    return 2 if projected >= BEDTIME_HIGH else 1 if projected >= BEDTIME_LIMIT else 0


STATUS_COLOR = {0: OK, 1: ELEV, 2: HIGH}
STATUS_NAME = {0: "OK", 1: "élevé", 2: "trop haut"}


def hhmm(t: float) -> str:
    t %= 24
    return f"{int(t):02d}:{int(round((t - int(t)) * 60)):02d}"


def save(fig, name: str) -> None:
    fig.savefig(OUT / f"{name}.svg", bbox_inches="tight")
    fig.savefig(OUT / f"{name}.png", dpi=200, bbox_inches="tight")
    plt.close(fig)
    print("écrit", name)


def frange(a: float, b: float, step: float) -> list[float]:
    n = int(round((b - a) / step))
    return [a + i * step for i in range(n + 1)]


# --- Figure 1 : une dose ------------------------------------------------------------------------
def fig_single_dose() -> None:
    dose = 100.0
    ts = frange(0, 12, 0.01)
    ys = [amount(dose, t) for t in ts]
    tp, peak = tmax(), amount(dose, tmax())

    fig, ax = plt.subplots(figsize=(7.2, 3.6))
    ax.fill_between(ts, ys, color=ACCENT, alpha=0.12)
    ax.plot(ts, ys, color=ACCENT, lw=2.4)
    ax.axvline(tp, color=MUTED, ls=":", lw=1)
    ax.plot([tp], [peak], "o", color=ACCENT, ms=7)
    ax.annotate(f"pic ≈ {peak:.0f} mg\n{tp * 60:.0f} min après la prise",
                (tp, peak), xytext=(1.6, 92), color=INK,
                arrowprops=dict(arrowstyle="-", color=MUTED, lw=1))
    for h in (5, 10):
        a = amount(dose, h)
        ax.plot([h], [a], "o", color=INK, ms=4)
        ax.annotate(f"{a:.0f} mg à {h} h", (h, a), xytext=(h + 0.3, a + 7), color=INK)
    ax.annotate("", xy=(10, 16), xytext=(5, 16), arrowprops=dict(arrowstyle="<->", color=MUTED, lw=1))
    ax.text(7.5, 18.5, "une demi-vie (5 h) : moitié moins", ha="center", color=MUTED, fontsize=9)
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 110)
    ax.set_xlabel("heures après la prise")
    ax.set_ylabel("mg dans l'organisme")
    ax.set_title("Une dose de 100 mg : montée rapide, puis décroissance exponentielle", loc="left", color=INK)
    ax.grid(axis="y", color=GRID)
    save(fig, "dose-unique")


# --- Figure 2 : une journée type -----------------------------------------------------------------
# Journée type : deux espressos le matin, un thé noir à 16:30 → ≈ 37 mg projetés à 23:00 (élevé dès 35 mg).
DAY = [(7.5, 63.0, "espresso 63 mg"), (9.5, 63.0, "espresso 63 mg"), (16.5, 47.0, "thé noir 47 mg")]


def day_status(t: float) -> tuple[int, str]:
    doses = [(t0, mg) for t0, mg, _ in DAY if t0 <= t]
    peak = status(total(doses, t), PEAK_LIMIT, ELEVATED["peak"])
    daily = status(sum(mg for _, mg in doses), DAILY_LIMIT, ELEVATED["daily"])
    projected = total(doses, max(t, BEDTIME_H))
    bed = bedtime_status(projected)
    worst = max(peak, daily, bed)
    reason = "pic" if peak == worst else "coucher" if bed == worst else "journée"
    return worst, reason if worst else ""


def sleep_ready(doses: list[tuple[float, float]], start: float) -> float:
    t = start
    while total(doses, t) >= BEDTIME_LIMIT and t < start + 72:
        t += 1 / 60
    return t


def fig_day() -> None:
    ts = frange(6, 26, 1 / 60)
    doses = [(t0, mg) for t0, mg, _ in DAY]
    tot = [total(doses, t) for t in ts]

    fig, (band, ax) = plt.subplots(2, 1, figsize=(8.4, 4.6), sharex=True,
                                   gridspec_kw=dict(height_ratios=[1, 9], hspace=0.05))
    # bandeau de statut
    band.set_ylim(0, 1)
    band.axis("off")
    prev_t, prev_s = ts[0], day_status(ts[0])
    segments = []
    for t in ts[1:]:
        s = day_status(t)
        if s != prev_s:
            segments.append((prev_t, t, prev_s))
            prev_t, prev_s = t, s
    segments.append((prev_t, ts[-1], prev_s))
    for a, b, (s, reason) in segments:
        band.add_patch(Rectangle((a, 0.15), b - a, 0.7, color=STATUS_COLOR[s], lw=0))
        if b - a > 2.5:
            label = STATUS_NAME[s] + (f" · {reason}" if reason else "")
            band.text((a + b) / 2, 0.5, label, ha="center", va="center", color="white", fontsize=8.5, weight="bold")
    band.set_title("Statut affiché au fil de la journée", loc="left", fontsize=10, color=INK)

    # courbes
    for t0, mg, label in DAY:
        ax.plot(ts, [amount(mg, t - t0) for t in ts], color=ACCENT, lw=1, ls="--", alpha=0.6)
        ax.annotate(label, (t0, 0), xytext=(t0 + 0.15, 4), color=MUTED, fontsize=8.5, rotation=90, va="bottom",
                    bbox=dict(boxstyle="round,pad=0.15", fc=PAPER, ec="none", alpha=0.85))
        ax.plot([t0], [0], "v", color=ACCENT, ms=7, clip_on=False)
    ax.plot(ts, tot, color=ACCENT, lw=2.4, label="total dans l'organisme")
    ax.axhline(BEDTIME_LIMIT, color=SLEEP, lw=1, ls="-.")
    ax.text(6.1, BEDTIME_LIMIT + 2, "seuil coucher 35 mg", color=SLEEP, fontsize=8.5)
    ax.axvline(BEDTIME_H, color=SLEEP, lw=1.2)
    ax.text(BEDTIME_H + 0.15, 100, "coucher\n23:00", color=SLEEP, fontsize=8.5, va="top")
    proj = total(doses, BEDTIME_H)
    ax.plot([BEDTIME_H], [proj], "o", color=SLEEP, ms=6)
    ax.annotate(f"{proj:.0f} mg projetés au coucher (≥ 35)\n→ « élevé · coucher » dès le thé",
                (BEDTIME_H, proj), xytext=(16.8, 78), color=SLEEP, fontsize=8.5,
                arrowprops=dict(arrowstyle="-", color=SLEEP, lw=0.8))
    last_peak = DAY[-1][0] + tmax()
    ready = sleep_ready(doses, last_peak)
    ax.plot([ready], [BEDTIME_LIMIT], "*", color=SLEEP, ms=12)
    ax.annotate(f"« OK pour dormir à {hhmm(ready)} »\n(le statut coucher redevient OK)", (ready, BEDTIME_LIMIT), xytext=(18.3, 12),
                color=SLEEP, fontsize=8.5, arrowprops=dict(arrowstyle="-", color=SLEEP, lw=0.8))
    ax.set_xticks(range(6, 27, 2))
    ax.set_xticklabels([hhmm(h) for h in range(6, 27, 2)])
    ax.set_xlim(6, 26)
    ax.set_ylim(0, 115)
    ax.set_ylabel("mg dans l'organisme")
    ax.grid(axis="y", color=GRID)
    ax.legend(loc="upper right", frameon=False)
    save(fig, "journee-type")


# --- Figure 3 : les trois jauges -----------------------------------------------------------------
def fig_gauges() -> None:
    at = 17.0
    doses = [(t0, mg) for t0, mg, _ in DAY if t0 <= at]
    rows = [
        ("Pic — mg dans l'organisme maintenant", total(doses, at), PEAK_LIMIT, ELEVATED["peak"],
         f"limite {PEAK_LIMIT:.0f} mg = Cmax d'une dose de 200 mg"),
        ("Journée — mg ingérés depuis 04:00", sum(mg for _, mg in doses), DAILY_LIMIT, ELEVATED["daily"],
         "limite 400 mg (EFSA)"),
        ("Coucher — mg projetés à 23:00", total(doses, BEDTIME_H), BEDTIME_HIGH, ELEVATED["bedtime"],
         "élevé dès 35 mg (Gardiner 2023), trop haut dès 100 mg (EFSA)"),
    ]
    fig, axes = plt.subplots(3, 1, figsize=(8.0, 4.2))
    for ax, (title, value, limit, elevated_at, note) in zip(axes, rows):
        ax.barh([0], [elevated_at], color=OK, alpha=0.35, height=0.6)
        ax.barh([0], [1 - elevated_at], left=elevated_at, color=ELEV, alpha=0.35, height=0.6)
        ax.barh([0], [0.25], left=1, color=HIGH, alpha=0.35, height=0.6)
        ratio = value / limit
        s = status(value, limit, elevated_at)
        ax.barh([0], [min(ratio, 1.25)], color=STATUS_COLOR[s], height=0.28)
        ax.text(min(ratio, 1.25) + 0.01, 0, f"{value:.0f} mg · {STATUS_NAME[s]}", va="center", color=INK, fontsize=9, weight="bold")
        ax.set_xlim(0, 1.25)
        ax.set_yticks([])
        ax.set_xticks([0, elevated_at, 1])
        ax.set_xticklabels(["0", f"{elevated_at * limit:.0f} mg", f"{limit:.0f} mg"])
        ax.spines["left"].set_visible(False)
        ax.set_title(f"{title}   ·   {note}", loc="left", fontsize=9.5, color=INK)
    fig.suptitle(f"Les trois questions posées chaque minute (exemple : la journée type à {hhmm(at)})",
                 x=0.02, ha="left", fontsize=10.5, color=INK)
    fig.tight_layout(rect=(0, 0, 1, 0.95))
    save(fig, "trois-seuils")


# --- Figure 4 : demi-vie -------------------------------------------------------------------------
def fig_half_life() -> None:
    ts = frange(0, 16, 0.02)
    fig, ax = plt.subplots(figsize=(7.2, 3.4))
    for hl, color, who in ((3, OK, "fumeur, gros buveur"), (5, ACCENT, "défaut"), (8, SLEEP, "contraception orale")):
        ys = [amount(100, t, hl) for t in ts]
        ax.plot(ts, ys, color=color, lw=2.2, label=f"t½ = {hl} h  ({who})")
        ax.annotate(f"{amount(100, 10, hl):.0f} mg", (10, amount(100, 10, hl)), xytext=(10.2, amount(100, 10, hl) + 4), color=color, fontsize=8.5)
    ax.axvline(10, color=MUTED, ls=":", lw=1)
    ax.axhline(BEDTIME_LIMIT, color=SLEEP, lw=0.8, ls="-.")
    ax.text(0.1, BEDTIME_LIMIT + 2, "seuil coucher 35 mg", color=SLEEP, fontsize=8.5)
    ax.set_xlim(0, 16)
    ax.set_ylim(0, 100)
    ax.set_xlabel("heures après une dose de 100 mg")
    ax.set_ylabel("mg dans l'organisme")
    ax.set_title("La demi-vie change tout : même dose, trois personnes", loc="left", color=INK)
    ax.grid(axis="y", color=GRID)
    ax.legend(frameon=False, loc="upper right")
    save(fig, "demi-vie")


# --- Figure 5 : iso-charge de Gardiner 2023 ---------------------------------------------------------
def fig_gardiner() -> None:
    cases = [(217.5, 13.2, "pré-workout 217,5 mg\n13,2 h avant le coucher", SLEEP, (-12.4, 150)),
             (107.0, 8.8, "café 107 mg\n8,8 h avant le coucher", ACCENT, (-6.6, 44))]
    ts = frange(-14, 0, 0.02)
    fig, ax = plt.subplots(figsize=(7.6, 3.8))
    for dose, lead, label, color, label_xy in cases:
        ys = [amount(dose, t + lead) for t in ts]
        ax.plot(ts, ys, color=color, lw=2.2)
        residual = amount(dose, lead)
        ax.plot([0], [residual], "o", color=color, ms=7)
        ax.annotate(f"{residual:.1f} mg".replace(".", ","), (0, residual),
                    xytext=(0.3, residual + (6 if color == SLEEP else -12)), color=color, fontsize=9, weight="bold")
        ax.text(*label_xy, label, color=color, fontsize=8.5)
    ax.axhline(BEDTIME_LIMIT, color=INK, lw=1, ls="-.")
    ax.text(-13.8, BEDTIME_LIMIT + 5, "→ seuil coucher retenu : 35 mg", color=INK, fontsize=9)
    ax.axvline(0, color=MUTED, lw=1)
    ax.text(0.15, 190, "coucher", color=MUTED, fontsize=9)
    ax.set_xlim(-14, 2.5)
    ax.set_ylim(0, 210)
    ax.set_xlabel("heures avant le coucher")
    ax.set_ylabel("mg dans l'organisme (t½ = 5 h)")
    ax.set_title("Deux cut-offs de la méta-analyse Gardiner 2023 aboutissent à la même charge au coucher",
                 loc="left", color=INK, fontsize=10)
    ax.grid(axis="y", color=GRID)
    save(fig, "gardiner-iso-charge")


# --- Figure 6 : timeline de la complication ---------------------------------------------------------
def fig_widget_timeline() -> None:
    doses = [(13.0, 250.0)]
    start, end = 13.0, 21.0
    ts = frange(start, end, 1 / 60)
    tot = [total(doses, t) for t in ts]

    def st(t: float) -> int:
        return status(total(doses, t), PEAK_LIMIT, ELEVATED["peak"])

    fig, ax = plt.subplots(figsize=(8.0, 3.4))
    ax.plot(ts, tot, color=ACCENT, lw=2.2, label="niveau réel")
    grid = frange(start, end, 0.25)
    ax.plot(grid, [total(doses, t) for t in grid], "o", color=MUTED, ms=3.5, label="entrées toutes les 15 min")
    transitions = [t for a, t in zip(ts, ts[1:]) if st(a) != st(t)]
    ax.plot(transitions, [total(doses, t) for t in transitions], "D", color=HIGH, ms=7,
            label="entrée ajoutée au changement de statut")
    for t in transitions:
        ax.annotate(hhmm(t), (t, total(doses, t)), xytext=(t + 0.1, total(doses, t) + 12), color=HIGH, fontsize=8.5)
    ax.axhline(PEAK_LIMIT, color=HIGH, lw=0.8, ls="-.")
    ax.text(end - 0.1, PEAK_LIMIT - 12, f"limite de pic {PEAK_LIMIT:.0f} mg", color=HIGH, fontsize=8.5, ha="right")
    ax.axhline(PEAK_LIMIT * ELEVATED["peak"], color=ELEV, lw=0.8, ls="-.")
    ax.text(16.2, PEAK_LIMIT * ELEVATED["peak"] + 4, f"élevé dès {PEAK_LIMIT * ELEVATED['peak']:.0f} mg",
            color=ELEV, fontsize=8.5, ha="left")
    ax.set_xticks(range(13, 22))
    ax.set_xticklabels([hhmm(h) for h in range(13, 22)])
    ax.set_ylim(0, 260)
    ax.set_ylabel("mg dans l'organisme")
    ax.set_title("La complication reçoit d'avance toutes ses entrées : 250 mg à 13:00", loc="left", color=INK)
    ax.grid(axis="y", color=GRID)
    ax.legend(frameon=False, loc="upper right", fontsize=8.5)
    save(fig, "timeline-complication")


if __name__ == "__main__":
    print(f"ka={KA} t½={HALF_LIFE} tmax={tmax() * 60:.1f} min peakFraction={peak_fraction():.3f} peakLimit={PEAK_LIMIT:.1f}")
    fig_single_dose()
    fig_day()
    fig_gauges()
    fig_half_life()
    fig_gardiner()
    fig_widget_timeline()
