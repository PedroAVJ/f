import Base

# Generic sprite timing/crop helpers. No artwork or private atlas is included.
# sample() returns a blank placeholder; sample_asset() takes a caller-owned URL.
type Animation is Data:
  Idle{}
  RunningRight{}
  RunningLeft{}
  Waving{}
  Jumping{}
  Failed{}
  Waiting{}
  Running{}
  Review{}
  LookDirection{direction: U32}
type Sequence is Data:
  Sequence{row: U32, total_ms: U32, durations: List<&2, U32>}
type Coordinates is Data:
  Coordinates{row: U32, column: U32}
type Frame is Data:
  Frame{pet_id: String, asset: String, animation: Animation, time_ms: U32, reduced_motion: Bool, row: U32, column: U32, x: U32, y: U32, width: U32, height: U32, sheet_width: U32, sheet_height: U32}

def sequence(animation: Animation) -> Sequence:
  match animation:
    case Idle{}: Sequence{0, 1000, [250, 250, 250, 250]}
    case RunningRight{}: Sequence{1, 1000, [250, 250, 250, 250]}
    case RunningLeft{}: Sequence{2, 1000, [250, 250, 250, 250]}
    case Waving{}: Sequence{3, 1000, [250, 250, 250, 250]}
    case Jumping{}: Sequence{4, 1000, [250, 250, 250, 250]}
    case Failed{}: Sequence{5, 1000, [250, 250, 250, 250]}
    case Waiting{}: Sequence{6, 1000, [250, 250, 250, 250]}
    case Running{}: Sequence{7, 1000, [250, 250, 250, 250]}
    case Review{}: Sequence{8, 1000, [250, 250, 250, 250]}
    case LookDirection{+direction}: Sequence{U32.add(9, U32.div(U32.mod(direction, 16), 8)), 1, [1]}
def column(durations: List<&2, U32>, +time_ms: U32, +index: U32) -> U32:
  match durations:
    case Nil{}: 0
    case Con{+duration, rest}: Bool.pick(U32, U32.is_lt(time_ms, duration), index, column(rest, U32.sub(time_ms, duration), U32.add(index, 1)))
def sequence_coordinates(seq: Sequence, time_ms: U32, reduced_motion: Bool) -> Coordinates:
  match seq:
    case Sequence{row, total_ms, durations}: Coordinates{row, column(durations, Bool.pick(U32, reduced_motion, 0, U32.mod(time_ms, total_ms)), 0)}
def coordinates(+animation: Animation, time_ms: U32, reduced_motion: Bool) -> Coordinates:
  match animation:
    case LookDirection{+direction}: Coordinates{U32.add(9, U32.div(U32.mod(direction, 16), 8)), U32.mod(direction, 8)}
    case _: sequence_coordinates(sequence(animation), time_ms, reduced_motion)
def sampled(coords: Coordinates, animation: Animation, time_ms: U32, reduced_motion: Bool) -> Frame:
  match coords:
    case Coordinates{+row, +col}: Frame{"sprite", "", animation, time_ms, reduced_motion, row, col, U32.mul(col, 64), U32.mul(row, 64), 64, 64, 512, 704}
def sample(+animation: Animation, +time_ms: U32, +reduced_motion: Bool) -> Frame:
  sampled(coordinates(animation, time_ms, reduced_motion), animation, time_ms, reduced_motion)
def activity(busy: Bool, failed: Bool, awaiting: Bool, reviewing: Bool, greeting: Bool) -> Animation:
  Bool.pick(Animation, failed, Failed{}, Bool.pick(Animation, busy, Running{}, Bool.pick(Animation, reviewing, Review{}, Bool.pick(Animation, greeting, Waving{}, Bool.pick(Animation, awaiting, Waiting{}, Idle{})))))

# Generic default layout: 8 columns, 11 rows, 64px square cells.
# Other layouts may supply Frame directly to the browser renderer.
def with_asset(asset: String, frame: Frame) -> Frame:
  match frame:
    case Frame{pet_id, old_asset, animation, time_ms, reduced_motion, row, column, x, y, width, height, sheet_width, sheet_height}:
      Frame{pet_id, asset, animation, time_ms, reduced_motion, row, column, x, y, width, height, sheet_width, sheet_height}

def sample_asset(asset: String, +animation: Animation, +time_ms: U32, +reduced_motion: Bool) -> Frame:
  with_asset(asset, sample(animation, time_ms, reduced_motion))
