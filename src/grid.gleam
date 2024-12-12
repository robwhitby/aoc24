import dir
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/result
import gleam/set.{type Set}
import gleam/yielder.{type Yielder}
import listx
import point.{type Point, Point}

pub type Cells(a) =
  Dict(Point, a)

pub type Cell(a) {
  Cell(point: Point, value: a)
}

pub type Grid(a) {
  Grid(cells: Cells(a), width: Int, height: Int)
}

pub fn cell_at(grid: Grid(a), point: Point) -> Result(Cell(a), Nil) {
  dict.get(grid.cells, point) |> result.map(Cell(point, _))
}

pub fn contains(grid: Grid(a), point: Point) -> Bool {
  dict.has_key(grid.cells, point)
}

pub fn update(grid: Grid(a), cell: Cell(a)) -> Grid(a) {
  Grid(dict.insert(grid.cells, cell.point, cell.value), grid.width, grid.height)
}

pub fn to_list(grid: Grid(a)) -> List(Cell(a)) {
  grid.cells
  |> dict.to_list
  |> list.map(fn(pair) { Cell(pair.0, pair.1) })
}

pub fn find(
  grid: Grid(a),
  value_predicate: fn(a) -> Bool,
) -> Result(Cell(a), Nil) {
  to_list(grid)
  |> list.find(fn(cell) { value_predicate(cell.value) })
}

pub fn filter(grid: Grid(a), value_predicate: fn(a) -> Bool) -> List(Cell(a)) {
  to_list(grid)
  |> list.filter(fn(cell) { value_predicate(cell.value) })
}

pub fn from_list(in: List(List(a))) -> Grid(a) {
  let cells =
    list.index_map(in, fn(row, y) {
      list.index_map(row, fn(v, x) { #(Point(x, y), v) })
    })
    |> list.flatten
    |> dict.from_list
  let w = in |> list.first |> result.map(list.length) |> result.unwrap(0)
  Grid(cells, w, list.length(in))
}

pub fn line(grid: Grid(a), from: Point, step: Point) -> Yielder(Cell(a)) {
  yielder.iterate(from, point.add(_, step))
  |> yielder.take_while(contains(grid, _))
  |> yielder.filter_map(cell_at(grid, _))
}

pub fn lines(
  grid: Grid(a),
  from: Point,
  steps: List(Point),
) -> List(Yielder(Cell(a))) {
  list.map(steps, line(grid, from, _))
}

pub type Stepper(a) {
  Stepper(
    steps: List(Point),
    valid_step: fn(Cell(a), Cell(a)) -> Bool,
    stop: fn(Cell(a)) -> Bool,
  )
}

pub fn routes(g: Grid(a), from: Cell(a), stepper: Stepper(a)) -> List(Cell(a)) {
  from.point
  |> point.neighbours(stepper.steps)
  |> list.filter_map(cell_at(g, _))
  |> list.filter(stepper.valid_step(from, _))
  |> list.flat_map(fn(next) {
    case stepper.stop(next) {
      True -> [next]
      False -> routes(g, next, stepper)
    }
  })
}

pub fn area(g: Grid(a), from: Cell(a)) -> Set(Cell(a)) {
  area_rec(g, [from], set.new())
}

fn area_rec(
  g: Grid(a),
  from: List(Cell(a)),
  found: Set(Cell(a)),
) -> Set(Cell(a)) {
  case from {
    [] -> found
    [c, ..tail] -> {
      point.neighbours(c.point, dir.nesw)
      |> list.filter_map(cell_at(g, _))
      |> list.filter(fn(n) { c.value == n.value && !set.contains(found, n) })
      |> fn(next) {
        area_rec(g, list.flatten([next, tail]), set.insert(found, c))
      }
    }
  }
}

pub fn areas(g: Grid(a)) -> List(Set(Cell(a))) {
  areas_rec(g, [], to_list(g))
}

fn areas_rec(g: Grid(a), found: List(Set(Cell(a))), remaining: List(Cell(a))) {
  case remaining {
    [] -> found
    [cell, ..rest] -> {
      case list.any(found, fn(area) { set.contains(area, cell) }) {
        True -> areas_rec(g, found, rest)
        False -> areas_rec(g, [area(g, cell), ..found], rest)
      }
    }
  }
}

pub fn perimeter(area: Set(Cell(a))) -> Int {
  let points = set.map(area, fn(c) { c.point })
  set.to_list(points)
  |> list.map(fn(p) {
    list.count(point.neighbours(p, dir.nesw), fn(n) { !set.contains(points, n) })
  })
  |> int.sum
}

pub fn sides(area: Set(Cell(a))) -> Int {
  let points = set.map(area, fn(c) { c.point })
  let is_edge = fn(p, d) { !set.contains(points, point.add(p, d)) }

  [
    set.filter(points, is_edge(_, dir.n)),
    set.filter(points, is_edge(_, dir.s)),
    set.filter(points, is_edge(_, dir.e)) |> set.map(point.flip),
    set.filter(points, is_edge(_, dir.w)) |> set.map(point.flip),
  ]
  |> list.flat_map(fn(edge) {
    edge
    |> set.to_list
    |> list.group(fn(p) { p.y })
    |> dict.map_values(fn(_, ps) {
      list.map(ps, fn(p) { p.x }) |> listx.count_contiguous
    })
    |> dict.values
  })
  |> int.sum
}
