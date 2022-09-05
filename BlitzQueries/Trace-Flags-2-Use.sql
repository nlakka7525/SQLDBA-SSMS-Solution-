/*	Below is the list of Trace Flags that could be appropriate in specific scenarios */

Positive
-----------
1118 -> Allocate uniform extents
2371 -> (Pre-2016) Force dynamic update stats thresholds for databases below 130 compatability

Negative
-----------
2861 -> Capture 0 cost plans

Neutral
------------
4199 -> Enable Query Optimizer Fixes
9481 -> Old CE (pre-2014) regardless of compat level
11064 -> memory balancing for columnstore inserted
9398 -> Disables Adaptive Joins
7412 -> Get live execution plan
272 -> Disables identity pre-allocation to avoid gaps in the values of an identity column in cases where the server restarts
610 -> (Pre-2016) Enables minimal logging for indexed tables
2312 -> Sets the query optimizer cardinality estimation model to the SQL Server 2014 (12.x) and later versions, dependent of the compatibility level of the database.


Query Performance
----------------------
8671 -> spend more time compiling plans, ignore "good enough plan found"
2453 -> table variables can trigger recompile when rows are inserted


OPTION (QUERYTRACEON 8671)
