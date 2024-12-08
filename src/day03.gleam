import gleam/int
import gleam/list
import gleam/option
import gleam/regexp
import gleam/result
import gleam/string

pub fn part1(in: String) -> Int {
  let assert Ok(re) = regexp.from_string("(mul\\((\\d+),(\\d+)\\))")
  regexp.scan(re, in)
  |> list.map(fn(match) -> Int {
    let assert [_, option.Some(a), option.Some(b)] = match.submatches
    result.unwrap(int.parse(a), 0) * result.unwrap(int.parse(b), 0)
  })
  |> int.sum
}

pub fn part2(in: String) -> Int {
  let assert Ok(re) = regexp.from_string("don't\\(\\).*?do\\(\\)")
  in
  |> string.replace("\n", "")
  |> regexp.replace(re, _, "")
  |> part1
}
