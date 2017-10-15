module gameoflife.rules;

class GameOfLifeRules
{
    bool shouldDie(ubyte livingNeighboursCount) {
        if(livingNeighboursCount < 2 || livingNeighboursCount > 3) {
            return true;
        }

        return false;
    }
}