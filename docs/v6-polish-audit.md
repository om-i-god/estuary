# estuary v6: polish audit

Written place by place from SNAP renders (still, mid, peak, three incidents, a moment, a swell; six consecutive frames at silence and in mid; maps of the pixels that jumped between frames; maps of pixels that toggled a -> b -> a). Each place lists what reads well, the defects found by eye and in the code, and the fix (one line per fix, the after state checked on a re-render).

## Shared (lib/visuals.lua)
Defects found across many places:
- `K.surface` switched each dash on at a threshold and doubled its level at a second one; places drove its gap and row spacing with `floor(nat * n)`, so the whole texture re-laid itself as the water sounds moved (ripples, drift, koi)
- `K.twinkle` and the glitter's halo switched on at a level threshold
- a theme fade scaled every rect by one factor, so all the level-1 texture of a place vanished (or appeared) in a single frame of a theme-cycle edge (a 0.22 mean-level jump in one frame in tide)
- `K.blit` slid a baked layer a whole pixel in one frame (the rain curtain's slanted strokes all hopped together)
- many single-pixel things (birds, fish, reflections) ticked a whole pixel at a time at 20 fps
Fixes:
- `K.surface(..., dens)`: dashes fade in and out with their wave and brighten smoothly on the crest; a density argument thickens it on fixed rows
- `K.ramp(v, a, b)`: a soft threshold for anything that used to switch on as an input crossed a line (used in 20 places)
- `K.dash(l, x, y, w, h)`: a dash at fractional x, its end pixels sharing the light; `K.dot` the same for points; `K.vshare` shares a row's light with the row below (one rect unless it is between rows); `K.edge` eases things near the screen's sides
- `K.twinkle` and the glitter's halo grow from zero
- `K.blit(..., soft)`: a slowly sliding layer moves on a few rects at a time (same rect count)
- theme fades: a fixed per-position level jitter while a place fades, so its dim texture goes a few rects at a time; fade-out 0.45 s to 0.6 s, fade-in 0.6 s to 0.8 s (worst frame of a cycle edge 0.22 to 0.125)

## New tests (test/unit_visuals.lua)
- still areas stay still: at silence, frames 101 to 220, the share of the screen changing by 3+ levels a frame must stay under 0.003 (the polished places sit between 0 and 0.0017; before the polish flock reached 0.0036 and tide 0.0022); a self-test injects a 16 x 4 px crawling dither and must fail it
- chord and meter changes never pop: chord changes (one mid-glide), the bar going from 8 eighths to 10 to 7; each onset against the frames just before it (3x), and what the events add never jumping more than 8 typical frames
- theme cycle edges ease: into each place from the one before and out to the next, on a barline

## Places
### ripples
Reads well: the tree line and its sky lying in the pond, the lily pads, rings landing in their motif's band, the cloud wisps' reflections.
Defects:
- the far waterline was one ruled full-width line
- the near reeds read as a bar chart (bare vertical strokes of one level)
- a cloud wisp wrapped from x 134 to -6 while still partly on screen (a pop at the edge)
- the near-water texture re-laid itself (its row spacing, dash gap and top row stepped in whole pixels) as the water sounds rose and fell
- out_mid's wavelets switched on one at a time at full light
- a motif's band of glints switched on and off at once with the motif
- the lower third sat near-empty at rest
Fixes:
- waterline: drawn as broken hand-made streaks, breathing as before
- reeds: the tall ones carry a lit seed head, each has a leaf arching off it, the stems have a little level jitter
- wisps wrap over a 176 px span, so they leave one side completely before coming back on the other (same positions on screen)
- near surface on fixed rows from y 37; the water sounds thicken it through the new density argument instead of re-laying it (also fills the lower third a little at rest)
- the newest wavelet fades in with the mid's fraction
- each motif's band eases in and out over ~0.8 s

### horizon
Reads well: the low sun on the line, the long cloud strokes, the rollers coming in, the porpoise pod.
Defects:
- the glow round the sun was a stepped pyramid of ruled bars
- the sun had no reflection of its own: the water under it was as dark as anywhere else at rest
- the headland read as a scatter of points rather than a dark mass with a lit rim
- the moment's skein of geese (large birds, 7 px apart) tangled into jagged streaks
- the sail incident was as bright as the glow it crosses, so it vanished in front of the sun
- the crests behind the line and the rollers' whitecaps switched on and off at a threshold
Fixes:
- halo: a rounded glow in hand-made dither strokes, clipped by the headland
- a soft column of strokes under the sun, as wide as the disc, wavering with the wave and dimmed by a passing cloud
- scrub thinned and thinning away from the rim; the rim is brighter and jittered
- geese: small birds in a clear V (6 px apart, 3 px per rank)
- sail brighter (9 at the mast)
- crests and whitecaps fade in over a soft threshold (new K.ramp)

### postcards
Reads well: four framed windows, each its own spot; the last note hanging in each sky; the caption playheads.
Defects:
- the hills hung vertical ticks down to the water every third column: they read as fences, not land
- the windows ended at y 42, leaving the band above the overlay's bar empty
- a window's frame, water and caption stepped a level when its motif came in or left
- whitecaps hopped up a row at a threshold, and the water sounds lengthened the dashes a whole pixel at a time
- at a peak the longest dashes poked through the right side of the frame
Fixes:
- each hill has a dim body under its ridge, thinning downward
- windows 4 px taller (y 9 to 47), two more rows of water, captions at y 50
- an eased per-window "sounding" light (0.7 s) drives frame, water and caption
- caps share their light between the two rows; dash length grows a fraction of a pixel at a time
- dashes are clipped to the frame

### rain
Reads well: the dark tree line with its two poplars against the pale rain sky, the slanted drops with their rings, the chord's heaped clouds.
Defects:
- the low cloud was four ruled rows of equal dashes every 40 px
- the grass along the near bank was a regular comb (heights cycling 1, 2, 3 on every column)
- the rain under each chord cloud jumped from the bottom of its fall back to the top
- the mist over the water gained a whole row at once as out_lo crossed a whole number
- the crests on the water line switched a level up and down at a threshold
- a dead black band between the low cloud and the trees
Fixes:
- low cloud in hand-made streaks whose lengths and places wander with each stroke
- tufts at hashed places and heights, two-thirds of the columns, with a little level jitter
- each rain stroke fades in under its cloud and out as it falls (sine over its fall)
- the mist's top row fades in with out_lo's fraction
- crests through K.ramp
- a faint rain haze (dithered, thinning upward) fills the band above the trees

### tide
Reads well: the swell lines running in toward the beach, the wash and its foam front, the bloom history drawing the shoreline.
Defects:
- with a steady bloom the shoreline was a ruled line, and the brightest thing on screen (level 5 every column)
- the sea's dashes crawled: each switched on at a threshold, hopped a pixel sideways and grew a pixel at w > 1, and whole columns hopped a row as their bend drifted with time
- the dash nearest the shore came and went with the heave
- the foam lace hopped sideways and switched pieces on and off at 2.3 rad/s: the most restless thing at rest (3+ level jumps on 0.2% of the screen every frame)
- the wet sheen's dashes switched level at a threshold
- the dune grass was nine straight bars 2 px apart: a bar code
- the far line was one ruled row
Fixes:
- fixed beach cusps (two slow sines) under the history; the line one level softer
- sea dashes fade in by K.ramp over their threshold, brighten on the crest, grow their fourth pixel by light; the bend is fixed in time; the last dash fades with its distance to the shore
- foam churns by light with its pieces in place; the upper lace and the out_mid lace fade in by ramps
- sheen through ramps
- six arching blades with lit tips, spread over 22 px
- far line jittered in 7 px pieces

### drift
Reads well: the chord's pools of sunlight on the bed, the leaves riding their eddies with wakes, the banks in the corners.
Defects:
- full-width sheens every 4 rows turned the pool into ruled horizontal lines and hid the eddies' round paths
- the surface texture re-laid itself (gap and row spacing stepping) as the water sounds changed
- the eddy arcs switched on at a threshold and stepped a level at sh > 0.8
- a leaf jumped from level 2.5 to 6 and its wake appeared at once when its motif came in (and the joining line between leaves appeared with it)
Fixes:
- sheens every 6 rows, longer gaps, a touch dimmer: the eddies now read as ellipses
- surface on fixed rows with the density argument
- arcs fade in by ramp over their threshold and brighten by ramp
- an eased per-motif presence (0.6 s) drives the leaf's light, its wake and the joining line

### reeds
Reads well: the glow over the far bank with the chord's stars, three layers of depth, the seed heads and their reflections.
Defects:
- every stem stood plumb and the near reeds were 2 px poles of one width and level: a forest of pipes
- the blade leaving each near reed was a straight stick
- the moon's halo (moment) was stacked bars every other row
- the wind along the far bank's top hopped a row at a threshold
Fixes:
- each stem has its own fixed set (up to 3 px of lean at the tip, less in the far layer); near reeds taper to 1 px above half height and dim 22% toward the top
- blades arch over and thin at their tips
- halo in hand-made dither rows, clipped by the bank
- the gust lifts the top by sharing its light with the row above (ramp)

### koi
Reads well: the fish swimming their loops with bending bodies and wakes, the stone rims, the maple branch, the rings at the notes' pitch.
Defects:
- the lily pads' notch was the whole right half of the middle row: every pad read as a mouth
- out_lo's broad light was a ruled stack of equal 14 px dashes every 4 rows
- the surface re-laid itself as the water sounds changed
- a fish jumped from level 2.5 to 6.5 (and its wake doubled) the frame its motif came in
- the wake's length stepped by whole points with out_mid, and every point's level jumped with it
Fixes:
- the slit is one pixel wide, on a slant, a different way round on alternate pads
- each row of the light band has its own length, place and level, alternate rows offset
- surface on fixed rows with density
- an eased per-fish presence (0.7 s) drives its light, sway and wake
- continuous wake length with its far end fading

### kelp
Reads well: the light fading with depth, the chord's shafts slanting down, the sandy floor, the bubbles.
Defects:
- fronds (near and far) were plumb stalks with horizontal blade ticks on alternate sides: fishbones or ladders, not kelp
- the surface skin switched a level and hopped a row at two thresholds along its length
- the motes and the school gained members whole as the water sounds and out_mid rose; school fish widened a whole pixel at once
Fixes:
- blades stream up and out in 2 px steps (three on near fronds, two on far; baked for the far layer), the tip fluttering; each stalk has its own fixed curve
- skin brightens by ramp and dips by sharing its light with the row below
- motes and the newest school fish fade in with the input's fraction; the fish's third pixel fades in by ramp

### fireflies
Reads well: the last light over the dark tree line, the fireflies and their wavering reflections, the chord's swarms, the lantern boat.
Defects:
- the water's edge was one ruled full-width line
- the reeds along the edge were the same three-stem stamp every 9 px: a tiled border
- a firefly's halo and cross switched on as it passed levels 3.5 and 7 (and its reflection's smear at 4)
- the crickets' shimmer in the grass switched on at a threshold
- the cattails were bare stems
Fixes:
- edge drawn as broken streaks
- reed clumps of one to three stems at hashed spacing (5 to 14 px) and heights
- halo, cross and reflection smear grow with the light from zero
- crickets through K.ramp
- cattails have a spike above the head, a leaf arching off and a little level jitter

