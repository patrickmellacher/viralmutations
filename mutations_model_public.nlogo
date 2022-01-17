; TERMS OF USE:
; Copyright (c) 2022 Patrick Mellacher

; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:

; 1.) The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.

; 2.) Any publication that contains results from this code (or significant portions) must cite the following publication:
; Mellacher, Patrick (2022). Endogenous viral mutations, evolutionary selection, and containment policy design. Journal of Economic Interaction and Coordination. https://doi.org/10.1007/s11403-021-00344-3

; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHOR OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.

;agent types
 breed [people person]
 breed [viruses virus]
 breed [antigenic_clusters antigenic_cluster]


;agent-specific variables
people-own
[
  currently_infected
  infected_time
  immunity
  isolated
  symptomatic
  severity
  incubation_time_target
  latent_time_target
  duration_target
]

viruses-own
[
  respective_antigenic_cluster
  infectiousness
  incubation_time
  latent_time
  symptomatic_chance
  fatality_rate
  duration
  current_carriers
  recovered_carriers
  cumulative_mutations_virus
]

antigenic_clusters-own
[
  current_carriers
  immune_against_parent_cluster
  cumulative_mutations_antigenic_cluster
]

;global variables
globals
[
  infected_agents
  infectious_agents
  human_agents
  deaths
  human_agents_number
  infected_agents_number
  infectious_agents_number
  mean_infectiousness
  mean_incubation_time
  mean_latent_time
  mean_symptomatic_chance
  mean_fatality_rate
  mean_duration
  mean_current_carriers
  mean_recovered_carriers
  viruses_number
  antigenic_clusters_number
  mean_cumulative_mutations_virus
  max_cumulative_mutations_antigenic_cluster
  reinfections
]

;setup procedure: ran at the start of the simulation
to setup
  ;clear the results of any previous simulations
  clear-all
  ;number of agents who are infected
  let to_infect_start ceiling ( start_infected / 100 * people_number)

  ;create human agents
  create-people people_number
  [
    set color green
    set xcor random-xcor
    set ycor random-ycor
    set shape "person"
    set size (world-width * world-height ) / people_number * 2
    set currently_infected []
    set immunity (turtle-set)
  ]

  ;create initial antigenic cluster
  create-antigenic_clusters 1
  [
    ht
    set current_carriers to_infect_start
  ]

  ;create initial virus ("wild type")
  create-viruses 1
  [
    set shape "virus"
    set color red
    set respective_antigenic_cluster one-of antigenic_clusters
    set infectiousness start_infectiousness
    set incubation_time start_incubation_time
    set latent_time start_latent_time
    set symptomatic_chance start_symptomatic_chance
    set fatality_rate start_fatality_rate
    set duration start_duration
    set xcor infectiousness * 10
    set ycor fatality_rate * 10
    set current_carriers to_infect_start
    ht
  ]

  ;are categorized in agent sets ("turtle-set" in order to enhance computational efficiency)
  set human_agents people
  set infected_agents (turtle-set)
  set infectious_agents (turtle-set)

  ;a fraction of human agents are infected with the wild type in order to match the initial number of infected
  let virus_start one-of viruses
  ask n-of to_infect_start human_agents
  [
    set currently_infected virus_start
    set infected_time max (list 0 random [latent_time] of virus_start)
    set infected_agents (turtle-set infected_agents self)
    set incubation_time_target max (list 0 random-normal [incubation_time] of virus_start ([incubation_time] of virus_start * sd_time))
    set latent_time_target max (list 0 random-normal [latent_time] of virus_start ([latent_time] of virus_start * sd_time))
    set duration_target max (list 0 random-normal [duration] of virus_start ([duration] of virus_start * sd_time))
    set severity random-float 1
    set color red
  ]

  update_statistics
  reset-ticks
end

;go procedure: ran during each time step of the simulation
to go
  meet
  process_infection_status
  update_statistics
  tick
end

;governs the interaction patterns of agents; further extensions possible to incorporate network structure
to meet
  ;currently, only "homogeneous mixing" is implemented

    if any? infectious_agents
    [
      ;only social interactions by infectious agents are processed in order to save computational resources
      ;ran for each infectious agent
      ask infectious_agents
      [
        ;only non-isolated agents may infect others
        if isolated = 0
        [
          ;defines those agents, which are met by the infectious agent social contacts for the infectious agent. since "number_contacts" is set to 10, only values such as 0, 10, 20 etc. make sense for "social_distancing".
          let contacts up-to-n-of ( number_contacts * (100 - social_distancing) / 100) other human_agents
          ;possible infections are processed for all social contacts in the procedure "try_to_infect"
          try_to_infect [currently_infected] of self contacts
        ]
      ]
    ]

end

;governs the infections created by the social interactions
to try_to_infect [virus_attacking contacts]
  ;ran for each social contact
  ask contacts
  [
    ;only agents who are not currently infected and are not immune against the respective antigenic cluster are processed
    if member? [respective_antigenic_cluster] of virus_attacking [immunity] of self = false and currently_infected = []
    [
      ;random draw to determine, whether agent becomes infected
      if random-float 1 < ([infectiousness] of virus_attacking  )
      [
        ;random draw to determine, whether a mutation occurs
        if random-float 100 < mutation_chance
        [
          ;create a new mutant in the create_mutant function
          let mutant virus_attacking
          ask virus_attacking
          [
            set mutant create_mutant
          ]
          set virus_attacking mutant
        ]
        ;the agent-specific variable "currently_infected" is set to the virus which has infected this agent (either the original "virus_attacking" or the new mutant)
        set currently_infected virus_attacking
        ;update statistics of virus and antigenic cluster
        ask currently_infected
        [
          set current_carriers current_carriers + 1
          ask respective_antigenic_cluster
          [
            set current_carriers current_carriers + 1
          ]
        ]
        ;update statistics regarding reinfections
        if any? immunity
        [
          set reinfections reinfections + 1
        ]
        ;update the agent set of infected agents
        set infected_agents (turtle-set infected_agents self)

        set color red

        ;set the parameters of the disease
        set infected_time 0
        set severity random-float 1
        set duration_target max (list 0 round ( random-normal [duration] of virus_attacking ([duration] of virus_attacking * sd_time) ))
        set incubation_time_target max (list 0 min (list duration_target round ( random-normal [incubation_time] of virus_attacking ([incubation_time] of virus_attacking * sd_time) )))
        set latent_time_target max (list 0 round ( random-normal [latent_time] of virus_attacking ([latent_time] of virus_attacking * sd_time) ))

      ]
    ]
  ]
