Bytecode stack frames
=====================

Stack grows downwards.

Frame layout:

    .            .
    | (next)     |
    +------------+
    |    ...     |
    | Locals     |
    |    ...     |
    +------------+
    | Extra_args |
    +------------+
    | Env        |
    +------------+
    | Pc         |
    +------------+
    | Accu       | <-- sp
    +------------+