### mist
Reads well: the fog banks drifting in long wisps, the chord's denser layers, the posts, buoys and boats showing through clear patches.
Defects:
- the sky above the fog was black: a night, not a morning
- the sun's glow (moment) was six stacked bars
- the waterline was a ruled row of 8 px pieces
- a fog wisp switched on at its threshold and stepped a level at a second one
- the lapping at the near edge switched on and hopped a row
- the near reed stalks were bare bars
Fixes:
- a faint pale-morning gradient (hand-made dither, clipped by the shore, warmer with bloom and breath) under the fog, kept low so the wisps still read
- the sun's glow as two nested soft rounds of dither rows
- waterline as broken streaks
- wisps gather out of nothing by K.ramp and brighten by ramp
- lapping fades in and lifts by sharing light between rows
- stalks get their own set, level jitter and a leaf on the tallest

### flock
Reads well: the flock keeping together and drifting with the tide, banking birds catching the light, the shining channels and the chord's pools on the mud.
Defects:
- the salt-marsh grass was a row of identical T-shaped posts every 8 px: a fence
- the far shore was one ruled line
- the birds ticked across a whole pixel at a time (the flock's 0.4 px/frame drift made 0.36% of the screen jump 3+ levels a frame at rest, the most of any place)
- a channel widened a whole row at once as the water rose; its running light and the out_hi glint switched on at thresholds; the wing extension switched on at mid 0.4
Fixes:
- grass in clumps of one to three fanning blades at hashed spacing and heights
- far shore as broken streaks
- each bird's body and wings are drawn at fractional x (new K.dash), sharing light between columns: still-area jumps fell to 0.11%
- channels widen by a fractional row; light, glint and wing extension through ramps

### brook
Reads well: the stones (the chord) with their pillows and wakes, the streamlines bending round them, the dappled bed, the minnows.
Defects:
- the banks were textured with the same horizontal strokes as the water, so bank and stream ran together
- each stone's wake riffles flickered a level on and off at 5 rad/s even at rest, and the whole wake re-levelled when out_mid added a riffle
- the streamline dashes switched a level at w 0.9 and appeared whole at w -0.5
- white-water flecks were added whole as the water sounds rose
- the standing wave (slot 1) blinked its riffles on and off
Fixes:
- banks re-baked as upright grass blades of one to three px, some leaning
- wake length continuous with its far riffle fading in; riffle shimmer by ramp at 3 rad/s
- dashes fade in and brighten through ramps
- the newest fleck fades in with the fraction
- standing-wave riffles through a ramp

### rockpool
Reads well: the starfish, the anemones opening with out_lo, the weed trailing from the rim, the boulders round the pool.
Defects:
- the pool's lip was one even line of one level all round: an outline on a map
- breakers beyond the rim hopped a row at a threshold and lengthened a whole pixel at once with the water sounds
- the surface ripples switched on at w 0.2 and again at a total-light threshold, and the cat's paws widened a pixel at a time
- the starfish glint jumped in at level 0.5+ the frame it crossed its threshold
Fixes:
- the lip's pieces (baked) each take their own level (0.65 to 1.25 of it) and one in ten is left dark
- breakers share light between rows and lengthen fractionally
- ripples and paws come and go through ramps, paw width grows fractionally
- the glint grows from zero

### dew
Reads well: the web (spokes, spiral and beaded dew), the drops the notes light, the anchor threads gliding with the chord.
Defects:
- the sun's glow was a hard-edged stepped plate: three zones a row, the middle one three times the outer
- the far reed bed was 46 identical uprights 2.8 px apart: a comb
- the two near reeds stood dead plumb the full height of the screen: posts
- the low mist switched each stroke on at its threshold
Fixes:
- five zones a row falling off from the sun's column (0.22, 0.55, 1.1, 0.55, 0.22): a round glow
- reed bed re-baked as loose clumps at hashed spacing, each stem in two pieces with its own lean, dimmer at the top, a few seed heads
- each near reed has its own set (2 to 2.5 px at the top)
- mist strokes fade in through a ramp

### cascade
Reads well: the woods along the top, the spray and plunge, the kingfisher, the rainbow incident.
Defects:
- the falling sheet was 1 px stripes every other column with streaks on them, and each ledge's shelf ran 6 px past it both sides: the fall read as a stack of boxed glyphs, not water
- the rock face used the same horizontal dashes as the pool, at a similar density, so cliff and water ran together
Fixes:
- the sheet is a continuous 2 px-per-column body with the streaks bright on it
- shelves reach 2 px past the lip and fade out over 3 more
- the rock is thinner, with 22 baked upright cracks (some jogging a pixel) through the strata

### mangrove
Reads well: the prop roots arching into the water, the canopy's ragged edge, the tide rising among the roots with the bloom, the chord's lit root arches.
Defects:
- the three near trunks were solid 3 x 20 px bars of one level: posts, not wood
- the chord's root arches lit their middle band 1.2 levels brighter in a hard step, reading as banded humps
- the lapping water hopped a row at a threshold
Fixes:
- trunks re-baked as 2 px pieces with their own levels, a little crooked, the lit side broken, a few highlights
- the arch's light swells smoothly toward its crown (sine along it)
- lapping shares its light between the two rows

### aurora
Reads well: the curtains folding and drifting, their broken reflection in the still fjord, the stars thinning where the aurora burns, the meteor and the cabin window.
Defects:
- the faint rays above the curtains stood on every 6th column: a comb along the top of the ribbon, most visible at rest
- a note's ray was a 2 px bar with a 6 px slab of glow: chunky, like a level meter
- at rest (bloom 0) the curtains were too faint to read as a ribbon (broken dashes)
Fixes:
- faint rays at hashed columns (three in ten), each its own height
- a ray is a 1 px core bright at its foot, thinning and fading upward, a 3 px glow beside it
- the aurora's floor strength 0.45 to 0.62 (peak unchanged: 0.62 + 0.8 bloom vs 0.45 + 0.9 bloom)

### shoal
Reads well: the near piles with the chord's bands of sunlight, the school turning as one, the surface broken by the deck's shadow.
Defects:
- the far piles were dotted rules (a 2 px dot every 3 rows)
- the weed was bare one-pixel sticks
- the surface skin switched a level and hopped a row at thresholds
- the school ticked a whole pixel at a time (0.17% of the screen jumping 3+ levels a frame at rest)
- motes came in whole as the water sounds rose
Fixes:
- far piles baked as dim uprights, broken by the haze at hashed places, some two px wide
- weed fronds carry leaflets off alternate sides
- skin brightens by ramp and dips by K.vshare (one rect unless it is between rows)
- each fish's body and tail drawn at fractional x with K.dash: still-area jumps 0.17% to 0.07%
- motes fade in with the fraction

### paddies
Reads well: the curved terraces stepping down the hill, each mirroring the sky along its far bund, the chord's light lying across them, the egret and the farmer's hat.
Defects:
- the rice was the same V tuft at near-even spacing on ruled rows: a repeated stamp
- the cat's paws switched on at a threshold
Fixes:
- each tuft sits further off its row (0.8 of a spacing instead of 0.35), up to a pixel off its row's height, its own height, and alternate tufts lean their tallest blade the other way (no added rects: paddies sits near the budget)
- cat's paws fade in by ramp

### echo bridge
Reads well: the arch and its reflection closing the ellipse, the echoes bouncing along the arch, the tail of light on its underside, the sunset through the arch.
Defects:
- the parapet was a ruled line with a post exactly every 6 px: a dashed rule, not old concrete
- the lanterns' halos were 6 x 4 boxes: lit windows, not lanterns
Fixes:
- coping baked in 5 px pieces of their own levels, posts at 5 to 7 px hashed spacing, the deck's lower edge in 7 px pieces
- a rounded halo (rows of 4, 6, 6, 4 px)

### confluence
Reads well: the petal pavilions in pairs, the drops running down them into the cistern, the cistern's glow with the bloom, the monarch.
Defects:
- the chord's light lay on every other row of a petal face: ruled hatching rather than a lit concrete face
- the native grasses were clumps every 8 px: a border, not a garden
Fixes:
- every row of the face, the light falling off smoothly (1 - d squared) from its height over a slightly shorter, narrower span (to stay inside the lit-area cap)
- grass clumps at 3 to 13 px hashed spacing