end

;agents may move out of the latent time, the incubation time and recover/die
to process_infection_status
  ;ran for each infected agent
  ask infected_agents
  [
    ;"infected_time" is a counter that increases by 1 during each period and describes the agent's transition to the various stages (becoming infectious, becoming symptomatic, recovering/dying)
    set infected_time infected_time + 1

    ;after the latent period, agents become infectious
    if infected_time >= latent_time_target and infected_time < ( latent_time_target + 1)
    [
      set infectious_agents (turtle-set infectious_agents self)
    ]

    ;after the incubation period, agents may become symptomatic (depending on their "severity", as drawn from a uniform distribution [0,1] upon infection
    if infected_time >= incubation_time_target and infected_time < (incubation_time_target + 1)
    [
      if severity >= (1 - [symptomatic_chance] of currently_infected)
      [
        set symptomatic 1

        ;if agents are isolated (or self-isolate) upon showing symptoms, these agents are not able to infect others anymore
        if isolate_symptomatic_agents = true
        [
          set infectious_agents other infectious_agents
        ]
      ]
    ]

    ;after reaching the end of the duration, an agent may either recover (thus becoming immune to viruses belonging to this antigenic cluster) or die
    if infected_time >= duration_target
    [
      ;only the most "serious" infections lead to death
      ifelse severity >= (1 - [fatality_rate] of currently_infected)
      [
        ;if there is any pre-existing immunity to any virus, the fatality chance may be lower.
        let cross_immunity_against_death_individual 0
        if (any? immunity)
        [
          set cross_immunity_against_death_individual cross_immunity_against_death
        ]
         ;only the most "serious" infections lead to death
        ifelse (severity) >= ( 1 - ([fatality_rate] of currently_infected * (100 - cross_immunity_against_death_individual ) / 100))
        [
          ;statistics are updated
          set deaths deaths + 1
          ask currently_infected
          [
            set current_carriers current_carriers - 1
            ask respective_antigenic_cluster
            [
              set current_carriers current_carriers - 1
            ]
          ]
          ;agent dies
          die
        ]
        [
          ;if "cross-protection" sets in, agent recovers
          recover
        ]
      ]
      [
          ;if infection is not "serious" enough, agent recovers
        recover
      ]
    ]
  ]
end

;processes the recovery of agents
to recover
  ;agents become immune against the antigenic cluster to which this virus belongs
  add-immunity  self [respective_antigenic_cluster] of currently_infected

  set color green
  ;update statistics
  set infectious_agents other infectious_agents
  set infected_agents other infected_agents
  ask currently_infected
  [
    set current_carriers current_carriers - 1
    ask respective_antigenic_cluster
    [
      set current_carriers current_carriers - 1
    ]
    set recovered_carriers recovered_carriers + 1
  ]
  ;agents are not infected, symptomatic or isolated anymore
  set currently_infected []
  set infected_time 0
  set symptomatic 0
  set isolated 0
end

;function that creates a new mutant
to-report create_mutant
  let virus_to_report myself ;myself = parent virus
  ;create a new virus
  hatch-viruses 1
  [
    set shape "virus"
    ;no current carriers, later on set to 1 after calling this function
    set current_carriers 0
    set recovered_carriers 0

    ;draw the infectiousness, duration, incubation time, latent time, symptomatic chance and fatality rate for the new virus
    set infectiousness [infectiousness] of myself * (1 + max (list -0.99 random-normal mutation_mean mutation_sd))
    set duration [duration] of myself * (1 + max (list -0.99 random-normal mutation_mean mutation_sd))
    set incubation_time min (list duration [incubation_time] of myself ) * (1 + max (list -0.99 random-normal mutation_mean mutation_sd))
    set latent_time max (list 0 [latent_time] of myself ) * (1 + max (list -0.99 random-normal mutation_mean mutation_sd))
    set symptomatic_chance min (list 1 ([symptomatic_chance] of myself * (1 + max (list -0.99 random-normal mutation_mean mutation_sd))))
    set fatality_rate min (list 1 [fatality_rate] of myself ) * (1 + max (list -0.99 random-normal mutation_mean mutation_sd))

    ;update statistics
    set cumulative_mutations_virus cumulative_mutations_virus + 1
    ;virus is placed on the GUI to reflect infectiousness and fatality rate
    set xcor infectiousness * 10
    set ycor fatality_rate * 10

    ;new virus later on returned by this function
    set virus_to_report self

    ;is the mutation coupled with an antigenic drift?
    let mutant_strain [respective_antigenic_cluster] of myself
    if random-float 100 < new_antigenic_cluster_chance
    [
      hatch-antigenic_clusters 1
      [
        ht
        ;create a link between "parent" and offspring antigenic cluster - important in order to measure antigenic distance
        create-link-with mutant_strain [hide-link]

        ;update statistics
        set cumulative_mutations_antigenic_cluster [cumulative_mutations_antigenic_cluster] of mutant_strain + 1

        ;calculate antigenic distance and account for cross-immunity
        set mutant_strain self
        ask other antigenic_clusters
        [
          ifelse link-neighbor? mutant_strain
          [
            set immune_against_parent_cluster 1
          ]
          [
            set immune_against_parent_cluster 0
          ] ;nw:distance-to mutant_strain
        ]
        ;human agents who are immune to the parent antigenic cluster may become immune against the new one
        ask people with [any? immunity with [immune_against_parent_cluster = 1]]
        [
          if random 100 < mutation_cross_immunity_chance
          [
            set immunity (turtle-set immunity mutant_strain)
          ]
        ]
      ]
    ]
    ;the antigenic cluster of the new virus is set to either the old antigenic cluster or the one created by the antigenic drift
    set respective_antigenic_cluster mutant_strain
  ]
  ;function returns the new virus
  report virus_to_report
end

;recursive function that adds immunity against a specific antigenic cluster
to add-immunity [person_in_question antigenic_cluster_in_question]

  ask person_in_question
  [
    ;immunity against this antigenic cluster is added
    set immunity (turtle-set immunity antigenic_cluster_in_question)

    ;immunity against offsprings/parent antigenic clusters may be added
    ask antigenic_clusters with [link-neighbor? antigenic_cluster_in_question and not member? self [immunity] of myself]
    [
      if random 100 < mutation_cross_immunity_chance
      [
        ;call this function again
        add-immunity myself self
      ]
    ]
  ]

end

;updates relevant statistics
to update_statistics
  ask viruses with [current_carriers = 0]
  [
    die
  ]

  set human_agents_number count human_agents
  set infected_agents_number count infected_agents
  set infectious_agents_number count infectious_agents
  set viruses_number count viruses
  set antigenic_clusters_number count antigenic_clusters
  if viruses_number > 0
  [
    set mean_cumulative_mutations_virus mean [cumulative_mutations_virus] of viruses
  ]
  set max_cumulative_mutations_antigenic_cluster max [cumulative_mutations_antigenic_cluster] of antigenic_clusters

  if infected_agents_number > 0
  [
    set mean_infectiousness sum [infectiousness * current_carriers] of viruses / infected_agents_number
    set mean_incubation_time sum [incubation_time * current_carriers] of viruses / infected_agents_number
    set mean_latent_time sum [latent_time * current_carriers] of viruses / infected_agents_number
    set mean_symptomatic_chance sum [symptomatic_chance * current_carriers] of viruses / infected_agents_number
    set mean_fatality_rate sum [fatality_rate * current_carriers] of viruses / infected_agents_number
    set mean_duration sum [duration * current_carriers] of viruses / infected_agents_number
    set mean_current_carriers sum [current_carriers * current_carriers] of viruses / infected_agents_number
    set mean_recovered_carriers mean [recovered_carriers] of viruses
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
702
84
1081
464
-1
-1
33.73
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
10
0
10
1
1
1
ticks
30.0

INPUTBOX
14
99
140
159
people_number
1000.0
1
0
Number

INPUTBOX
146
100
268
160
number_contacts
10.0
1
0
Number

BUTTON
284
354
350
398
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
355
354
421
398
go
if infected_agents_number > 0\n[\ngo\n]
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
14
168
268
201
start_infected
start_infected
0
100
1.0
1
1
%
HORIZONTAL

PLOT
298
85
689
351
totals
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"set-plot-y-range 0 people_number" ""
PENS
"healthy" 1.0 0 -13840069 true "" "plot human_agents_number - infected_agents_number"
"infected" 1.0 0 -2139308 true "" "plot infected_agents_number"
"infectious" 1.0 0 -8053223 true "" "plot infectious_agents_number"
"deaths" 1.0 0 -16777216 true "" "plot deaths"
"mean recovered" 1.0 0 -13345367 true "" "plot mean_recovered_carriers"

PLOT
282
410
482
560
number of variants
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
"default" 1.0 0 -16777216 true "" "plot viruses_number"

PLOT
283
599
481
749
mean infectiousness
NIL
NIL
0.0
1.0
0.0
0.1
true
false
"" ""
PENS
"infectiousness" 1.0 0 -16777216 true "" "plot mean_infectiousness"

INPUTBOX
10
402
136
462
mutation_mean
0.0
1
0
Number

INPUTBOX
145
402
273
462
mutation_sd
0.05
1
0
Number

SLIDER
11
362
272
395
mutation_chance
mutation_chance
0
100
2.0
1
1
%
HORIZONTAL

SLIDER
8
531
274
564
mutation_cross_immunity_chance
mutation_cross_immunity_chance
0
100
40.0
1
1
%
HORIZONTAL

PLOT
283
762
484
912
mean fatality rate
NIL
NIL
0.0
10.0
0.0
0.02
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean_fatality_rate"

PLOT
491
599
690
749
mean incubation period
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
"default" 1.0 0 -16777216 true "" "plot mean_incubation_time"

PLOT
494
763
694
913
mean latent time
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
"default" 1.0 0 -16777216 true "" "plot mean_latent_time"

PLOT
699
600
899
750
mean symptomatic chance
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean_symptomatic_chance"

PLOT
702
766
902
916
mean duration
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
"default" 1.0 0 -16777216 true "" "plot mean_duration"

SLIDER
10
286
270
319
social_distancing
social_distancing
0
100
0.0
1
1
%
HORIZONTAL

SWITCH
11
249
270
282
isolate_symptomatic_agents
isolate_symptomatic_agents
1
1
-1000

INPUTBOX
8
631
135
691
start_infectiousness
0.0625
1
0
Number

INPUTBOX
140
632
271
692
start_fatality_rate
0.01
1
0
Number

INPUTBOX
8
697
135
757
start_incubation_time
6.0
1
0
Number

INPUTBOX
9
762
136
822
start_latent_time
4.0
1
0
Number

INPUTBOX
140
697
270
757
start_duration
8.0
1
0
Number

INPUTBOX
141
762
270
822
sd_time
0.1
1
0
Number

INPUTBOX
8
828
270
888
start_symptomatic_chance
0.7
1
0
Number

SLIDER
7
496
274
529
new_antigenic_cluster_chance
new_antigenic_cluster_chance
0
100
20.0
1
1
%
HORIZONTAL

SLIDER
8
566
273
599
cross_immunity_against_death
cross_immunity_against_death
0
100
99.0
1
1
%
HORIZONTAL

TEXTBOX
24
82
174
100
initializing conditions
11
0.0
1

TEXTBOX
15
230
268
258
policies (may be changed during simulation run)
11
0.0
1

TEXTBOX
12
609
162
627
characteristics of the wild type
11
0.0
1

TEXTBOX
15
342
165
360
parameters for mutations
11
0.0
1

TEXTBOX
10
479
259
507
parameters for antigenic drifts (immune escape)
11
0.0
1

TEXTBOX
284
575
434
593
properties of the viruses
11
0.0
1

PLOT
489
409
689
559
number of antigenic clusters
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
"default" 1.0 0 -16777216 true "" "plot antigenic_clusters_number"

TEXTBOX
18
10
683
50
(c) Patrick Mellacher 2022 \nplease cite as: Mellacher, Patrick (2022). Endogenous Viral Mutations, Endogenous viral mutations, evolutionary selection, and containment policy design, Journal of Economic Interaction and Coordination. https://doi.org/10.1007/s11403-021-00344-3
11
0.0
1

MONITOR
424
354
481
399
healthy
human_agents_number - infected_agents_number
0
1
11

MONITOR
487
354
545
399
infected
infected_agents_number
17
1
11

MONITOR
551
355
617
400
infectious
infectious_agents_number
17
1
11

MONITOR
624
355
681
400
dead
deaths
17
1
11

BUTTON
796
46
1069
79
show variants (x= infectiousness, y=lethality)
ask viruses\n[\nshow-turtle\n]\nask people\n[\nhide-turtle\n]
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
703
46
789
79
show people
ask viruses\n[\nhide-turtle\n]\nask people\n[\nshow-turtle\n]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
This is the model on which the following paper is based on: https://doi.org/10.1007/s11403-021-00344-3
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

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

virus
false
0
Circle -7500403 true true 75 75 150
Line -7500403 true 150 75 150 45
Line -7500403 true 90 105 60 75
Line -7500403 true 75 150 45 150
Line -7500403 true 105 210 75 240
Line -7500403 true 150 225 150 255
Line -7500403 true 195 210 225 240
Line -7500403 true 225 150 255 150
Line -7500403 true 210 105 240 75
Line -7500403 true 45 90 75 60
Line -7500403 true 135 45 165 45
Line -7500403 true 225 60 255 90
Line -7500403 true 255 135 255 165
Line -7500403 true 210 255 240 225
Line -7500403 true 135 255 165 255
Line -7500403 true 60 225 90 255
Line -7500403 true 45 135 45 165

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="mutations_1" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>deaths</metric>
    <metric>human_agents_number</metric>
    <metric>infected_agents_number</metric>
    <metric>infectious_agents_number</metric>
    <metric>mean_infectiousness</metric>
    <metric>mean_incubation_time</metric>
    <metric>mean_latency_time</metric>
    <metric>mean_symptomatic_chance</metric>
    <metric>mean_fatality_rate</metric>
    <metric>mean_duration</metric>
    <metric>mean_current_carriers</metric>
    <metric>mean_recovered_carriers</metric>
    <metric>viruses_number</metric>
    <metric>antigenic_clusters_number</metric>
    <metric>mean_cumulative_mutations_virus</metric>
    <metric>max_cumulative_mutations_antigenic_cluster</metric>
    <metric>reinfections</metric>
    <steppedValueSet variable="random-seed" first="1" step="1" last="5"/>
    <enumeratedValueSet variable="start_infected">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_chance">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolate_symptomatic_agents">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_distancing" first="0" step="10" last="80"/>
    <enumeratedValueSet variable="cross_immunity_death">
      <value value="90"/>
      <value value="99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_fatality_rate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_latency_time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_duration">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_incubation_time">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new_antigenic_cluster_chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_infectiousness">
      <value value="0.0625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_symptomatic_chance">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_number">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_cross_immunity_chance">
      <value value="0"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sd_time">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mixing">
      <value value="&quot;homogenous mixing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_contacts">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mutations_2" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>deaths</metric>
    <metric>human_agents_number</metric>
    <metric>infected_agents_number</metric>
    <metric>infectious_agents_number</metric>
    <metric>mean_infectiousness</metric>
    <metric>mean_incubation_time</metric>
    <metric>mean_latency_time</metric>
    <metric>mean_symptomatic_chance</metric>
    <metric>mean_fatality_rate</metric>
    <metric>mean_duration</metric>
    <metric>mean_current_carriers</metric>
    <metric>mean_recovered_carriers</metric>
    <metric>viruses_number</metric>
    <metric>antigenic_clusters_number</metric>
    <metric>mean_cumulative_mutations_virus</metric>
    <metric>max_cumulative_mutations_antigenic_cluster</metric>
    <metric>reinfections</metric>
    <steppedValueSet variable="random-seed" first="6" step="1" last="10"/>
    <enumeratedValueSet variable="start_infected">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_chance">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolate_symptomatic_agents">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_distancing" first="0" step="10" last="80"/>
    <enumeratedValueSet variable="cross_immunity_death">
      <value value="90"/>
      <value value="99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_fatality_rate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_latency_time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_duration">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_incubation_time">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new_antigenic_cluster_chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_infectiousness">
      <value value="0.0625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_symptomatic_chance">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_number">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_cross_immunity_chance">
      <value value="0"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sd_time">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mixing">
      <value value="&quot;homogenous mixing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_contacts">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mutations_3" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>deaths</metric>
    <metric>human_agents_number</metric>
    <metric>infected_agents_number</metric>
    <metric>infectious_agents_number</metric>
    <metric>mean_infectiousness</metric>
    <metric>mean_incubation_time</metric>
    <metric>mean_latency_time</metric>
    <metric>mean_symptomatic_chance</metric>
    <metric>mean_fatality_rate</metric>
    <metric>mean_duration</metric>
    <metric>mean_current_carriers</metric>
    <metric>mean_recovered_carriers</metric>
    <metric>viruses_number</metric>
    <metric>antigenic_clusters_number</metric>
    <metric>mean_cumulative_mutations_virus</metric>
    <metric>max_cumulative_mutations_antigenic_cluster</metric>
    <metric>reinfections</metric>
    <steppedValueSet variable="random-seed" first="11" step="1" last="15"/>
    <enumeratedValueSet variable="start_infected">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_chance">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolate_symptomatic_agents">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_distancing" first="0" step="10" last="80"/>
    <enumeratedValueSet variable="cross_immunity_death">
      <value value="90"/>
      <value value="99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_fatality_rate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_latency_time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_duration">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_incubation_time">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new_antigenic_cluster_chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_infectiousness">
      <value value="0.0625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_symptomatic_chance">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_number">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_cross_immunity_chance">
      <value value="0"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sd_time">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mixing">
      <value value="&quot;homogenous mixing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_contacts">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mutations_4" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>deaths</metric>
    <metric>human_agents_number</metric>
    <metric>infected_agents_number</metric>
    <metric>infectious_agents_number</metric>
    <metric>mean_infectiousness</metric>
    <metric>mean_incubation_time</metric>
    <metric>mean_latency_time</metric>
    <metric>mean_symptomatic_chance</metric>
    <metric>mean_fatality_rate</metric>
    <metric>mean_duration</metric>
    <metric>mean_current_carriers</metric>
    <metric>mean_recovered_carriers</metric>
    <metric>viruses_number</metric>
    <metric>antigenic_clusters_number</metric>
    <metric>mean_cumulative_mutations_virus</metric>
    <metric>max_cumulative_mutations_antigenic_cluster</metric>
    <metric>reinfections</metric>
    <steppedValueSet variable="random-seed" first="16" step="1" last="20"/>
    <enumeratedValueSet variable="start_infected">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_chance">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolate_symptomatic_agents">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_distancing" first="0" step="10" last="80"/>
    <enumeratedValueSet variable="cross_immunity_death">
      <value value="90"/>
      <value value="99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_fatality_rate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_latency_time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_duration">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_incubation_time">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new_antigenic_cluster_chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_infectiousness">
      <value value="0.0625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_symptomatic_chance">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_number">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_cross_immunity_chance">
      <value value="0"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sd_time">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mixing">
      <value value="&quot;homogenous mixing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_contacts">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mutations_5" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>deaths</metric>
    <metric>human_agents_number</metric>
    <metric>infected_agents_number</metric>
    <metric>infectious_agents_number</metric>
    <metric>mean_infectiousness</metric>
    <metric>mean_incubation_time</metric>
    <metric>mean_latency_time</metric>
    <metric>mean_symptomatic_chance</metric>
    <metric>mean_fatality_rate</metric>
    <metric>mean_duration</metric>
    <metric>mean_current_carriers</metric>
    <metric>mean_recovered_carriers</metric>
    <metric>viruses_number</metric>
    <metric>antigenic_clusters_number</metric>
    <metric>mean_cumulative_mutations_virus</metric>
    <metric>max_cumulative_mutations_antigenic_cluster</metric>
    <metric>reinfections</metric>
    <steppedValueSet variable="random-seed" first="21" step="1" last="25"/>
    <enumeratedValueSet variable="start_infected">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_chance">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolate_symptomatic_agents">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_distancing" first="0" step="10" last="80"/>
    <enumeratedValueSet variable="cross_immunity_death">
      <value value="90"/>
      <value value="99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_fatality_rate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_latency_time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_duration">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_incubation_time">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new_antigenic_cluster_chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_infectiousness">
      <value value="0.0625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_symptomatic_chance">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_number">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_cross_immunity_chance">
      <value value="0"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sd_time">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mixing">
      <value value="&quot;homogenous mixing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_contacts">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mutations_6" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>deaths</metric>
    <metric>human_agents_number</metric>
    <metric>infected_agents_number</metric>
    <metric>infectious_agents_number</metric>
    <metric>mean_infectiousness</metric>
    <metric>mean_incubation_time</metric>
    <metric>mean_latency_time</metric>
    <metric>mean_symptomatic_chance</metric>
    <metric>mean_fatality_rate</metric>
    <metric>mean_duration</metric>
    <metric>mean_current_carriers</metric>
    <metric>mean_recovered_carriers</metric>
    <metric>viruses_number</metric>
    <metric>antigenic_clusters_number</metric>
    <metric>mean_cumulative_mutations_virus</metric>
    <metric>max_cumulative_mutations_antigenic_cluster</metric>
    <metric>reinfections</metric>
    <steppedValueSet variable="random-seed" first="26" step="1" last="30"/>
    <enumeratedValueSet variable="start_infected">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_chance">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolate_symptomatic_agents">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_distancing" first="0" step="10" last="80"/>
    <enumeratedValueSet variable="cross_immunity_death">
      <value value="90"/>
      <value value="99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_fatality_rate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_latency_time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_duration">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_incubation_time">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new_antigenic_cluster_chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_infectiousness">
      <value value="0.0625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_symptomatic_chance">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_number">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_cross_immunity_chance">
      <value value="0"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sd_time">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mixing">
      <value value="&quot;homogenous mixing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_contacts">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mutations_7" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>deaths</metric>
    <metric>human_agents_number</metric>
    <metric>infected_agents_number</metric>
    <metric>infectious_agents_number</metric>
    <metric>mean_infectiousness</metric>
    <metric>mean_incubation_time</metric>
    <metric>mean_latency_time</metric>
    <metric>mean_symptomatic_chance</metric>
    <metric>mean_fatality_rate</metric>
    <metric>mean_duration</metric>
    <metric>mean_current_carriers</metric>
    <metric>mean_recovered_carriers</metric>
    <metric>viruses_number</metric>
    <metric>antigenic_clusters_number</metric>
    <metric>mean_cumulative_mutations_virus</metric>
    <metric>max_cumulative_mutations_antigenic_cluster</metric>
    <metric>reinfections</metric>
    <steppedValueSet variable="random-seed" first="31" step="1" last="35"/>
    <enumeratedValueSet variable="start_infected">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_chance">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolate_symptomatic_agents">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_distancing" first="0" step="10" last="80"/>
    <enumeratedValueSet variable="cross_immunity_death">
      <value value="90"/>
      <value value="99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_fatality_rate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_latency_time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_duration">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_incubation_time">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new_antigenic_cluster_chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_infectiousness">
      <value value="0.0625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_symptomatic_chance">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_number">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_cross_immunity_chance">
      <value value="0"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sd_time">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mixing">
      <value value="&quot;homogenous mixing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_contacts">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mutations_8" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>deaths</metric>
    <metric>human_agents_number</metric>
    <metric>infected_agents_number</metric>
    <metric>infectious_agents_number</metric>
    <metric>mean_infectiousness</metric>
    <metric>mean_incubation_time</metric>
    <metric>mean_latency_time</metric>
    <metric>mean_symptomatic_chance</metric>
    <metric>mean_fatality_rate</metric>
    <metric>mean_duration</metric>
    <metric>mean_current_carriers</metric>
    <metric>mean_recovered_carriers</metric>
    <metric>viruses_number</metric>
    <metric>antigenic_clusters_number</metric>
    <metric>mean_cumulative_mutations_virus</metric>
    <metric>max_cumulative_mutations_antigenic_cluster</metric>
    <metric>reinfections</metric>
    <steppedValueSet variable="random-seed" first="36" step="1" last="40"/>
    <enumeratedValueSet variable="start_infected">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_chance">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolate_symptomatic_agents">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_distancing" first="0" step="10" last="80"/>
    <enumeratedValueSet variable="cross_immunity_death">
      <value value="90"/>
      <value value="99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_fatality_rate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_latency_time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_duration">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_incubation_time">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new_antigenic_cluster_chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_infectiousness">
      <value value="0.0625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_symptomatic_chance">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_number">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_cross_immunity_chance">
      <value value="0"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sd_time">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mixing">
      <value value="&quot;homogenous mixing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_contacts">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mutations_9" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>deaths</metric>
    <metric>human_agents_number</metric>
    <metric>infected_agents_number</metric>
    <metric>infectious_agents_number</metric>
    <metric>mean_infectiousness</metric>
    <metric>mean_incubation_time</metric>
    <metric>mean_latency_time</metric>
    <metric>mean_symptomatic_chance</metric>
    <metric>mean_fatality_rate</metric>
    <metric>mean_duration</metric>
    <metric>mean_current_carriers</metric>
    <metric>mean_recovered_carriers</metric>
    <metric>viruses_number</metric>
    <metric>antigenic_clusters_number</metric>
    <metric>mean_cumulative_mutations_virus</metric>
    <metric>max_cumulative_mutations_antigenic_cluster</metric>
    <metric>reinfections</metric>
    <steppedValueSet variable="random-seed" first="41" step="1" last="45"/>
    <enumeratedValueSet variable="start_infected">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_chance">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolate_symptomatic_agents">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_distancing" first="0" step="10" last="80"/>
    <enumeratedValueSet variable="cross_immunity_death">
      <value value="90"/>
      <value value="99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_fatality_rate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_latency_time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_duration">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_incubation_time">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new_antigenic_cluster_chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_infectiousness">
      <value value="0.0625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_symptomatic_chance">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_number">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_cross_immunity_chance">
      <value value="0"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sd_time">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mixing">
      <value value="&quot;homogenous mixing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_contacts">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mutations_10" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>deaths</metric>
    <metric>human_agents_number</metric>
    <metric>infected_agents_number</metric>
    <metric>infectious_agents_number</metric>
    <metric>mean_infectiousness</metric>
    <metric>mean_incubation_time</metric>
    <metric>mean_latency_time</metric>
    <metric>mean_symptomatic_chance</metric>
    <metric>mean_fatality_rate</metric>
    <metric>mean_duration</metric>
    <metric>mean_current_carriers</metric>
    <metric>mean_recovered_carriers</metric>
    <metric>viruses_number</metric>
    <metric>antigenic_clusters_number</metric>
    <metric>mean_cumulative_mutations_virus</metric>
    <metric>max_cumulative_mutations_antigenic_cluster</metric>
    <metric>reinfections</metric>
    <steppedValueSet variable="random-seed" first="46" step="1" last="50"/>
    <enumeratedValueSet variable="start_infected">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_chance">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolate_symptomatic_agents">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_distancing" first="0" step="10" last="80"/>
    <enumeratedValueSet variable="cross_immunity_death">
      <value value="90"/>
      <value value="99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_fatality_rate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_latency_time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_duration">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_incubation_time">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new_antigenic_cluster_chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_infectiousness">
      <value value="0.0625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_symptomatic_chance">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_number">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_cross_immunity_chance">
      <value value="0"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sd_time">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mixing">
      <value value="&quot;homogenous mixing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_contacts">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mutations_11" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>deaths</metric>
    <metric>human_agents_number</metric>
    <metric>infected_agents_number</metric>
    <metric>infectious_agents_number</metric>
    <metric>mean_infectiousness</metric>
    <metric>mean_incubation_time</metric>
    <metric>mean_latency_time</metric>
    <metric>mean_symptomatic_chance</metric>
    <metric>mean_fatality_rate</metric>
    <metric>mean_duration</metric>
    <metric>mean_current_carriers</metric>
    <metric>mean_recovered_carriers</metric>
    <metric>viruses_number</metric>
    <metric>antigenic_clusters_number</metric>
    <metric>mean_cumulative_mutations_virus</metric>
    <metric>max_cumulative_mutations_antigenic_cluster</metric>
    <metric>reinfections</metric>
    <steppedValueSet variable="random-seed" first="51" step="1" last="55"/>
    <enumeratedValueSet variable="start_infected">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_chance">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolate_symptomatic_agents">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_distancing" first="0" step="10" last="80"/>
    <enumeratedValueSet variable="cross_immunity_death">
      <value value="90"/>
      <value value="99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_fatality_rate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_latency_time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_duration">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_incubation_time">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new_antigenic_cluster_chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_infectiousness">
      <value value="0.0625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_symptomatic_chance">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_number">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_cross_immunity_chance">
      <value value="0"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sd_time">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mixing">
      <value value="&quot;homogenous mixing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_contacts">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mutations_12" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>deaths</metric>
    <metric>human_agents_number</metric>
    <metric>infected_agents_number</metric>
    <metric>infectious_agents_number</metric>
    <metric>mean_infectiousness</metric>
    <metric>mean_incubation_time</metric>
    <metric>mean_latency_time</metric>
    <metric>mean_symptomatic_chance</metric>
    <metric>mean_fatality_rate</metric>
    <metric>mean_duration</metric>
    <metric>mean_current_carriers</metric>
    <metric>mean_recovered_carriers</metric>
    <metric>viruses_number</metric>
    <metric>antigenic_clusters_number</metric>
    <metric>mean_cumulative_mutations_virus</metric>
    <metric>max_cumulative_mutations_antigenic_cluster</metric>
    <metric>reinfections</metric>
    <steppedValueSet variable="random-seed" first="56" step="1" last="60"/>
    <enumeratedValueSet variable="start_infected">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_chance">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolate_symptomatic_agents">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_distancing" first="0" step="10" last="80"/>
    <enumeratedValueSet variable="cross_immunity_death">
      <value value="90"/>
      <value value="99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_fatality_rate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_latency_time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_duration">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_incubation_time">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new_antigenic_cluster_chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_infectiousness">
      <value value="0.0625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_symptomatic_chance">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_number">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_cross_immunity_chance">
      <value value="0"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sd_time">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mixing">
      <value value="&quot;homogenous mixing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_contacts">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mutations_13" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>deaths</metric>
    <metric>human_agents_number</metric>
    <metric>infected_agents_number</metric>
    <metric>infectious_agents_number</metric>
    <metric>mean_infectiousness</metric>
    <metric>mean_incubation_time</metric>
    <metric>mean_latency_time</metric>
    <metric>mean_symptomatic_chance</metric>
    <metric>mean_fatality_rate</metric>
    <metric>mean_duration</metric>
    <metric>mean_current_carriers</metric>
    <metric>mean_recovered_carriers</metric>
    <metric>viruses_number</metric>
    <metric>antigenic_clusters_number</metric>
    <metric>mean_cumulative_mutations_virus</metric>
    <metric>max_cumulative_mutations_antigenic_cluster</metric>
    <metric>reinfections</metric>
    <steppedValueSet variable="random-seed" first="61" step="1" last="65"/>
    <enumeratedValueSet variable="start_infected">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_chance">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolate_symptomatic_agents">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_distancing" first="0" step="10" last="80"/>
    <enumeratedValueSet variable="cross_immunity_death">
      <value value="90"/>
      <value value="99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_fatality_rate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_latency_time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_duration">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_incubation_time">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new_antigenic_cluster_chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_infectiousness">
      <value value="0.0625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_symptomatic_chance">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_number">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_cross_immunity_chance">
      <value value="0"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sd_time">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mixing">
      <value value="&quot;homogenous mixing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_contacts">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mutations_14" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>deaths</metric>
    <metric>human_agents_number</metric>
    <metric>infected_agents_number</metric>
    <metric>infectious_agents_number</metric>
    <metric>mean_infectiousness</metric>
    <metric>mean_incubation_time</metric>
    <metric>mean_latency_time</metric>
    <metric>mean_symptomatic_chance</metric>
    <metric>mean_fatality_rate</metric>
    <metric>mean_duration</metric>
    <metric>mean_current_carriers</metric>
    <metric>mean_recovered_carriers</metric>
    <metric>viruses_number</metric>
    <metric>antigenic_clusters_number</metric>
    <metric>mean_cumulative_mutations_virus</metric>
    <metric>max_cumulative_mutations_antigenic_cluster</metric>
    <metric>reinfections</metric>
    <steppedValueSet variable="random-seed" first="66" step="1" last="70"/>
    <enumeratedValueSet variable="start_infected">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_chance">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolate_symptomatic_agents">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_distancing" first="0" step="10" last="80"/>
    <enumeratedValueSet variable="cross_immunity_death">
      <value value="90"/>
      <value value="99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_fatality_rate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_latency_time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_duration">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_incubation_time">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new_antigenic_cluster_chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_infectiousness">
      <value value="0.0625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_symptomatic_chance">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_number">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_cross_immunity_chance">
      <value value="0"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sd_time">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mixing">
      <value value="&quot;homogenous mixing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_contacts">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mutations_15" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>deaths</metric>
    <metric>human_agents_number</metric>
    <metric>infected_agents_number</metric>
    <metric>infectious_agents_number</metric>
    <metric>mean_infectiousness</metric>
    <metric>mean_incubation_time</metric>
    <metric>mean_latency_time</metric>
    <metric>mean_symptomatic_chance</metric>
    <metric>mean_fatality_rate</metric>
    <metric>mean_duration</metric>
    <metric>mean_current_carriers</metric>
    <metric>mean_recovered_carriers</metric>
    <metric>viruses_number</metric>
    <metric>antigenic_clusters_number</metric>
    <metric>mean_cumulative_mutations_virus</metric>
    <metric>max_cumulative_mutations_antigenic_cluster</metric>
    <metric>reinfections</metric>
    <steppedValueSet variable="random-seed" first="71" step="1" last="75"/>
    <enumeratedValueSet variable="start_infected">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_chance">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolate_symptomatic_agents">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_distancing" first="0" step="10" last="80"/>
    <enumeratedValueSet variable="cross_immunity_death">
      <value value="90"/>
      <value value="99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_fatality_rate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_latency_time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_duration">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_incubation_time">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new_antigenic_cluster_chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_infectiousness">
      <value value="0.0625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_symptomatic_chance">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_number">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_cross_immunity_chance">
      <value value="0"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sd_time">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mixing">
      <value value="&quot;homogenous mixing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_contacts">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mutations_16" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>deaths</metric>
    <metric>human_agents_number</metric>
    <metric>infected_agents_number</metric>
    <metric>infectious_agents_number</metric>
    <metric>mean_infectiousness</metric>
    <metric>mean_incubation_time</metric>
    <metric>mean_latency_time</metric>
    <metric>mean_symptomatic_chance</metric>
    <metric>mean_fatality_rate</metric>
    <metric>mean_duration</metric>
    <metric>mean_current_carriers</metric>
    <metric>mean_recovered_carriers</metric>
    <metric>viruses_number</metric>
    <metric>antigenic_clusters_number</metric>
    <metric>mean_cumulative_mutations_virus</metric>
    <metric>max_cumulative_mutations_antigenic_cluster</metric>
    <metric>reinfections</metric>
    <steppedValueSet variable="random-seed" first="76" step="1" last="80"/>
    <enumeratedValueSet variable="start_infected">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_chance">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolate_symptomatic_agents">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_distancing" first="0" step="10" last="80"/>
    <enumeratedValueSet variable="cross_immunity_death">
      <value value="90"/>
      <value value="99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_fatality_rate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_latency_time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_duration">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_incubation_time">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new_antigenic_cluster_chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_infectiousness">
      <value value="0.0625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_symptomatic_chance">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_number">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_cross_immunity_chance">
      <value value="0"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sd_time">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mixing">
      <value value="&quot;homogenous mixing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_contacts">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mutations_17" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>deaths</metric>
    <metric>human_agents_number</metric>
    <metric>infected_agents_number</metric>
    <metric>infectious_agents_number</metric>
    <metric>mean_infectiousness</metric>
    <metric>mean_incubation_time</metric>
    <metric>mean_latency_time</metric>
    <metric>mean_symptomatic_chance</metric>
    <metric>mean_fatality_rate</metric>
    <metric>mean_duration</metric>
    <metric>mean_current_carriers</metric>
    <metric>mean_recovered_carriers</metric>
    <metric>viruses_number</metric>
    <metric>antigenic_clusters_number</metric>
    <metric>mean_cumulative_mutations_virus</metric>
    <metric>max_cumulative_mutations_antigenic_cluster</metric>
    <metric>reinfections</metric>
    <steppedValueSet variable="random-seed" first="81" step="1" last="85"/>
    <enumeratedValueSet variable="start_infected">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_chance">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolate_symptomatic_agents">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_distancing" first="0" step="10" last="80"/>
    <enumeratedValueSet variable="cross_immunity_death">
      <value value="90"/>
      <value value="99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_fatality_rate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_latency_time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_duration">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_incubation_time">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new_antigenic_cluster_chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_infectiousness">
      <value value="0.0625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_symptomatic_chance">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_number">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_cross_immunity_chance">
      <value value="0"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sd_time">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mixing">
      <value value="&quot;homogenous mixing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_contacts">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mutations_18" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>deaths</metric>
    <metric>human_agents_number</metric>
    <metric>infected_agents_number</metric>
    <metric>infectious_agents_number</metric>
    <metric>mean_infectiousness</metric>
    <metric>mean_incubation_time</metric>
    <metric>mean_latency_time</metric>
    <metric>mean_symptomatic_chance</metric>
    <metric>mean_fatality_rate</metric>
    <metric>mean_duration</metric>
    <metric>mean_current_carriers</metric>
    <metric>mean_recovered_carriers</metric>
    <metric>viruses_number</metric>
    <metric>antigenic_clusters_number</metric>
    <metric>mean_cumulative_mutations_virus</metric>
    <metric>max_cumulative_mutations_antigenic_cluster</metric>
    <metric>reinfections</metric>
    <steppedValueSet variable="random-seed" first="86" step="1" last="90"/>
    <enumeratedValueSet variable="start_infected">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_chance">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolate_symptomatic_agents">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_distancing" first="0" step="10" last="80"/>
    <enumeratedValueSet variable="cross_immunity_death">
      <value value="90"/>
      <value value="99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_fatality_rate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_latency_time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_duration">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_incubation_time">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new_antigenic_cluster_chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_infectiousness">
      <value value="0.0625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_symptomatic_chance">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_number">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_cross_immunity_chance">
      <value value="0"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sd_time">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mixing">
      <value value="&quot;homogenous mixing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_contacts">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mutations_19" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>deaths</metric>
    <metric>human_agents_number</metric>
    <metric>infected_agents_number</metric>
    <metric>infectious_agents_number</metric>
    <metric>mean_infectiousness</metric>
    <metric>mean_incubation_time</metric>
    <metric>mean_latency_time</metric>
    <metric>mean_symptomatic_chance</metric>
    <metric>mean_fatality_rate</metric>
    <metric>mean_duration</metric>
    <metric>mean_current_carriers</metric>
    <metric>mean_recovered_carriers</metric>
    <metric>viruses_number</metric>
    <metric>antigenic_clusters_number</metric>
    <metric>mean_cumulative_mutations_virus</metric>
    <metric>max_cumulative_mutations_antigenic_cluster</metric>
    <metric>reinfections</metric>
    <steppedValueSet variable="random-seed" first="91" step="1" last="95"/>
    <enumeratedValueSet variable="start_infected">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_chance">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolate_symptomatic_agents">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_distancing" first="0" step="10" last="80"/>
    <enumeratedValueSet variable="cross_immunity_death">
      <value value="90"/>
      <value value="99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_fatality_rate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_latency_time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_duration">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_incubation_time">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new_antigenic_cluster_chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_infectiousness">
      <value value="0.0625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_symptomatic_chance">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_number">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_cross_immunity_chance">
      <value value="0"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sd_time">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mixing">
      <value value="&quot;homogenous mixing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_contacts">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mutations_20" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>deaths</metric>
    <metric>human_agents_number</metric>
    <metric>infected_agents_number</metric>
    <metric>infectious_agents_number</metric>
    <metric>mean_infectiousness</metric>
    <metric>mean_incubation_time</metric>
    <metric>mean_latency_time</metric>
    <metric>mean_symptomatic_chance</metric>
    <metric>mean_fatality_rate</metric>
    <metric>mean_duration</metric>
    <metric>mean_current_carriers</metric>
    <metric>mean_recovered_carriers</metric>
    <metric>viruses_number</metric>
    <metric>antigenic_clusters_number</metric>
    <metric>mean_cumulative_mutations_virus</metric>
    <metric>max_cumulative_mutations_antigenic_cluster</metric>
    <metric>reinfections</metric>
    <steppedValueSet variable="random-seed" first="96" step="1" last="100"/>
    <enumeratedValueSet variable="start_infected">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_chance">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolate_symptomatic_agents">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_distancing" first="0" step="10" last="80"/>
    <enumeratedValueSet variable="cross_immunity_death">
      <value value="90"/>
      <value value="99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_fatality_rate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_latency_time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_duration">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_incubation_time">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new_antigenic_cluster_chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_infectiousness">
      <value value="0.0625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start_symptomatic_chance">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_number">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_cross_immunity_chance">
      <value value="0"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sd_time">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation_mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mixing">
      <value value="&quot;homogenous mixing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_contacts">
      <value value="10"/>
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
0
@#$#@#$#@
