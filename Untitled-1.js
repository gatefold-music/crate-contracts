//Sorting is a map

// mapping sortOrder // uint > id
// mapping reverseSortOrder // id > uint

// event orderUpdated (bytes32 id, uint256 sortedPosition)

function updateSortOrder(startIndex, idsInOrder) {
  // start index plus ids inorder should be less than or equal to the current length of the list
  // check if id exists in list
  // if it does, update reverse sort order / update sort order / emit event orderUpdated
}

// when listing is removed
// remove from both mappings

// when adding a listing
// dont give af about the order

// a challenge can be challenging the song or the place of that song on the playlist
// if a proposer suggests a spot on the playlist, if it gets added it should take that spot ?
// what if its already taken by the time it getss apporved>?

// propose a song with a sort order, risk getting wrecked
// propose a song without a sort order, more likely hood of that song getting added

// should anyone ever suggest a song for a playlist without having an idea of where it should be in the list??? << yes

// a contributor shouldnt get booted for choosing a good song but the wrong placement on the list
// how do we separate sort order and listing but also allow for a user to do both in one step. is that even possible ? who da fuq knows
