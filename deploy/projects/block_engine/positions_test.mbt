///|
test "insertion positions with and without an active block" {
  assert_eq(insertion_index(0, -1), 0)
  assert_eq(insertion_index(3, 0), 1)
  assert_eq(insertion_index(3, -1), 3)
  assert_eq(insertion_index(3, 9), 3)
}

///|
test "movement respects document bounds" {
  assert_eq(movement_index(4, 3, -1), 2)
  assert_eq(movement_index(4, 0, 1), 1)
  assert_eq(movement_index(4, 0, -1), -1)
  assert_eq(movement_index(4, 3, 1), -1)
  assert_eq(movement_index(4, 3, 0), -1)
}

///|
test "focus stays by the removed block" {
  assert_eq(selection_after_removal(1, 0), -1)
  assert_eq(selection_after_removal(4, 1), 1)
  assert_eq(selection_after_removal(4, 3), 2)
}
