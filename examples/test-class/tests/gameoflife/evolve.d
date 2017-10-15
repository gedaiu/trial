module tests.gameoflife.evolve;

import std.random;
import gameoflife.evolve;

import trial.discovery.testclass;
import fluent.asserts;
auto rnd = Random(42);

class EvolveTests {

    @Test()
    void evolvingTheVoid() {
        [].evolve.should.equal([]);
    }

    @Test()
    void evolvingARandomCell() {
        auto x =  uniform(-100, 100, rnd);
        auto y =  uniform(-100, 100, rnd);

        [ Cell(x, y) ].evolve.should.equal([]);
    }
}
