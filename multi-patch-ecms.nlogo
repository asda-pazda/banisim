globals [ reproductionNoiseSD maxPop shares donations possibleDonations donationRate color-set turnInc 
          maxDonationRate spread-max established? watched-patch w-donations w-possibleDonations report-time smoothing
          av-rel-tol don-rate pop num-strong-cheat num-weak-cheat 
          sum-pop sum-num-weak-cheat sum-num-strong-cheat sum-av-rel-tol sum-don-rate
          av-pop av-num-weak-cheat av-num-strong-cheat av-av-rel-tol av-don-rate ]

turtles-own [tag tolerance skill age store strong-cheater? last-patch random-evolution]
;; tag - is the value of an agent's socially recognisable characteristic
;; tolerance - is the range above and below its own tag which defines which other agents it will donate to 
;; skill - is the kind of nutrition that this agent can harvest
;; age - the age of the agent in simulation ticks, this is not necessary for the simulation but allows the setting of a maximum age if desired
;; store - the amount of energy an agent can store, otherwise some agents accumulate HUGE stores of energy
;; strong-cheater? - whether the agent is of the special kind "strong cheater", any of its offspring will also be strong cheaters
;; last-patch - the patch turtle is living in now

patches-own [foodAvailable sum-patch-pop sum-patch-num-weak-cheat sum-patch-num-strong-cheat deaths mortality av-patch-pop]
;; The energy available on the patch

;;;;;;;;;;;;;;;;;;;;;;;
;;; Setup procedure ;;;
;;;;;;;;;;;;;;;;;;;;;;;
to setup 
  clear-all
  set color-set [red blue lime cyan magenta gray orange violet yellow]
  set maxPop numFood / foodUsageRate
  ifelse maxAge > 0 
    [set turnInc 360 / maxAge]
    [set turnInc 1]
  set maxDonationRate 1 / numPairings
  set spread-max 0.4
  
  if map-chooser = "standard" [
    ask patches [set pcolor white]
  ]
  if map-chooser = "ultra-marine" [
  ;TODO RS: insert map generator / swapper here
  ask patches [set pcolor white]
  ask patches [if pxcor > 3 and pxcor < 6 [set pcolor blue]]
  ask patches [if pxcor = 0 [set pcolor blue]]  
  ask patches [if pxcor = 9 [set pcolor blue]]  
  ask patches [if pycor = 0 [set pcolor blue]] 
  ask patches [if pycor = 8 [set pcolor blue]] 
  ask patches [if pxcor = 2 and pycor < 7 [set pcolor blue]]
  ask patches [if pxcor = 7 and pycor < 7 [set pcolor blue]]
  ask patches [if pxcor > 3 and pxcor < 6 and pycor = 0 [set pcolor white]]
  ;TODO RS END
  ]
  
  set watched-patch patch watched-pxcor watched-pycor
  ask watched-patch [set pcolor grey - 1]
  set established? false
  set report-time 0
  set smoothing 0.2
  set sum-pop 0 set sum-num-weak-cheat  0 set sum-num-strong-cheat  0 set sum-av-rel-tol  0 set sum-don-rate 0
  ;set sum-patch-pop 0 set sum-patch-num-weak-cheat 0 set sum-patch-num-strong-cheat 0 set deaths 0 set mortality 0
  do-attributes
  do-subpopulations
  do-profile
  reset-ticks
  reset-timer
end

;;;;;;;;;;;;;;;;;
;;; Main loop ;;;
;;;;;;;;;;;;;;;;;
to go
  set report-time smoothing * timer + (1 - smoothing) * report-time
  reset-timer
  if maxTime > 0 and ticks >= maxTime [ stop ]
  ;; generate initial newcomers
  if count turtles > stopNewThreshold [set established? true]
  if not established? 
    [ask one-of patches [repeat initialNumNew [ generate-agent ]]]
  ;; random newcomers
  if newRate > 0 
    [ repeat (floor (newRate - random-float newRate)) [ ask one-of patches [generate-agent] ] ]
  ;; and any suitable existing agents reproduce
  ask turtles [
    if (min store >= reproduceVal) [
      hatch-agent 
      set store map [ ? - initialFood ] store
    ]
  ]
  
  ;; scatter the food and share it out
  ask patches [
    generate-food
    ask turtles-here [
      let val (item skill store + item skill shares)
      if val > maxRes [ set val maxRes ]
      set store replace-item skill store val
    ]
  ]
  
  ;; then get agents to share where appropriate
  set donations 0
  set possibleDonations 0
  set w-possibleDonations 0
  set w-donations 0
  ask turtles [ do-sharing ]
