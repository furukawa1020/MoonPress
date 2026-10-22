# Shared WordPress comparison

`python3 benchmarks/wordpress/fixture.py NEW_DIRECTORY 10` creates synthetic article JSON and native Markdown from one canonical source. Sizes are 10, 100 and 1000. The manifest hashes corpus bytes and all native inputs. Heading/paragraph equality is checked from rendered HTML, including escaping and Unicode; fixture creation refuses an existing destination. No personal articles or private history/trash records are used.

See [measurement boundaries](../../docs/wordpress-parity.md#measurement-contract). Native generation and HTTP serving are separate workloads; cached WordPress HTML is a required static control.
