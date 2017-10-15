module tests.gameoflife.rules;

import gameoflife.rules;

import trial.discovery.spec;
import fluent.asserts;

private alias suite = Spec!({
    describe("The game of life rules", {
        GameOfLifeRules rules;

        beforeEach({
            rules = new GameOfLifeRules;
        });

        it("any live cell with fewer than two live neighbours dies, as if caused by underpopulation", {
            rules.shouldDie(1).should.equal(true);
            rules.shouldDie(0).should.equal(true);
        });

        it("any live cell with two or three live neighbours lives on to the next generation", {
            rules.shouldDie(2).should.equal(false);
            rules.shouldDie(3).should.equal(false);
        });

        it("any live cell with more than three live neighbours dies, as if by overpopulation", {
            rules.shouldDie(4).should.equal(true);
            rules.shouldDie(5).should.equal(true);
            rules.shouldDie(6).should.equal(true);
            rules.shouldDie(7).should.equal(true);
            rules.shouldDie(8).should.equal(true);
            rules.shouldDie(9).should.equal(true);
        });

        it("any dead cell with exactly three live neighbours becomes a live cell, as if by reproduction");
    });
});