;;  ifelse count turtles > 0 and possibleDonations > 0
;;    [ set donationRate donations / possibleDonations ]
;;    [ set donationRate 0 ]

  ;; age, consume food and kill off any unfit agents
  ask turtles [
    set age (age + 1)
    set store map [ ? - foodUsageRate ] store
    set size mean store / 20
    if min store <= 0 [die]
    if maxAge > 0 and age > maxAge [ die ]
    right turnInc
  ]
  
  ;; migrate
  ask turtles with [not strong-cheater?] [
    if random-float 1 < prob-migrate [
      migrate
      turtle-display-settings
;;      set shape "airplane"
;;      move-turtles
    ]
  ]
  
  ask turtles with [strong-cheater?] [
;;    if not dynamic-relocate [stop]
    if random-float 1 < prob-cheater-migrate [
      migrate
      turtle-display-settings
    ]
  ]
  
  ask patches [
    ;show sum-patch-num-weak-cheat
    ask turtles-here with [not strong-cheater?] [;;not moving cheaters
      ;let prawilni count turtles-here with [tolerance != 0] ;; iteracja forem sprawdzajaca kazdy patch po koleji
      ;let czity count turtles-here with [tolerance = 0]
      if not dynamic-relocate [stop] ;; procent czitera - random że się przenosi
      ;if czity / ( czity + prawilni ) > 0.1 [ ;; dodanie statystyki - nie odpytywanie bezpośrednio turtla o jego prywatne sprawy
      if sum-patch-pop = 0 [stop]
      if  sum-patch-num-weak-cheat / sum-patch-pop > 0.1[
        let white-patches PATCHES WITH [ PCOLOR = WHITE ]
        let new-patch ONE-OF white-patches
        if new-patch != last-patch [
          move-to new-patch
          SET last-patch new-patch
        ]
        set shape "airplane"
      ]
    ]
  ]
  ; 0.009 - nie jest traktowany jako cheat - myslę że turtle które mają tolerancję < 0.1 są słabymi cheatami
  
  ask patches [
    ask turtles-here with [tolerance = 0] [
      if not cheater-evolution [stop]
      ;let prawilni count turtles-here with [tolerance != 0] ;; iteracja forem sprawdzajaca kazdy patch po koleji
      ;let czity count turtles-here with [tolerance = 0]
      ;if czity / ( czity + prawilni ) > 0.6 [
      if sum-patch-pop = 0 [stop]
      if sum-patch-num-weak-cheat / sum-patch-pop > 0.6 [
        set random-evolution random-float 1
        if random-evolution > 0.6 [
          set tolerance 0.01 + random-float 0.99
          set shape "face happy"
        ]
      ]
    ]  
  ]
  
  ;; do displays
  do-attributes
  do-subpopulations
  do-profile
  do-stats
  do-patch-stats
  tick
end

to do-patch-stats
  ask patches [
    ;if ticks <= stats-after [stop]
    ;show "spam"
    let stat-time ticks - stats-after
    set deaths sum-patch-pop - count turtles-here
    set sum-patch-pop count turtles-here
    set sum-patch-num-weak-cheat count turtles-here with [tolerance = 0]
    set sum-patch-num-strong-cheat count turtles-here with [strong-cheater?] 
    ;set av-patch-pop sum-patch-pop / stat-time ; problem here
    if av-patch-pop = 0 [stop]
    ;set mortality deaths / av-patch-pop
  ]  
end

to migrate
  let x [pxcor] of patch-here
  let y [pYcor] of patch-here

  let availablePositions []

  ask patch x y [set availablePositions [pcolor] of neighbors]
  
  let my-turtle-list (neighbors)

  let goodPatches 0
  foreach availablePositions 
  [ 
    if ? = white [set goodPatches goodPatches + 1]
  ]
  let newPatch random goodPatches
   
  let counter 0
  ask my-turtle-list
  [ 
    if counter = newPatch
    [
      set x pxcor
      set y pycor 
    ]
    set counter counter + 1
  ]
   
   set xcor x
   set ycor y
   
   ;RS TODO FIX: if patch with wrong color is chosen, retry 
   let wrongSwap 0
   ask patch x y 
   [ 
     if pcolor != white 
     [
        ;show "WTF"
        set wrongSwap 1 
     ]
     
   ]
   if wrongSwap = 1 [ migrate ] 
   ;TODO RS END
   
end


to basic-agent-settings
    set store (n-values numFoodTypes [initialFood])
    set age 0
    set size 0.1
end

;to move-turtles
;  ;; get count of turtles on patch if non-cheats < cheats, make random non-cheat move to another patch
;  if not dynamic-relocate [stop]
;  let grey-patches PATCHES WITH [ PCOLOR = GREY ]
;  ask turtles [
;    let new-patch ONE-OF grey-patches
;    if new-patch != last-patch [
;      jump new-patch
;      SET last-patch new-patch
;      set shape "airplane"
;    ]
;  ]
;end

to turtle-display-settings
    st
    set heading 0
    set size 0.1
    set color item skill color-set
    setxy pxcor + spread pycor + spread
    ifelse strong-cheater? [set color color - 2 set shape "face sad"] [set shape "default"]
end

;; generate a random agent at a patch
to generate-agent
  if pcolor = white [
    sprout 1 [
      basic-agent-settings
      set skill (random numFoodTypes)
      set tolerance (random-float 1) * maxTolerance
      set tag random-float 1
      ifelse random-float 1 < prob-cheater 
      [set strong-cheater? true set tolerance 0] 
      [set strong-cheater? false]
      turtle-display-settings
    ]
  ]
end

to introduce-cheaters
  ask watched-patch [
    sprout numb-cheat [
      basic-agent-settings
      set strong-cheater? true
      set skill (random numFoodTypes)
      set tolerance 0
      set tag random-float 1
      turtle-display-settings
    ]
  ]
end

to change-to-cheater
;;  let chosen-patch one-of patches with [count turtles-here >= numb-cheat]
  let numb-turn min list numb-cheat count [turtles-here] of watched-patch
  if numb-turn > 0 [
    ask n-of numb-turn [turtles-here] of watched-patch [
      set strong-cheater? true
      set tolerance 0
      turtle-display-settings
    ]
  ]
end

to-report spread
  report max list (-1 * spread-max) min list spread-max random-normal 0 (spread-max / 3)
end

;; create an offspring, given parent's tolerance, tag and skill
to hatch-agent
  hatch 1 [
    basic-agent-settings
    if random-float 1 < prob-cheater [set strong-cheater? true]
    if probValMutation > 0 [if random-float 1 < probValMutation [
        set tolerance tolerance + random-normal 0 sdValMutation
        set tag tag + random-normal 0 sdValMutation
    ]]
    if sdReproductionNoise > 0 [
      set tolerance tolerance + random-normal 0 sdReproductionNoise
      set tag tag + random-normal 0 sdReproductionNoise
    ]
    if tolerance < 0 [set tolerance 0]
    if tolerance > maxTolerance [set tolerance maxTolerance]
    if tag < 0 [set tag 0]
    if tag > 1 [set tag 1]
    if probSkillMutation > 0 [if random-float 1 < probSkillMutation [
      set skill random numFoodTypes
      set color item skill color-set
    ]]
    if strong-cheater? [set tolerance 0]
    turtle-display-settings
  ]
end

;; maybe turtle display could be... plotted on a val/tolerance axis, with color being skill, 
;; size being number at that val,tol and no direction?

;; scatter the food randomly amongst the food types
;; and calculate the share each agent should get
to generate-food
  set foodAvailable (n-values numFoodTypes [0])
  ;; why 100 here??
  set foodAvailable map [? + random 100] foodAvailable
  let total sum foodAvailable
  ;; just in case 0 is randomly generated numFoodTypes times
  ;; (it did actually happen in testing!)
  ifelse total = 0 [ generate-food ]
  [
   set foodAvailable map [ ? / total * numFood ] foodAvailable
   let pos 0
   set shares []
   repeat numFoodTypes [
     let val count turtles-here with [ skill = pos ]
     ifelse val = 0
       [set shares lput 0 shares]
       [set shares lput ((item pos foodAvailable) / val) shares]
     set pos pos + 1
   ]
 ]
end

;; agent tries random pairings to share any excess resources
to do-sharing
  if count turtles-here > 1 [
    ;; first determine excess
    let unneeded []
    let pos 0
    repeat numFoodTypes [
      let val item pos store - excessVal
      ifelse val > 0
        [set unneeded lput val unneeded]
        [set unneeded lput 0 unneeded]
      set pos pos + 1
    ]
    ;; if agent has nothing to share, don't go further
    if sum unneeded = 0 [ stop ]
    
    ;; select numPairings partners, and keep the ones that
    ;; lie within tolerance
    let partners []
    repeat numPairings [
      let partner one-of other turtles-here
      let diff ([tag] of partner - tag)
      if diff < 0 [ set diff diff * -1 ]
      if diff < tolerance [set partners fput partner partners]
    ]
    
    if patch-here = watched-patch [set w-possibleDonations w-possibleDonations + numPairings]
    set possibleDonations possibleDonations + numPairings
    ;; if there are any suitable partners, dole out the excess
    ;; and delete from own stores
    let num length partners
    if num > 0 [
      set donations donations + length partners
      if patch-here = watched-patch [set w-donations w-donations + length partners]
      let j 0
      repeat numFoodTypes [
        let val item j store
        set store replace-item j store (val - item j unneeded)
        set j j + 1
      ]
      set unneeded map  [? / num] unneeded
      foreach  partners [ ask ? [take-excess unneeded] ]
    ]
  ]
end

;; incorporate donated resources into own stores
to take-excess [ amounts ]
  let pos 0
  repeat numFoodTypes [
    let tmp item pos store + (item pos amounts) * donationBenefit
    if maxRes > 0 and tmp > maxRes [ set tmp maxRes ]
    set store replace-item pos store tmp
    set pos pos + 1
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; VISUALISATION AND STATS PROCEDURES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to do-stats
  if ticks <= stats-after [stop]
  let stat-time ticks - stats-after
  set sum-pop sum-pop + pop
  set sum-num-weak-cheat  sum-num-weak-cheat + num-weak-cheat 
  set sum-num-strong-cheat  sum-num-strong-cheat + num-strong-cheat 
  set sum-av-rel-tol sum-av-rel-tol + av-rel-tol 
  set sum-don-rate sum-don-rate + don-rate
  set av-pop sum-pop / stat-time
  set av-num-weak-cheat sum-num-weak-cheat  / stat-time
  set av-num-strong-cheat sum-num-strong-cheat / stat-time
  set av-av-rel-tol sum-av-rel-tol / stat-time
  set av-don-rate sum-don-rate / stat-time
end

to do-attributes
  set-current-plot "Agent Attributes" 
  let num (count turtles)
  ifelse num > 0 [
    set-current-plot-pen "av. tolerance" 
    set av-rel-tol (mean [tolerance] of turtles) / maxTolerance
    plot av-rel-tol
  ] [
    set av-rel-tol 0
  ]
  ifelse count turtles > 0 and possibleDonations > 0 [
    set-current-plot-pen "donation rate"
    set don-rate donations / possibleDonations
    plot don-rate
  ] [
    set don-rate 0
  ]
  set pop count turtles
  set num-strong-cheat count turtles with [strong-cheater?]
  set num-weak-cheat count turtles with [tolerance = 0]
end

to do-subpopulations
;;  set-current-plot "Subpopulations"
;;  set-plot-pen-mode 2
;;  let pos 0
;;  repeat numFoodTypes [
;;    let current-set (([turtles-here] of watched-patch) with [skill = pos])
;;    set-plot-pen-color item pos color-set
;;    plot count current-set
;;    set pos pos + 1
;;  ]
;;  set-plot-pen-color black
;;  plot count ([turtles-here] of watched-patch) with [strong-cheater?]
end

;; plot each agent as a line representing its tag +/- tolerance
;; vertical axis is age, with agents evenly spaced between each 
;; age point so that they can be more clearly seen
to do-profile
  if not profile-on? [stop]
  set-current-plot "Tag Profile"
  clear-plot
  set-plot-x-range 0 1
  ifelse maxAge > 0 
    [set-plot-y-range 0 maxAge]
    [set-plot-y-range 0 360]
  let pos 0
  repeat maxAge [
    let current-set ([turtles-here] of watched-patch) with [age = pos]
    let num count current-set
    if num > 0 [
      set current-set [self] of current-set
      let i 0
      foreach current-set [
        ask ? [
          set-plot-pen-color color
          plot-pen-up
          plotxy (tag - tolerance) age + (i / num)
          plot-pen-down
          plotxy (tag + tolerance) age + (i / num)
          if strong-cheater? [ plot-dot i num]
        ]
        set i i + 1
      ]
    ]
    set pos pos + 1
  ]
end

to plot-dot [i num]
  let dot-sizex 0.0025
  let dot-sizey 0.2
  set-plot-pen-color black
  plotxy tag + dot-sizex age + (i / num) 
  plot-pen-down
  plotxy tag + dot-sizex age + (i / num) + dot-sizey
  plotxy tag - dot-sizex age + (i / num) + dot-sizey
  plotxy tag - dot-sizex age + (i / num) - dot-sizey
  plotxy tag + dot-sizex age + (i / num) - dot-sizey
  plotxy tag + dot-sizex age + (i / num) 
  plot-pen-up
end

to-report safeDiv [nm dn]
  if dn = 0 [report 0]
  report nm / dn
end
@#$#@#$#@
GRAPHICS-WINDOW
6
10
611
576
-1
-1
59.5
1
10
1
1
1
0
1
1
1
0
9
0
8
1
1
1
ticks
30.0

BUTTON
817
308
883
341
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
953
308
1016
341
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
886
308
949
341
step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
640
49
812
82
numFood
numFood
0
100
50
5
1
NIL
HORIZONTAL

SLIDER
640
126
812
159
maxRes
maxRes
0
10
7
0.1
1
NIL
HORIZONTAL

SLIDER
640
308
812
341
maxAge
maxAge
0
100
45
1
1
NIL
HORIZONTAL

SLIDER
640
89
812
122
initialFood
initialFood
0
10
1
1
1
NIL
HORIZONTAL

SLIDER
640
163
812
196
foodUsageRate
foodUsageRate
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
640
272
812
305
maxTolerance
maxTolerance
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
641
201
814
234
reproduceVal
reproduceVal
0
10
4
0.5
1
NIL
HORIZONTAL

SLIDER
640
236
812
269
excessVal
excessVal
0
10
5
0.5
1
NIL
HORIZONTAL

PLOT
819
11
1243
300
Agent Attributes
time
proportion of max value
0.0
1000.0
0.0
1.0
true
true
"" ""
PENS
"av. tolerance" 1.0 0 -13345367 true "" ""
"donation rate" 1.0 0 -10899396 true "" ""

SLIDER
640
345
812
378
numFoodTypes
numFoodTypes
0
9
3
1
1
NIL
HORIZONTAL

SLIDER
641
419
813
452
numPairings
numPairings
0
20
6
1
1
NIL
HORIZONTAL

SLIDER
641
455
813
488
donationBenefit
donationBenefit
0
1
0.83
0.01
1
NIL
HORIZONTAL

PLOT
530
675
698
834
Tag Profile
Tag value
Age
0.0
1.0
0.0
50.0
false
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

SLIDER
641
492
813
525
sdValMutation
sdValMutation
0
0.5
0.2
0.01
1
NIL
HORIZONTAL

SLIDER
642
528
814
561
probValMutation
probValMutation
0
0.5
0
0.025
1
NIL
HORIZONTAL

SLIDER
641
11
813
44
maxTime
maxTime
0
100000
10200
100
1
NIL
HORIZONTAL

SLIDER
642
602
814
635
sdReproductionNoise
sdReproductionNoise
0
0.1
0.003
0.0001
1
NIL
HORIZONTAL

PLOT
704
675
999
837
Subpopulations
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"cheaters" 1.0 0 -16777216 true "" "plot count (([turtles-here] of watched-patch) with [strong-cheater?])"
"red" 1.0 0 -2674135 true "" "plot count (([turtles-here] of watched-patch) with [skill = 0])"
"blue" 1.0 0 -13345367 true "" "plot count (([turtles-here] of watched-patch) with [skill = 1])"
"lime" 1.0 0 -13840069 true "" "plot count (([turtles-here] of watched-patch) with [skill = 2])"
"cyan" 1.0 0 -11221820 true "" "plot count (([turtles-here] of watched-patch) with [skill = 3])"

SLIDER
641
564
813
597
probSkillMutation
probSkillMutation
0
0.2
0
0.01
1
NIL
HORIZONTAL

BUTTON
815
350
923
383
Intro Cheat
introduce-cheaters
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
925
350
1020
384
Turn to Cheat
change-to-cheater
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
816
394
988
427
prob-cheater
prob-cheater
0
0.1
0.01
0.001
1
NIL
HORIZONTAL

SLIDER
641
637
813
670
prob-migrate
prob-migrate
0
0.1
0.01
0.001
1
NIL
HORIZONTAL

PLOT
100
675
523
835
Population
time
Number
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"all" 1.0 0 -2674135 true "" "plot count turtles"
"cheaters" 1.0 0 -16777216 true "" "plot count turtles with [strong-cheater?]"
"soft" 1.0 0 -7500403 true "" "plot count turtles with [tolerance = 0]"

INPUTBOX
875
555
925
615
watched-pxcor
9
1
0
Number

INPUTBOX
931
556
981
616
watched-pycor
4
1
0
Number

SLIDER
1118
303
1244
336
initialNumNew
initialNumNew
0
10
3
1
1
NIL
HORIZONTAL

SLIDER
1117
340
1245
373
stopNewThreshold
stopNewThreshold
0
500
500
10
1
NIL
HORIZONTAL

SLIDER
639
380
811
413
newRate
newRate
0
10
0
0.1
1
NIL
HORIZONTAL

TEXTBOX
423
643
643
677
Watched Patch (darker patch) ->
13
0.0
1

PLOT
1005
676
1244
838
Patch Sharing Stats
time
Prop Max
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"donation rate" 1.0 0 -13840069 true "" "ifelse count turtles > 0 and w-possibleDonations > 0 \n     [plot w-donations / w-possibleDonations]\n     [plot 0]"
"av. tolerance" 1.0 0 -13345367 true "" "ask watched-patch [\n  ifelse count turtles-here > 0 \n    [plot (mean [tolerance] of turtles-here) / maxTolerance]\n    [plot 0]\n]"

SLIDER
817
431
989
464
prob-cheater-migrate
prob-cheater-migrate
0
0.1
0.01
0.0025
1
NIL
HORIZONTAL

MONITOR
1136
65
1239
110
Prop Strong Cheat
safeDiv \n  count turtles with [strong-cheater?] \n  count turtles
2
1
11

MONITOR
1136
113
1239
158
Prop Soft Cheat
safeDiv \n  count turtles with [tolerance = 0] \n  count turtles
2
1
11

INPUTBOX
1025
320
1098
380
numb-cheat
20
1
0
Number

SWITCH
820
515
990
548
profile-on?
profile-on?
0
1
-1000

MONITOR
1180
210
1238
255
Pop
count turtles
0
1
11

MONITOR
1165
160
1239
205
Secs/Tick
report-time
2
1
11

INPUTBOX
819
555
874
615
stats-after
1000
1
0
Number

SWITCH
820
475
990
508
dynamic-relocate
dynamic-relocate
1
1
-1000

SWITCH
1005
475
1187
508
cheater-evolution
cheater-evolution
0
1
-1000

CHOOSER
1010
520
1148
565
map-chooser
map-chooser
"standard" "ultra-marine"
0

@#$#@#$#@
## WHAT IS IT?

This model demonstrates how cooperation (sharing) can be achieved through essentially selfish groups. Over time in each patch, groups of symbiotic relationships develop, and eventually collapse again.  However new patches are seeded from other patches so that, on the whole, cooperation is maintained.

This version of the model maintains cooperation even with significant and continual injection of "strong cheaters" as defined in (Shutters and Hales 2012).  It does so using a combination of (a) specialisation of skill (b) tag-based group formation and (c) being part of a mult-patch meta-population.  These use only low-level abilities and could be implemented in quite simple entities.

## HOW IT WORKS

Each agent can harvest food of a single type, but must have stores of all food types in order to survive. Agents within the same patch and similar tag values will share excess resources, giving a means of accessing other resources. Agents who gather enough resources reproduce, propagting their strategies (with some mutation); agents who fail to gather sufficient resources die.  There is a small chance that mutation can occur during reproduction in tags, tolerances and skills.

The world is divided into a number of patches in a 2D grid.  There is a small probability that agents can migrate to other patches (either adjacent ones or random ones based on a parameter).

Strong cheaters can be injected into the population in a number of ways: (a) by setting the probability that any new agent (either born or from outside) becomes a strong cheater (his is a one-way process - they cannot then mutate back again and their offspring are strong cheaters) or (b) by pressing the "Intro Cheat" or "Turn to Cheat" buttons which create/change a number of strong cheater agents in a single patch (determined by num-cheat).

## HOW TO USE IT

Choose settings using the sliders.

Press setup to initialise the model, then "step" for a single step, or "go" for continuous running.

If you want to manually inject cheaters use the the "Intro Cheat" or "Turn to Cheat" buttons.

## PARAMETERS

* maxTime - How many simulation ticks it will run for
* numFood - how much of each kind of food is injected into the world each tick (this is divided equally between patches)
* initialFood - how much of each kind of food new agents are endowed with (if born this is subtracted from the parent)
* maxRes - the most of any kind of food an agent can store (anything more than this is lost)
* foodUsageRate - the life tax subtracted from all agents of each kind of food each tick
* reproduceVal - the minimum amount needed in all kinds of food for reproduction to occur (once a tick whilst this is true)
* excessVal - the amount that triggers donation (if this occurs)
* maxTolerance - the maximum value of tolerances
* maxAge - the maximum age (after which agents die)
* numFoodTypes - how many different food types there are
* newRate - how many new random agents are introduced into the simulation each tick
* numPairings - how many times agents are randomly paired each tick for potential donation
* donationBenefit - the proportion of what is donated that is received by the donee (so food is not created by donation)
* sdValMutation - the standard deviation of the normal noise added to tag and tolerance in the case of mutation
* probValMutation - the probability that tag and tolerance are mutated during birth
* probSkillMutation - probability that the specialist skill is changed curing birth
* sdReproductionNoise - the standard deviation of the normal noise that is added during all births (can be used to ensure no exact tag clones exist)
* prob-migrate - probability a (non-strong-cheater) entity migrates to a neighbouring patch

* prob-cheater - probability that a new entrant (from newRate or a birth) becomes a strong cheater
* prob-cheater-migrate - probability a strong-cheater migrates to a neighbouring patch
* num-cheat - number of cheaters introduced when press "Intro Cheat" or "Turn to Cheat" buttong is pressed

* initialNumNew - how many random new agents are created during initial period in the same patch (until a viable population is first established)
* stopNewThreshold - the threshold above which the initial period (with random new agents as immediately above) cease.  

## THINGS TO NOTICE

Notice that setting maxNumNew to 0 is catastrophic if you have a single patch - some random mutation of the population is essential to re-seed the patch once the population has collapsed. If you have multiple patches is can be set to 0 as seeding occurs from neighbouring patches.  Enough patches makes the chance of simultaneous collaps of populations on all patches neglidgible.

Once mutual donation has started occurring (when there are enough overlapping individuals of each food type) the population takes of and a "tag group" forms.  Eventually this group fails, followed by a short period of non-viability before a new group forms.

## AGENT CHARACTERISTICS

* tag - is the value of an agent's socially recognisable characteristic
* tolerance - is the range above and below its own tag which defines which other agents it will donate to 
* skill - is the kind of nutrition that this agent can harvest
* age - the age of the agent in simulation ticks, this is not necessary for the simulation but allows the setting of a maximum age if desired
* store - the amount of energy an agent can store, otherwise some agents accumulate HUGE stores of energy
* strong-cheater? - whether the agent is of the special kind "strong cheater", any of its offspring will also be strong cheaters

## PATCH CHARACTERISTICS

* foodAvailable - how much of each food is on the patch (added to be general distribution process - see numFood above) and distributed to agents on the patch each tick

## THE GRAPHS, VISUALISATION and MONITORS

The "Tag Profile" is a visualisation of all the individuals that are alive at this instance.  Each individual is represented as a horizontal line, whose centre is at the individual's tag value and whose width is that of its tollerance.  Given enough spare food each individual might donate some of its unneeded food to any other current individuals whose centre (i.e. tag) lies within its width.  The bollour of the individual indicates its skill (i.e. the type of nutrition it can directly harvest).  Clearly to be viable there must be some indivuals of each kind in each viablew tag group.  The horizontal position of the lines indicate the age of the individual.  Individuals of the same age are spread out a little horizontally so they can be seen.

The "Agent Atributes" graph shows the population size, the avereage tollerance of individuals and the rate at which individuals donate to others.

The "Subpopulations" graph shows the number of individuals of each skill type as a seperate line of dots (one colour for each type).  Once a cooperative (i.e. mutally donating) tag group forms you see the population of all types rise and then oscilate with respect of each other until the group eventually collapses again to a situation of non-viability.

The Turtle view is another visualisation of the current population.  Each individual is represented by a seperate turtle their:  x-position being their tag, y-position being their tolerance (up to the maximum value), their colour being their skill type, their size representing the average size of their stores, and the direction indicating their age (from veritcally upwards for age 0 and rotating to the right each time interval until almost vertical again at their maximum age).

Allong the bottom of the screen are a set of graphs etc. for a single patch (the one in slightly darker grey in the world).

## CREDITS AND REFERENCES

This model is at page: http://cfpm.org/models/multi-patch-ecms.html

This model is described in the paper:

Edmonds, B. (2013) Multi-Patch Cooperative Specialists With Tags Can Resist Strong Cheaters. In Rekdalsbakken, W., Bye, R.T. and Zhang, H. (eds), _Proceedings of the 27th European Conference on Modelling and Simulation_ (ECMS 2013), May 2013, Alesund, Norway. European Council for Modelling and Simulation, 900-906. (http://cfpm.org/cpmrep220.html)

It is a multi-patch version of the single-patch version of this model that is described in:

Edmonds, B. (2006) The Emergence of Symbiotic Groups Resulting From Skill-Differentiation and Tags. _Journal of Artificial Societies and Social Simulation_, **9**(1):10. (http://jasss.soc.surrey.ac.uk/9/1/10.html).  

It is tolerant to the continual injection of "strong cheaters" as defined in:

Shutters, S. T. & Hales, D. (2013) Tag-Mediated Altruism is Contingent on How Cheaters Are Defined. _Journal of Artificial Societies and Social Simulation_, **16**(1):4 http://jasss.soc.surrey.ac.uk/16/1/4.html.

This model came out of many discussions with David Hales which started when we were trying to understand a model published as:

Riolo, R. L., Cohen, M. D. and Axelrod, R. (2001) Evolution of cooperation without reciprocity. _Nature_, **411**:441-443.

Our analysis and critique of this model was:

Edmonds, B. and Hales, D. (2003) Replication, Replication and Replication - Some Hard Lessons from Model Alignment.  _Journal of Artificial Societies and Social Simulation_,  **6**(4):11 (http://jasss.soc.surrey.ac.uk/6/4/11.html)

The single-patch model and this multi-patch version are an attempt to produce a model of tag-based cooperation which did not suffer from the defects of the Riolo et al model, but showed genuiine tag-based cooperation.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0.5
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="base" repetitions="2" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>do-stats</final>
    <timeLimit steps="5001"/>
    <metric>av-pop</metric>
    <metric>av-num-strong-cheat</metric>
    <metric>av-num-weak-cheat</metric>
    <metric>av-av-rel-tol</metric>
    <metric>av-don-rate</metric>
    <enumeratedValueSet variable="maxAge">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialNumNew">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxRes">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="watched-pxcor">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numb-cheat">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-cheater">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sdValMutation">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxTolerance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="donationBenefit">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reproduceVal">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numFoodTypes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numFood">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numPairings">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="excessVal">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-cheater-migrate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxTime">
      <value value="5000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probSkillMutation">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probValMutation">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sdReproductionNoise">
      <value value="0.005"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profile-on?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="newRate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stopNewThreshold">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="foodUsageRate">
      <value value="0.17"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="watched-pycor">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialFood">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-migrate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pxcor">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pycor">
      <value value="9"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="vary cheater rate" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>do-stats</final>
    <timeLimit steps="5001"/>
    <metric>av-pop</metric>
    <metric>av-num-strong-cheat</metric>
    <metric>av-num-weak-cheat</metric>
    <metric>av-av-rel-tol</metric>
    <metric>av-don-rate</metric>
    <enumeratedValueSet variable="maxAge">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialNumNew">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxRes">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="watched-pxcor">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numb-cheat">
      <value value="5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="prob-cheater" first="0" step="0.0025" last="0.03"/>
    <enumeratedValueSet variable="sdValMutation">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxTolerance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="donationBenefit">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reproduceVal">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numFoodTypes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numFood">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numPairings">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="excessVal">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-cheater-migrate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxTime">
      <value value="5000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probSkillMutation">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probValMutation">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sdReproductionNoise">
      <value value="0.005"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profile-on?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="newRate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stopNewThreshold">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="foodUsageRate">
      <value value="0.17"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="watched-pycor">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialFood">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-migrate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pxcor">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pycor">
      <value value="9"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="vary pairings" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>do-stats</final>
    <timeLimit steps="5001"/>
    <metric>av-pop</metric>
    <metric>av-num-strong-cheat</metric>
    <metric>av-num-weak-cheat</metric>
    <metric>av-av-rel-tol</metric>
    <metric>av-don-rate</metric>
    <enumeratedValueSet variable="maxAge">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialNumNew">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxRes">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="watched-pxcor">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numb-cheat">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-cheater">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sdValMutation">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxTolerance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="donationBenefit">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reproduceVal">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numFoodTypes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numFood">
      <value value="50"/>
    </enumeratedValueSet>
    <steppedValueSet variable="numPairings" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="excessVal">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-cheater-migrate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxTime">
      <value value="5000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probSkillMutation">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probValMutation">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sdReproductionNoise">
      <value value="0.005"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profile-on?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="newRate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stopNewThreshold">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="foodUsageRate">
      <value value="0.17"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="watched-pycor">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialFood">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-migrate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pxcor">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pycor">
      <value value="9"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="vary donation benefit" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>do-stats</final>
    <timeLimit steps="5001"/>
    <metric>av-pop</metric>
    <metric>av-num-strong-cheat</metric>
    <metric>av-num-weak-cheat</metric>
    <metric>av-av-rel-tol</metric>
    <metric>av-don-rate</metric>
    <enumeratedValueSet variable="maxAge">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialNumNew">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxRes">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="watched-pxcor">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numb-cheat">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-cheater">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sdValMutation">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxTolerance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="donationBenefit" first="0.5" step="0.1" last="1.1"/>
    <enumeratedValueSet variable="reproduceVal">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numFoodTypes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numFood">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numPairings">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="excessVal">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-cheater-migrate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxTime">
      <value value="5000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probSkillMutation">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probValMutation">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sdReproductionNoise">
      <value value="0.005"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profile-on?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="newRate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stopNewThreshold">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="foodUsageRate">
      <value value="0.17"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="watched-pycor">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialFood">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-migrate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pxcor">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pycor">
      <value value="9"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="different sizes w and wo cheaters" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>do-stats</final>
    <timeLimit steps="5001"/>
    <metric>av-pop</metric>
    <metric>av-num-strong-cheat</metric>
    <metric>av-num-weak-cheat</metric>
    <metric>av-av-rel-tol</metric>
    <metric>av-don-rate</metric>
    <enumeratedValueSet variable="maxAge">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialNumNew">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxRes">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="watched-pxcor">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numb-cheat">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-cheater">
      <value value="0"/>
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sdValMutation">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxTolerance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="donationBenefit">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reproduceVal">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numFoodTypes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numFood">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numPairings">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="excessVal">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-cheater-migrate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxTime">
      <value value="5000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probSkillMutation">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probValMutation">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sdReproductionNoise">
      <value value="0.005"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profile-on?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="newRate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stopNewThreshold">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="foodUsageRate">
      <value value="0.17"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="watched-pycor">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialFood">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-migrate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <steppedValueSet variable="max-pxcor" first="0" step="2" last="9"/>
    <steppedValueSet variable="max-pycor" first="0" step="2" last="9"/>
  </experiment>
  <experiment name="vary pairings - 0%" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>do-stats</final>
    <timeLimit steps="5001"/>
    <metric>av-pop</metric>
    <metric>av-num-strong-cheat</metric>
    <metric>av-num-weak-cheat</metric>
    <metric>av-av-rel-tol</metric>
    <metric>av-don-rate</metric>
    <enumeratedValueSet variable="maxAge">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialNumNew">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxRes">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="watched-pxcor">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numb-cheat">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-cheater">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sdValMutation">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxTolerance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="donationBenefit">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reproduceVal">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numFoodTypes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numFood">
      <value value="50"/>
    </enumeratedValueSet>
    <steppedValueSet variable="numPairings" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="excessVal">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-cheater-migrate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxTime">
      <value value="5000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probSkillMutation">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probValMutation">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sdReproductionNoise">
      <value value="0.005"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profile-on?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="newRate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stopNewThreshold">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="foodUsageRate">
      <value value="0.17"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="watched-pycor">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialFood">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-migrate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pxcor">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pycor">
      <value value="9"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="vary donation benefit - 0%" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>do-stats</final>
    <timeLimit steps="5001"/>
    <metric>av-pop</metric>
    <metric>av-num-strong-cheat</metric>
    <metric>av-num-weak-cheat</metric>
    <metric>av-av-rel-tol</metric>
    <metric>av-don-rate</metric>
    <enumeratedValueSet variable="maxAge">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialNumNew">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxRes">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="watched-pxcor">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numb-cheat">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-cheater">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sdValMutation">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxTolerance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="donationBenefit" first="0.5" step="0.1" last="1.1"/>
    <enumeratedValueSet variable="reproduceVal">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numFoodTypes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numFood">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numPairings">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="excessVal">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-cheater-migrate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxTime">
      <value value="5000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probSkillMutation">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probValMutation">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sdReproductionNoise">
      <value value="0.005"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profile-on?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="newRate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stopNewThreshold">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="foodUsageRate">
      <value value="0.17"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="watched-pycor">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialFood">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-migrate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pxcor">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pycor">
      <value value="9"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
1
@#$#@#$#@
