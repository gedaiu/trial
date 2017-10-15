module tests.gameoflife.rules;

import gameoflife.rules;

import trial.discovery.spec;
import fluent.asserts;

private alias suite = Spec!({
    describe("any live cell", {
        GameOfLifeRules rules;

        beforeEach({
            rules = new GameOfLifeRules;
        });

        it("should die if it has fewer than two live neighbours, as if caused by underpopulation", {
            rules.shouldDie(1).should.equal(true);
            rules.shouldDie(0).should.equal(true);
        });

        it("should live on to the next generation if it has two or three live neighbours", {
            rules.shouldDie(2).should.equal(false);
            rules.shouldDie(3).should.equal(false);
        });

        it("should die if it has more than three live neighbours, as if by overpopulation", {
            rules.shouldDie(4).should.equal(true);
            rules.shouldDie(5).should.equal(true);
            rules.shouldDie(6).should.equal(true);
            rules.shouldDie(7).should.equal(true);
            rules.shouldDie(8).should.equal(true);
            rules.shouldDie(9).should.equal(true);
        });
    });

    describe("any dead cell", {
        it("should become a live cell if it has exactly three live neighbours, as if by reproduction");
    });
});
