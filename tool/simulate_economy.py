#!/usr/bin/env python3
"""Economy and pacing simulator for Chai Tapri Tycoon.

Mirrors the formulas of lib/core/economy.dart (keep both in sync) and plays the game with
simple bots, so you can see what a balance change does BEFORE you edit
assets/config/game_config.json.

    python tool/simulate_economy.py                     # uses assets/config/game_config.json
    python tool/simulate_economy.py other_config.json

What it prints
  * the first hour of continuous play (when is the first upgrade, the helper, new menu items),
  * how many days an "engaged" (4 sessions/day, ads) and a "casual" (2 sessions/day) player
    need to reach the maximum level of every upgrade.
The test suite (test/simulation_test.dart) checks the same targets on the real Dart code.
"""
import json, math, sys, copy

def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)

class Eco:
    def __init__(self, cfg):
        self.c = cfg
        self.ups = cfg["upgrades"]
        self.menu = cfg["menu"]
        self.idx = {u["id"]: i for i, u in enumerate(self.ups)}

    def mult(self, i, L):
        u = self.ups[i]
        m = int(L // self.c["milestoneEvery"])
        return (1.0 + u["perLevel"] * L) * (u["milestoneMult"] ** m)

    def cost(self, i, L):
        u = self.ups[i]
        return math.ceil(u["baseCost"] * (u["growth"] ** L))

    def weights(self, unlocked):
        latest = max(i for i, v in enumerate(unlocked) if v)
        w = []
        for i, m in enumerate(self.menu):
            if not unlocked[i]:
                w.append(0.0)
            else:
                w.append(m["weight"] * (self.c["newItemWeightBoost"] if (i == latest and latest > 0) else 1.0))
        return w

    def soft_min(self, a, b):
        p = self.c["softMinPower"]
        return (a ** -p + b ** -p) ** (-1.0 / p)

    def snap(self, levels, unlocked, free_helper=False):
        c = self.c
        w = self.weights(unlocked)
        sw = sum(w)
        avg_price = sum(w[i] * self.menu[i]["price"] for i in range(len(w))) / sw
        avg_brew = c["brew"]["baseSeconds"] * sum(w[i] * self.menu[i]["brewMult"] for i in range(len(w))) / sw
        speed = self.mult(self.idx["chulha"], levels[self.idx["chulha"]])
        batch = self.mult(self.idx["kettle"], levels[self.idx["kettle"]])
        brew_rate = c["brew"]["baseBatchCups"] * batch * speed / avg_brew
        cust_rate = c["customers"]["basePerSecond"] * self.mult(self.idx["seats"], levels[self.idx["seats"]]) * self.mult(self.idx["board"], levels[self.idx["board"]])
        thr = self.soft_min(brew_rate, cust_rate)
        tip = self.ups[self.idx["radio"]]["perLevel"] * levels[self.idx["radio"]]
        R = thr * avg_price * (1.0 + tip)
        hl = levels[self.idx["helper"]]
        if free_helper and hl < 1:
            hl = 1
        hu = self.ups[self.idx["helper"]]
        eff = 0.0 if hl <= 0 else hu["effBase"] + hu["perLevel"] * (hl - 1)
        idle = R * eff
        ref = R * max(eff, hu["effBase"])
        tap = c["tap"]["cups"] * avg_price * (1.0 + tip) + R * c["tap"]["incomeSeconds"]
        return dict(brew=brew_rate, cust=cust_rate, thr=thr, price=avg_price, tip=tip, R=R, eff=eff, idle=idle, ref=ref, tap=tap)

def fmt(x):
    for s, d in (("T", 1e12), ("B", 1e9), ("M", 1e6), ("K", 1e3)):
        if abs(x) >= d:
            return "%.2f%s" % (x / d, s)
    return "%.1f" % x


TAPS_PER_SEC = 3.0

class Player:
    def __init__(self, cfg, mode):
        self.cfg = cfg
        self.e = Eco(cfg)
        self.levels = [0] * len(cfg["upgrades"])
        self.unlocked = [True] + [False] * (len(cfg["menu"]) - 1)
        self.coins = 0.0
        self.t = 0.0                   # seconds since start
        self.mode = mode               # 'active' (continuous play) or 'daily'
        self.log = []                  # (t, text)
        self.spent_ups = 0
        self.first_upgrade_t = None
        self.unlock_t = {}
        self.helper_t = None
        self.max_t = None

    def snap(self):
        return self.e.snap(self.levels, self.unlocked)

    def value(self, s):
        if self.mode == "active":
            return s["idle"] + TAPS_PER_SEC * s["tap"]
        return 0.3 * s["idle"] + 0.05 * TAPS_PER_SEC * s["tap"]

    def options(self):
        opts = []
        for i, u in enumerate(self.cfg["upgrades"]):
            if self.levels[i] < self.cfg["maxLevel"]:
                opts.append(("up", i, self.e.cost(i, self.levels[i])))
        for j, m in enumerate(self.cfg["menu"]):
            if not self.unlocked[j]:
                opts.append(("menu", j, m["unlockCost"]))
                break
        return opts

    def apply(self, opt):
        kind, i, cost = opt
        self.coins -= cost
        if kind == "up":
            self.levels[i] += 1
            if self.first_upgrade_t is None:
                self.first_upgrade_t = self.t
            if self.cfg["upgrades"][i]["id"] == "helper" and self.levels[i] == 1 and self.helper_t is None:
                self.helper_t = self.t
            if all(l >= self.cfg["maxLevel"] for l in self.levels) and self.max_t is None:
                self.max_t = self.t
        else:
            self.unlocked[i] = True
            self.unlock_t[self.cfg["menu"][i]["id"]] = self.t

    def best(self):
        s = self.snap()
        v0 = self.value(s)
        best = None
        for opt in self.options():
            kind, i, cost = opt
            lv = list(self.levels); un = list(self.unlocked)
            if kind == "up":
                lv[i] += 1
            else:
                un[i] = True
            s2 = self.e.snap(lv, un)
            dv = self.value(s2) - v0
            if dv <= 1e-12:
                score = 1e18 + cost
            else:
                wait = max(0.0, cost - self.coins) / max(v0, 1e-9)
                score = cost / dv + wait
            if best is None or score < best[0]:
                best = (score, opt)
        return best[1] if best else None

    def buy_loop(self):
        n = 0
        while n < 50:
            opt = self.best()
            if opt is None or opt[2] > self.coins:
                break
            self.apply(opt)
            n += 1

    def run_active(self, seconds, boost=False, vip_ad=False, vip=True, step=1.0):
        steps = int(seconds / step)
        vip_timer = 240.0
        for _ in range(steps):
            s = self.snap()
            m = self.cfg["boost"]["multiplier"] if boost else 1.0
            self.coins += (s["idle"] + TAPS_PER_SEC * s["tap"]) * m * step
            self.t += step
            vip_timer -= step
            if vip and vip_timer <= 0:
                vip_timer = 240.0
                tipm = 1.0 + self.cfg["upgrades"][5]["vipTipPerLevel"] * self.levels[5]
                self.coins += self.cfg["vip"]["tipSeconds"] * s["ref"] * tipm * (2.0 if vip_ad else 1.0)
            self.buy_loop()

    def offline(self, seconds, ad=False):
        s = self.snap()
        cap = self.cfg["offline"]["capHours"] * 3600
        gain = min(seconds, cap) * s["idle"] * self.cfg["offline"]["efficiency"] * (2.0 if ad else 1.0)
        self.coins += gain
        self.t += seconds
        return gain

    def daily(self, day_idx, ad=False):
        mins = self.cfg["daily"]["rewardMinutes"][day_idx % 7]
        s = self.snap()
        g = max(self.cfg["daily"]["minCoins"], mins * 60 * s["ref"])
        self.coins += g * (2.0 if ad else 1.0)

def first_session(cfg, minutes=60):
    p = Player(cfg, "active")
    p.run_active(minutes * 60, boost=False, vip=False)
    return p

def profile(cfg, sessions_per_day, session_min, ads, days=30, first_min=25, label=""):
    p = Player(cfg, "daily")
    # day 0: first session continuous active (value uses active mode weights)
    p.mode = "active"
    p.run_active(first_min * 60, boost=False, vip=False)
    p.mode = "daily"
    last_end = p.t
    day_marks = {}
    for day in range(days):
        starts = sessions_per_day
        for k, h in enumerate(starts):
            t_start = day * 86400 + h * 3600
            if t_start <= p.t:
                continue
            gap = t_start - p.t
            if gap > 0:
                p.offline(gap, ad=ads and gap > 600)
                p.t = t_start
            if k == 0 or True:
                # first session of the calendar day -> daily reward
                if k == 0:
                    p.daily(day, ad=ads)
            p.run_active(session_min * 60, boost=ads, vip_ad=ads)
        day_marks[day + 1] = (list(p.levels), list(p.unlocked), p.coins)
        if p.max_t is not None and day > 0 and all(l >= cfg["maxLevel"] for l in p.levels):
            break
    return p, day_marks

def report_first(p):
    print("first upgrade at %.0fs" % (p.first_upgrade_t or -1))
    for k, v in p.unlock_t.items():
        print("  unlock %-8s at %.0fs (%.1f min)" % (k, v, v / 60))
    print("  helper L1 at", None if p.helper_t is None else "%.0fs (%.1f min)" % (p.helper_t, p.helper_t / 60))
    s = p.snap()
    print("  end: lv=%s R=%s idle=%s tap=%s coins=%s" % (p.levels, fmt(s["R"]), fmt(s["idle"]), fmt(s["tap"]), fmt(p.coins)))

def report_profile(name, p):
    print("== profile:", name)
    print("  helper L1 day: %.2f" % ((p.helper_t or 0) / 86400))
    for k, v in p.unlock_t.items():
        print("  unlock %-8s at day %.2f" % (k, v / 86400))
    print("  max at day:", None if p.max_t is None else "%.2f" % (p.max_t / 86400))
    print("  levels at end:", p.levels, "t=%.2f days" % (p.t / 86400))

def run_report(cfg):
    p = first_session(cfg, 60)
    print("--- first session (continuous active play) ---")
    report_first(p)
    eng = [8, 13, 18, 22]
    day1_extra = [3, 6, 9, 12, 15, 18, 21]
    def run_profile(per_day_hours, session_min, ads, label, day0_hours=None, days=40):
        pp = Player(cfg, "active")
        pp.run_active(25 * 60, boost=False, vip=False)
        pp.mode = "daily"
        for day in range(days):
            hours = (day0_hours if (day == 0 and day0_hours) else per_day_hours)
            for k, h in enumerate(hours):
                t_start = day * 86400 + h * 3600
                if t_start <= pp.t:
                    continue
                gap = t_start - pp.t
                pp.offline(gap, ad=ads and gap > 600)
                pp.t = t_start
                if k == 0:
                    pp.daily(day, ad=ads)
                pp.run_active(session_min * 60, boost=ads, vip_ad=ads)
            if pp.max_t is not None:
                break
        report_profile(label, pp)
        return pp
    run_profile(eng, 6, True, "engaged (4 sessions, ads)", day0_hours=day1_extra)
    run_profile([9, 20], 5, False, "casual (2 sessions, no ads)")
    run_profile([9, 20], 5, True, "casual with ads (2 sessions)")

if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "assets/config/game_config.json"
    run_report(load(path))
