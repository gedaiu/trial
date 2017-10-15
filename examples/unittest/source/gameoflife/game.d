module gameoflife.game;

import std.stdio;
import std.math;

struct Cell {
	long x;
	long y;
}

alias Cell[] CellList;

/// Count cell neighbours
long neighbours(Cell myCell, CellList list) {
	long cnt;

	foreach(cell; list) {
		auto diff1 = abs(myCell.x - cell.x);
		auto diff2 = abs(myCell.y - cell.y);

		if(diff1 == 1 || diff2 == 1) cnt++;
	}

	return cnt;
}

import fluent.asserts;

/// Count 0 neighbours on an empty cell list
unittest {
	CellList world = [ ];
	Cell(1,1).neighbours(world).should.equal(0);
}

/// Count all neighbours
unittest {
	CellList world = [ Cell(0,0), Cell(0,1), Cell(0,2), Cell(1,0), Cell(1,2), Cell(2,0), Cell(2,1), Cell(2,2) ];
    Cell(1,1).neighbours(world).should.equal(world.length);
}

/// Count 2 neighbours
unittest {
	CellList world = [ Cell(0,0), Cell(1,1), Cell(2,2), Cell(3,3) ];
    Cell(1,1).neighbours(world).should.equal(2);
}

/// Remove a cell from the world
CellList remove(ref CellList list, Cell myCell) {
	CellList newList;

	foreach(cell; list)
		if(cell != myCell)
			newList ~= cell;

	list = newList;

	return newList;
}

/// Should find one newighbour if the cell is in the world
unittest {
    auto cells = [ Cell(1,1), Cell(1,2) ];
    cells.remove(Cell(1,1)).length.should.equal(1);
}


/// Check if a cell lives
bool livesIn(Cell myCell, CellList list) {

	foreach(cell; list)
		if(cell == myCell) return true;

	return false;
}

/// Find if a cell is living in the world
unittest {
	CellList world = [ Cell(1,1) ];

	Cell(1,1).livesIn(world).should.equal(true);
}

/// Find if a cell does not live in the world
unittest {
	CellList world = [ Cell(1,1) ];

    Cell(2,2).livesIn(world).should.equal(false);
}

/// Get a list of all dead neighbours
CellList deadNeighbours(Cell myCell, CellList list) {
	CellList newList;

	foreach(x; myCell.x-1..myCell.x+1)
		foreach(y; myCell.y-1..myCell.y+1)
			if(x != myCell.x && y != myCell.y && !Cell(x,y).livesIn(list))
				newList ~= Cell(x,y);

	return newList;
}

/// The function that moves our cells to the next generation
void evolve(ref CellList list) {
	CellList newList = list;

	foreach(cell; list) {
		if(cell.neighbours(list) < 2)
			newList.remove(cell);

		if(cell.neighbours(list) > 3)
			newList.remove(cell);

		auto deadFrirends = cell.deadNeighbours(list);

		foreach(friend; deadFrirends)
			if(friend.neighbours(list) == 3)
				newList ~= friend;
	}

	list = newList;
}


//Any live cell with fewer than two live neighbours dies,
//as if caused by under-population.
unittest {
	CellList world = [ Cell(1,1), Cell(0,0) ];

	world.evolve;

	world.length.should.equal(0);
}

//Any live cell with two or three live neighbours lives
//on to the next generation.
unittest {
	CellList world = [ Cell(1,1), Cell(0,0), Cell(0,1) ];

	world.evolve;

	Cell(1,1).livesIn(world).should.equal(true);
}

//Any live cell with more than three live neighbours dies,
//as if by overcrowding.
unittest {
	CellList world = [ Cell(0,0), Cell(0,1), Cell(1,1), Cell(2,1), Cell(2,2) ];

	world.evolve;

    Cell(1,1).livesIn(world).should.equal(false);
}

//Any dead cell with exactly three live neighbours becomes
//a live cell, as if by reproduction.
unittest {
	CellList world = [ Cell(0,1), Cell(2,1), Cell(2,2) ];

	world.evolve;

    Cell(1,1).livesIn(world).should.equal(true);
}