use util gfx unit

type world{Main}
   main/Main w h rect owned/(dup 32 []) units cycle vs vs_i
   nqs trans orders free_ids used_ids active_units
   max_units/1200 max_w/256 max_h/256 max_cells
   tileset tileset_name tiles gfxes palette tints
   players/16^dup player/No minimap_dim minimap/Main.minimap
   minimap_cells
| WxH = $max_w*$max_h
| $max_cells <= WxH
| $units <= dup $max_units+WxH
| $free_ids <= ($max_units){?+WxH}
| for Id $free_ids
  | U = unit
  | U.id <= Id
  | U.world <= Me
  | $units.Id <= U
| $vs <= dup $units.size [] // visible units
| $minimap_cells <= dup $minimap.w*$minimap.h
| $main.world <= Me

world.cell_id P = $w*P.1 + P.0
world.get X Y = $units.($w*Y + X)
world.`.` P = $units.($w*P.1 + P.0)

world.init_minimap =
| [MW MH] = [$minimap.w $minimap.h]
| [W H] = [$w $h]
| for [MX MY] [0 0 MW MH].points
  | X = MX*W/MW
  | Y = MY*H/MH
  | $minimap_cells.(MW*MY+MX) <= $units.(Y*W+X)
| $upd_minimap

world.init_dimensions W H =
| $w <= W
| $h <= H
| $rect <= [0 0 W H]
| $minimap_dim <= 128/W //FIXME: breaks for 96x96 maps

world.upd_minimap =
| [MW MH] = [$minimap.w $minimap.h]
| for [MX MY] [0 0 MW MH].points
  | C = $minimap_cells.(MY*MW + MX)
  | U = C.content
  | if U then $minimap.set{MX MY U.mm_color}
    else $minimap.set{MX MY C.mm_color}

world.init_cell XY Tile =
| C = $tiles.Tile.copy
| Id = $cell_id{XY}
| C.id <= Id
| C.xy <= XY
| C.disp <= XY*32
| $units.Id <= C

world.new O T delay/6.rand =
| T = if T.is_utype then T else $main.types.T
| Id = $free_ids.($used_ids)
| $used_ids++
| U = $units.Id
| U.type <= T
| U.mana <= T.mana
| U.owner <= O
| U.resources <= T.resources.copy
| U.frame <= 0
| U.color <= if O then O.color else \yellow
| U.init_mm_color
| U.active_next <= $active_units
| $active_units <= U
| U

world.upd_area Rect F =
| for [X Y] Rect.points: when [X Y].in{$rect}: F $units.(Y*$w + X)

world.update =
| for U $active_units^uncons{active_next}: U.update
| $cycle++

PudTilesets = [summer winter wasteland swamp]
PudTeams = t nobody(0) neutral(0) capturable(0) computer(1) person(2) rescueable(2)
PudPlayers = [0 0 neutral 0 computer person capturable rescueable]
Critters = t summer\sheep wasteland\boar winter\seal swamp\hellhog
PudSides = [human orc neutral]

recolor Offset Pal Cs =
| Pal = Pal.copy
| for [I C] Cs.i: Pal.(Offset+I) <= C
| new_cmap Pal

world.load_pud Path =
| Units = []
| era [N @_] =
  | $tileset_name <= PudTilesets.N
  | $tileset <= $main.tilesets.($tileset_name)
  | $tiles <= $tileset.tiles
| sres N Xs = for [I A] Xs.group{2}{?u2}.i
  | $players.I.resources.N <= A
| Handlers = t
  'DESC' | Xs => //$description <= Xs.take{Xs.locate{0}^~{32}}.utf8
  'OWNR' | Xs => for [I P] Xs{PudPlayers.?}.i
                 | U = $new{0 player}
                 | less P: U.nobody <= 1
                 | U.color <= case P neutral yellow _ $main.player_colors.I
                 | U.name <= "Player[I]"
                 | U.playable <= P >< person
                 | U.rescueable <= case P capturable+rescueable 1
                 | U.xy <= [0 0]
                 | U.team <= PudTeams.P
                 | $players.I <= U
  'ERA ' | Xs => era Xs
  'ERAX' | Xs => era Xs
  'DIM ' | [2/W.u2 2/H.u2 @_] => $init_dimensions{W H}
  'SIDE' | Xs => for [I S] Xs{PudSides.?}.i: $players.I.side <= S
  'SGLD' | Xs => sres gold Xs
  'SLBR' | Xs => sres wood Xs
  'SOIL' | Xs => sres oil Xs
  'AIPL' | Xs => Xs.i{}{$0[I 1]=>$players.I.passive<=1}
  'MTXM' | Xs => | M = Xs.group{2}{?u2}
                 | I = -1
                 | for P $rect.points: $init_cell{P M.(|I++;I)}
  'UNIT' | @r$0 [2/X.u2 2/Y.u2 I O 2/D.u2 @Xs] =>
           | XY = [X Y]
           | T = case I 57 Critters.($tileset_name) _ $main.pud.I
           | case T
             No | bad "Invalid unit slot: [I]"
             player | $players.O.xy <= XY
                    | $players.O.view <= XY*32 - [224 224]
             _ | push [XY O T D] Units
           | r Xs
| Cs = Path.get^(@r$[] [4/M.utf8 4/L.u4 L/D @Xs] => [[M D] @Xs^r])
| less Cs^is{[[\TYPE _]@_]}: bad "Invalid PUD file: [Path]"
| for [T D] Cs: when got!it Handlers.T: it D
| for U $players
  | U.owner <= U.id
  | U.enemies <= $players.skip{?id >< U.id}.keep{P =>
    | (P.team <> U.team and P.team <> 0 and U.team <> 0)
      or (P.playable and U.playable)}
  | $units.(U.id) <= U
  | if no $player and U.playable then $player <= U
    else if U.nobody then
    else //U.order{plan}
| for [XY O T D] Units
  | P = $players.O
  | U = $new{P T}
  | when!it U.resource: U.resources.it <= D*2500
  | Rs = P.resources
  | have Rs.food 0
  | Rs.food += U.supply - U.cost.food
  | less U.building: U.dir <= Dirs.rand
  | U.deploy{XY}
| $palette <= $tileset.tiles.0.gfx.cmap
| $tints <= @table: map [K C] $main.ui_colors [K (recolor 208 $palette C)]
| $init_minimap
| for XY $rect.points
  | C = $XY
  | C.neibs <= Dirs{?+XY}.keep{?.in{$rect}}{$?}
| No

export world
