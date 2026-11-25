extends RefCounted
## 2026-11-19 Claude: 清溪村 calendar. The village clock already runs a full day in about
## 4 real minutes (center.gd: center_hour += dt*0.1). Each time it passes midnight the day
## count goes up; DAYS_PER_SEASON days make a season, four seasons a year.
## Stored in the save as sim.data.calendar = {"day": int}. Day 0 = spring, day 1.
## Rice (paddies.gd): spring = plant, summer = grow, autumn = harvest, winter = frozen.
## F5 in the village jumps to the next season (test key, like F6–F10).
const NAMES=["春","夏","秋","冬"]
const LONG=["春季","夏季","秋季","冬季"]
const DAYS_PER_SEASON=7
static func season(day:int)->int:return int(day/DAYS_PER_SEASON)%4
static func day_in_season(day:int)->int:return day%DAYS_PER_SEASON+1
## 0..1 through the current season, counting the hour too, so things change smoothly.
static func progress(day:int,hour:float)->float:
 return clampf((float(day%DAYS_PER_SEASON)+clampf(hour,0,24)/24.0)/DAYS_PER_SEASON,0,1)
static func label(day:int)->String:return "%s · 第%d天"%[NAMES[season(day)],day_in_season(day)]
static func calendar(data:Dictionary)->Dictionary:
 if not data.has("calendar") or not data.calendar is Dictionary:data.calendar={"day":0}
 return data.calendar
