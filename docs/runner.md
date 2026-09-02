## RSpec Runner

Crystalball has a custom RSpec runner you can use in your development with `bundle exec crystalball` command. It builds a prediction and runs it.

### Runner Configuration

#### Config file

Create a YAML file for the runner. Default locations are `./crystalball.yml` and `./config/crystalball.yml`.
Please check an [example of a config file](https://github.com/toptal/crystalball/blob/master/spec/fixtures/crystalball.yml) and [configuration defaults](https://github.com/toptal/crystalball/blob/master/lib/crystalball/rspec/runner/configuration.rb#L10) for available options.
Please keep in mind that additional generator\prediction strategies can introduce additional configuration options.

#### Overriding config file

If you want to override the path to config file please set `CRYSTALBALL_CONFIG=path/to/crystalball.yml` env variable.

Any specific configuration option in `crystalball.yml` can be overridden by providing ENV variable with "CRYSTALBALL_" prefix. 
E.g. `CRYSTALBALL_EXAMPLES_LIMIT=10` will set `examples_limit` value to 10 regardless of what you have in config file.

More examples:

* `CRYSTALBALL_EXAMPLES_LIMIT=0` sets no limit on prediction size
* `CRYSTALBALL_MAP_EXPIRATION_PERIOD=0` sets no expiration period for maps
* `CRYSTALBALL_DIFF_FROM=origin/master` changes diff building to be `git diff origin/master`

### Parallel evaluation

Crystalball can split one prediction across multiple RSpec workers. It automatically uses
`CI_NODE_TOTAL` and `CI_NODE_INDEX`, as used by Knapsack, or `PARALLEL_TEST_GROUPS` and
`TEST_ENV_NUMBER`, as used by `parallel_tests`.

Run the same Crystalball command in each worker. For example, with GNU Parallel:

```shell
seq 0 3 | parallel 'CI_NODE_TOTAL=4 CI_NODE_INDEX={} bundle exec crystalball'
```

Locations from one spec file always run in the same worker. This prevents a full-file
prediction and an example-level prediction from running the same example twice.

For other parallel runners, set `CRYSTALBALL_PARALLEL_WORKERS` to the worker count and
`CRYSTALBALL_PARALLEL_WORKER_INDEX` to the zero-based index of the current worker.
