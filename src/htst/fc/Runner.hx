package htst.fc;

import htst.fc.Property.PropertyGen;
import htst.fc.Property.Run;

class Runner<Ts> {
    final gen: PropertyGen<Ts>;
    final run: Run<Ts>;
    final runExecution = new RunExecution<Ts>();
    var runIndex = -1;

    public function new(gen:PropertyGen<Ts>, run: Run<Ts>) {
        this.gen = gen;
        this.run = run;
    }

    public function runCheck(): RunExecution<Ts> {
        // TODO - have the runner pull values and control the flow instead
        for(v in this.gen) {
            this.runIndex++;
            switch(this.run.run(v)) {
                case Success:
                    this.runExecution.success();
                case Failure(s):
                    this.runExecution.fail(v, runIndex, s);
                    this.runIndex = -1;
                    break;
                case PreconditionFailure:
                    // TODO handle skips etc...
                    this.runExecution.fail(v, runIndex, "PreConditionFailure");
                    this.runIndex = -1;
                    break;
            }
        }
        return this.runExecution;
    }
}

class RunExecution<Ts> {
    public var runs(default,null): Int = 0;
    public var numSuccesses(default,null): Int = 0;
    public var pathToFailure(default,null): String = null;
    public var value(default,null): Ts = null;
    public var failure(default,null): String = null;

    public function new() {}

    public inline function fail(value: Ts, id: Int, message: String): Void {
        this.pathToFailure = this.pathToFailure == null ? '${id}' : ':${id}';
        this.value = value;
        this.failure = message;
    }

    public inline function success(): Void {
        this.runs++;
        this.numSuccesses++;
    }

    public inline function isFailure(): Bool {
        return this.failure != null;
    }
}